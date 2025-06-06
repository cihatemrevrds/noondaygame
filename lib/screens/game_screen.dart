import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/player.dart';
import '../services/lobby_service.dart';
import '../services/game_service.dart';
import '../services/game_state_manager.dart';
import '../widgets/role_utils.dart';
import '../screens/night_phase_screen.dart';
import '../widgets/discussion_phase_widget.dart';
import '../widgets/voting_phase_widget.dart';
import '../widgets/role_reveal_popup.dart';
import '../widgets/night_outcome_popup.dart';
import '../widgets/event_share_popup.dart';
import '../widgets/vote_result_popup.dart';
import 'main_menu.dart';

class GameScreen extends StatefulWidget {
  final String lobbyCode;
  final bool isHost;

  const GameScreen({super.key, required this.lobbyCode, required this.isHost});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final LobbyService _lobbyService = LobbyService();
  final GameService _gameService = GameService();
  List<Player> _players = [];
  String _currentPhase = 'night';
  String _currentGameState = 'role_reveal'; // Track current game state
  String? _myRole;
  String? _myRoleDesc; // Role description
  String? _votedPlayerId;
  bool _isLoading = false;
  String _currentUserId = '';
  String? _nightActionResult; // Night action result
  Map<String, dynamic> _nightOutcomes = {}; // Individual night outcomes
  bool _hasShownRoleReveal = false; // Role reveal popup state
  int _dayCount = 1; // Day/Night counter
  // Phase configuration
  bool _manualPhaseControl = false; // Default value
  Map<String, dynamic>? _lobbyData; // Store current lobby data
  // Timing and phase management
  Timer? _phaseTimer;
  int _remainingTime = 0;

  // Event and popup state management
  bool _hasShownNightOutcome = false;
  bool _hasShownEventSharing = false;
  bool _hasShownVoteResult = false;
  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    WidgetsBinding.instance.addObserver(this);
    _setupLobbyListener();
    _fetchPhaseDurations().then((_) {
      _startGameLoop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phaseTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes during game
    switch (state) {
      case AppLifecycleState.paused:
        // Game went to background (Alt+Tab, minimized, etc.) - do nothing
        // Players should stay in game when switching between apps
        break;
      case AppLifecycleState.detached:
        // App is being terminated - if host, try to end game gracefully
        if (widget.isHost) {
          _performEmergencyGameCleanup();
        }
        break;
      case AppLifecycleState.inactive:
        // App is inactive but not necessarily closing - do nothing
        // This can happen during transitions, system dialogs, or Alt+Tab
        break;
      case AppLifecycleState.resumed:
        // Game resumed - everything is fine
        break;
      case AppLifecycleState.hidden:
        // Game is hidden - do nothing
        break;
    }
  }

  void _performEmergencyGameCleanup() {
    final gameStateManager = GameStateManager();
    gameStateManager.performEmergencyGameCleanup(
      widget.lobbyCode,
      widget.isHost,
    );
  }

  void _setupLobbyListener() {
    print('📡 Connecting to lobby: ${widget.lobbyCode}');

    _lobbyService.listenToLobbyUpdates(widget.lobbyCode).listen((snapshot) {
      if (!snapshot.exists) {
        // Lobby deleted, return to main menu
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Game has ended',
                style: TextStyle(fontFamily: 'Rye'),
              ),
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => MainMenu(username: '')),
            (route) => false,
          );
        }
        return;
      }
      final data = snapshot.data() as Map<String, dynamic>;

      // Store lobby data for access in other methods
      _lobbyData = data;

      // Update players
      final playersList =
          (data['players'] as List<dynamic>? ?? [])
              .map((p) => Player.fromMap(p as Map<String, dynamic>))
              .toList();

      // Find my role
      final myPlayer = playersList.firstWhere(
        (p) => p.id == _currentUserId,
        orElse: () => Player(name: 'Unknown'),
      );

      // Get votes status
      final votesData = data['votes'] as Map<String, dynamic>? ?? {};
      final votes = votesData.map((k, v) => MapEntry(k, v.toString()));

      // Get phase info and timing
      final phase = data['phase'] as String? ?? 'night';
      final gameState = data['gameState'] as String? ?? 'role_reveal';
      final dayCount = data['dayCount'] as int? ?? 1;

      // Extract timing info from Firebase
      final phaseStartedAt = data['phaseStartedAt'];
      final phaseTimeLimit =
          data['phaseTimeLimit'] as int? ?? 60000; // milliseconds

      // Calculate remaining time
      int remainingTime = 0;
      if (phaseStartedAt != null) {
        final startTime = phaseStartedAt.toDate();
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        remainingTime =
            ((phaseTimeLimit - elapsed) / 1000)
                .round()
                .clamp(0, double.infinity)
                .toInt();
      }

      // Get night action result and outcomes
      final nightActionResult =
          data['nightActionResult']?[_currentUserId]
              as String?; // Get individual night outcomes for this player
      final privateEvents =
          data['privateEvents'] as Map<String, dynamic>? ?? {};

      print("DEBUG: privateEvents structure: $privateEvents");

      // Check if there's a private event specifically for the current user
      final myPrivateEvent = privateEvents[_currentUserId];
      print("DEBUG: myPrivateEvent for $_currentUserId: $myPrivateEvent");

      // Handle both potential structures - either a full event object or a map of events
      final Map<String, dynamic> myNightOutcome;
      if (myPrivateEvent is Map<String, dynamic>) {
        myNightOutcome = myPrivateEvent;
      } else if (myPrivateEvent is String && myPrivateEvent.isNotEmpty) {
        // Handle case where privateEvent is a direct string message
        myNightOutcome = {'message': myPrivateEvent};
      } else {
        myNightOutcome = {};
      }

      // Get role description
      _getRoleDescription(myPlayer.role).then((roleDesc) {
        if (mounted) {
          setState(() {
            _players = playersList;
            _myRole = myPlayer.role;
            _myRoleDesc = roleDesc;
            _currentPhase = phase;
            _currentGameState = gameState;
            _nightActionResult = nightActionResult;
            _nightOutcomes = myNightOutcome;
            _dayCount = dayCount;
            _remainingTime = remainingTime;

            // Update vote selection
            _votedPlayerId = votes[_currentUserId];
          });

          // Handle phase-specific popups and actions
          _handlePhaseSpecificActions(gameState, data);

          // Start or update timer for current phase
          _updatePhaseTimer();
        }
      });
    });
  }

  // Get role description
  Future<String> _getRoleDescription(String? role) async {
    return RoleUtils.getRoleDescription(role);
  }

  Future<void> _submitVote(String targetId) async {
    // Prevent dead players from voting
    if (!_players.any((p) => p.id == _currentUserId && p.isAlive)) {
      return;
    }

    if (_currentGameState != 'voting_phase' || targetId == _currentUserId) {
      return;
    }

    setState(() {
      _isLoading = true;
      _votedPlayerId = targetId; // Update UI immediately
    });

    try {
      final success = await _gameService.submitVote(
        widget.lobbyCode,
        _currentUserId,
        targetId,
      );

      if (!success) {
        throw Exception('Failed to submit vote');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vote submitted',
              style: TextStyle(fontFamily: 'Rye'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Rye'),
            ),
          ),
        );
        setState(() {
          _votedPlayerId = null; // Reset selection on error
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showRoleRevealPopup() {
    if (_myRole == null || _myRole!.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => RoleRevealPopup(
            roleName: _myRole!,
            onComplete: () {
              Navigator.of(context).pop();
              // Trigger UI rebuild to show night screen immediately
              setState(() {
                // Force rebuild with _hasShownRoleReveal = true
              });
              // Server will automatically advance to night phase after 5 seconds
            },
          ),
    );
  }

  Future<void> _performNightAction(String action, String targetId) async {
    // Prevent dead players from performing actions
    if (!_players.any((p) => p.id == _currentUserId && p.isAlive)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? result;

      switch (action) {
        case 'doctorProtect':
          result = await _gameService.doctorProtect(
            widget.lobbyCode,
            _currentUserId,
            targetId,
          );
          break;

        case 'gunmanKill':
          result = await _gameService.gunmanKill(
            widget.lobbyCode,
            _currentUserId,
            targetId,
          );
          break;

        case 'sheriffInvestigate':
          result = await _gameService.sheriffInvestigate(
            widget.lobbyCode,
            _currentUserId,
            targetId,
          );
          break;

        case 'prostituteBlock':
          result = await _gameService.prostituteBlock(
            widget.lobbyCode,
            _currentUserId,
            targetId,
          );
          break;

        case 'peeperSpy':
          result = await _gameService.peeperSpy(
            widget.lobbyCode,
            _currentUserId,
            targetId,
          );
          break;
      }

      if (mounted && result != null) {
        setState(() => _nightActionResult = result);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result, style: const TextStyle(fontFamily: 'Rye')),
            backgroundColor: Colors.green[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Rye'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startGameLoop() {
    // Handle 7-phase system based on gameState
    switch (_currentGameState) {
      case 'role_reveal':
        // Phase 1: Role Reveal - handled by popup, no specific screen
        break;
      case 'night_phase':
        // Phase 2: Night Phase - uses NightPhaseScreen
        break;
      case 'night_outcome':
        // Phase 3: Night Outcome - individual results shown
        _showNightOutcomePhase();
        break;
      case 'event_sharing':
        // Phase 4: Event Sharing - public events shown
        _showEventSharingPhase();
        break;
      case 'discussion_phase':
        // Phase 5: Discussion Phase - uses DayPhaseScreen
        break;
      case 'voting_phase':
        // Phase 6: Voting Phase - uses DayPhaseScreen
        break;
      case 'voting_outcome':
        // Phase 7: Voting Outcome - results shown
        _showVotingOutcomePhase();
        break;
      default:
        print('Unknown game state: $_currentGameState');
        break;
    }
  }

  void _showNightOutcomePhase() {
    // Show individual night outcomes (Sheriff investigation results, etc.)
    print("DEBUG: Showing night outcome with _nightOutcomes: $_nightOutcomes");

    // Always show something, even if _nightOutcomes is empty
    String mainMessage = 'You had a quiet night.';

    if (_nightOutcomes.isNotEmpty) {
      // Check if _nightOutcomes itself has a message property (it's the entire event object)
      if (_nightOutcomes.containsKey('message')) {
        final message = _nightOutcomes['message'];
        if (message is String && message.isNotEmpty) {
          mainMessage = message;
        }
      }
    } // Show a single popup with the night outcome message
    print("DEBUG: Showing night outcome popup with message: '$mainMessage'");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => NightOutcomePopup(
            title: 'Night Outcome',
            message: mainMessage,
            onComplete: () {
              Navigator.of(context).pop();
              // Make sure we set flag so phase can advance properly
              setState(() {
                _hasShownNightOutcome = true;
              });

              // If we're in manual phase control mode, show a snackbar to remind the host
              if (_manualPhaseControl && widget.isHost) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "You can now advance to the next phase",
                      style: const TextStyle(fontFamily: 'Rye'),
                    ),
                    backgroundColor: Colors.green[800],
                    duration: const Duration(seconds: 3),
                  ),
                );
              }

              // Try to manually advance phase if auto-advance is enabled and timer is done
              if (!_manualPhaseControl && _remainingTime <= 0) {
                print("DEBUG: Attempting auto-advance after popup completion");
                _autoAdvancePhase();
              }
            },
          ),
    );
  }

  void _showEventSharingPhase() {
    // Show public night events
    List<String> events = _fetchNightEvents();
    if (events.isNotEmpty) {
      _showOutcomePopups(events, 0, isPrivate: false);
    }
  }

  // Helper method to check if there are any valid night outcomes
  bool _hasValidNightOutcomes() {
    if (_nightOutcomes.isEmpty) return false;

    // If _nightOutcomes has a message property, it's a valid outcome
    if (_nightOutcomes.containsKey('message')) {
      final message = _nightOutcomes['message'];
      return message is String && message.isNotEmpty;
    }

    // Always return true if we have any data - we'll display a default message anyway
    return true;
  }

  // Handle phase-specific actions and popups
  void _handlePhaseSpecificActions(
    String gameState,
    Map<String, dynamic> data,
  ) {
    switch (gameState) {
      case 'role_reveal':
        if (!_hasShownRoleReveal && _myRole != null && _myRole!.isNotEmpty) {
          _hasShownRoleReveal = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRoleRevealPopup();
          });
          setState(() {
            _remainingTime = 5; // Set timer to 5 seconds for role_reveal phase
          });
        }
        break;
      case 'night_outcome':
        if (!_hasShownNightOutcome && _hasValidNightOutcomes()) {
          // We'll set _hasShownNightOutcome in the popup's onComplete callback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showNightOutcomePhase();
          });
          setState(() {
            _remainingTime =
                10; // Set timer to 10 seconds for night_outcome phase
          });
        }
        break;

      case 'event_sharing':
        if (!_hasShownEventSharing) {
          _hasShownEventSharing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final events = _fetchNightEvents();
            if (events.isNotEmpty) {
              _showEventSharingPopup(events);
            }
          });
          setState(() {
            _remainingTime =
                5; // Set timer to 5 seconds for event_sharing phase
          });
        }
        break;

      case 'voting_outcome':
        if (!_hasShownVoteResult) {
          _hasShownVoteResult = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showVoteResultPopup(data);
          });
        }
        break;
      default:
        // Reset popup flags when entering new phases
        if (gameState == 'night_phase') {
          _hasShownNightOutcome = false;
        } else if (gameState == 'night_outcome') {
          // Ensure the flag is reset when entering night outcome phase
          _hasShownNightOutcome = false;
        } else if (gameState == 'discussion_phase') {
          _hasShownEventSharing = false;
        } else if (gameState == 'voting_phase') {
          _hasShownVoteResult = false;
        }
        break;
    }
  }

  // Update phase timer based on current timing
  void _updatePhaseTimer() {
    _phaseTimer?.cancel();

    if (_remainingTime > 0) {
      _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _remainingTime =
                (_remainingTime - 1).clamp(0, double.infinity).toInt();
          });

          if (_remainingTime <= 0) {
            timer.cancel();
            // Automatically advance phase when timer expires (only if not in manual mode)
            if (!_manualPhaseControl) {
              _autoAdvancePhase();
            } else {
              // In manual mode, ensure we show a message that the host needs to advance the phase
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Host needs to advance to the next phase",
                    style: const TextStyle(fontFamily: 'Rye'),
                  ),
                  backgroundColor: Colors.amber[800],
                ),
              );
            }
          }
        } else {
          timer.cancel();
        }
      });
    }
  }

  // Automatically advance phase when timer expires
  void _autoAdvancePhase() async {
    try {
      print('⏰ Timer expired, auto-advancing phase from: $_currentGameState');

      // Add a small delay to ensure Firebase has processed any state changes
      await Future.delayed(const Duration(milliseconds: 500));

      // Call the backend auto-advance function
      final response = await http.post(
        Uri.parse(
          'https://us-central1-noondaygame.cloudfunctions.net/autoAdvancePhase',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lobbyCode': widget.lobbyCode,
          'currentState':
              _currentGameState, // Send current state for verification
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ Phase auto-advanced: ${responseData['message']}');
      } else if (response.statusCode == 400 &&
          response.body.contains("Phase time not expired yet")) {
        // Phase isn't ready to advance yet, will be handled by the next Firebase update
        print('⏱️ Phase not ready to advance yet, waiting for next update');
      } else {
        print(
          '❌ Auto-advance failed: ${response.statusCode} - ${response.body}',
        );

        // Show a message to the host if we're in manual mode
        if (widget.isHost && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Unable to advance phase automatically. Please try manually.",
                style: const TextStyle(fontFamily: 'Rye'),
              ),
              backgroundColor: Colors.red[800],
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Auto-advance error: $e');

      // Try again after a short delay if it's a network error
      if (e.toString().contains('XMLHttpRequest error')) {
        print('🔄 Network error, retrying auto-advance in 1 second');
        Future.delayed(const Duration(seconds: 1), _autoAdvancePhase);
      }
    }
  }

  // Show event sharing popup with public events
  void _showEventSharingPopup(List<String> events) {
    if (events.isEmpty) return;

    // Show first event - for multiple events, we could chain them
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => EventSharePopup(
            eventDescription: events.first,
            playerName: 'Everyone', // Generic player name for public events
            onComplete: () {
              Navigator.of(context).pop();
            },
          ),
    );
  }

  // Show vote result popup
  void _showVoteResultPopup(Map<String, dynamic> data) {
    final lastDayResult = data['lastDayResult'] as Map<String, dynamic>?;

    if (lastDayResult != null) {
      final eliminatedPlayerName =
          lastDayResult['name'] as String? ?? 'Unknown';
      final eliminatedPlayerRole =
          lastDayResult['role'] as String? ?? 'Unknown';
      final voteCount = lastDayResult['voteCount'] as int? ?? 0;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => VoteResultPopup(
              playerName: eliminatedPlayerName,
              playerRole: eliminatedPlayerRole,
              voteCount: voteCount,
              onComplete: () {
                Navigator.of(context).pop();
              },
            ),
      );
    } else {
      // No majority vote - show no elimination message
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => VoteResultPopup(
              playerName: 'No One', // Use "No One" instead of null
              playerRole: null,
              voteCount: 0,
              onComplete: () {
                Navigator.of(context).pop();
              },
            ),
      );
    }
  }

  void _showVotingOutcomePhase() {
    // Show voting results (handled by the vote result popup in _handlePhaseSpecificActions)
    // This method is called by _startGameLoop but actual popup is handled by phase listener
  }
  Future<void> _fetchPhaseDurations() async {
    try {
      final lobbySettings = await _lobbyService.getLobbySettings(
        widget.lobbyCode,
      );
      setState(() {
        _manualPhaseControl = lobbySettings['manualPhaseControl'] ?? false;
        // Note: In 7-phase system, phase durations are handled server-side
        // We only need to fetch manual phase control setting
      });
    } catch (e) {
      print('Error fetching phase durations: $e');
    }
  }

  List<String> _fetchNightEvents() {
    // Fetch events from Firebase lobby data
    if (_lobbyData != null && _lobbyData!.containsKey('nightEvents')) {
      final nightEvents = _lobbyData!['nightEvents'] as List<dynamic>?;
      if (nightEvents != null) {
        return nightEvents.map((event) => event.toString()).toList();
      }
    }
    // Return empty list if no events are available
    return [];
  }

  void _showOutcomePopups(
    List<String> messages,
    int index, {
    bool isPrivate = false,
  }) {
    if (index >= messages.length) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2B1810),
            title: Text(
              isPrivate ? 'Night Outcome' : 'Event',
              style: const TextStyle(fontFamily: 'Rye', color: Colors.white),
            ),
            content: Text(
              messages[index],
              style: const TextStyle(fontFamily: 'Rye', color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (index + 1 < messages.length) {
                    _showOutcomePopups(
                      messages,
                      index + 1,
                      isPrivate: isPrivate,
                    );
                  }
                },
                child: const Text(
                  'OK',
                  style: TextStyle(fontFamily: 'Rye', color: Colors.orange),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _endGame() async {
    final gameStateManager = GameStateManager();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('End Game?'),
            content: const Text('This will end the game for all players.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await gameStateManager.endGame(
                    widget.lobbyCode,
                    widget.isHost,
                    (message) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      }
                    },
                  );
                },
                child: const Text('END GAME'),
              ),
            ],
          ),
    );
  } // Manual advance method for host

  void _manualAdvancePhase() async {
    if (!widget.isHost || !_manualPhaseControl) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Use gameService to advance to next phase
      final result = await _gameService.advancePhase(
        widget.lobbyCode,
        user.uid,
      );

      if (result == null) {
        throw Exception('Failed to advance phase');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phase advanced',
              style: TextStyle(fontFamily: 'Rye'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Rye'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Get text for manual advance button based on current game state
  String _getManualAdvanceButtonText() {
    switch (_currentGameState) {
      case 'role_reveal':
        // After role reveal popup, button should advance to night phase
        return _hasShownRoleReveal ? 'START NIGHT PHASE' : 'START NIGHT PHASE';
      case 'night_phase':
        return 'START NIGHT OUTCOME';
      case 'night_outcome':
        return 'START EVENT SHARING';
      case 'event_sharing':
        return 'START DISCUSSION';
      case 'discussion_phase':
        return 'START VOTING';
      case 'voting_phase':
        return 'START VOTING OUTCOME';
      case 'voting_outcome':
        return 'START NEXT NIGHT';
      default:
        return 'ADVANCE PHASE';
    }
  }

  // Get user-friendly display text for current phase
  String _getDisplayPhase() {
    switch (_currentGameState) {
      case 'role_reveal':
        // After role reveal popup, show "Night" while waiting for server transition
        return _hasShownRoleReveal ? 'Night' : 'Role Reveal';
      case 'night_phase':
        return 'Night';
      case 'night_outcome':
        return 'Night Results';
      case 'event_sharing':
        return 'Events';
      case 'discussion_phase':
        return 'Discussion';
      case 'voting_phase':
        return 'Voting';
      case 'voting_outcome':
        return 'Vote Results';
      default:
        return _currentPhase;
    }
  }

  // Build the appropriate widget for the current game state
  Widget _buildPhaseWidget() {
    switch (_currentGameState) {
      case 'role_reveal':
        // Show a waiting screen while role reveal popup is shown
        return _buildWaitingScreen('Revealing roles...', Icons.visibility);

      case 'night_phase':
        // Show night phase screen for night actions
        return NightPhaseScreen(
          lobbyCode: widget.lobbyCode,
          currentUserId: _currentUserId,
          myRole: _myRole,
          myRoleDesc: _myRoleDesc,
          nightActionResult: _nightActionResult,
          players: _players,
          isLoading: _isLoading,
          onNightAction: (action, targetId) {
            if (_players.any((p) => p.id == _currentUserId && p.isAlive)) {
              _performNightAction(action, targetId);
            }
          },
          onSetNightActionResult: (result) => setState(() => _nightActionResult = result),
          nightNumber: _dayCount,
        );

      case 'night_outcome':
        // Show waiting screen while night outcome popups are shown
        return _buildWaitingScreen(
          'Processing night actions...',
          Icons.nightlight_round,
        );

      case 'event_sharing':
        // Show waiting screen while event sharing popup is shown
        return _buildWaitingScreen(
          'Sharing night events...',
          Icons.announcement,
        );

      case 'discussion_phase':
        // Show discussion phase widget
        return DiscussionPhaseWidget(
          players: _players.where((p) => p.isAlive).toList(),
          remainingTime: _remainingTime,
          currentUserId: _currentUserId,
          myRole: _myRole,
        );
      case 'voting_phase':
        // Show voting phase widget
        return VotingPhaseWidget(
          players: _players
              .where((p) => p.isAlive && p.id != _currentUserId)
              .toList(),
          remainingTime: _remainingTime,
          currentUserId: _currentUserId,
          myRole: _myRole,
          onVoteChanged: (selectedPlayerId) {
            if (_players.any((p) => p.id == _currentUserId && p.isAlive)) {
              if (selectedPlayerId != null) {
                _submitVote(selectedPlayerId);
              }
            }
          },
        );

      case 'voting_outcome':
        // Show waiting screen while vote result popup is shown
        return _buildWaitingScreen('Sharing vote results...', Icons.how_to_vote);

      default:
        // Fallback to a generic waiting screen
        return _buildWaitingScreen('Loading game...', Icons.hourglass_empty);
    }
  }

  // Build a waiting screen with message and icon
  Widget _buildWaitingScreen(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.orange.withOpacity(0.8)),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Rye',
              fontSize: 24,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(2, 2),
                  blurRadius: 4,
                  color: Colors.black87,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (_remainingTime > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${_remainingTime}s remaining',
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 16,
                color: Colors.orange,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getDisplayPhase().toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            if (_myRole != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.brown[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'You: $_myRole',
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (widget.isHost)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _endGame,
              tooltip: 'End Game',
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/backgrounds/saloon_bg.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: _buildPhaseWidget(),
          ),

          // Host controls for manual phase advancement
          if (widget.isHost && _manualPhaseControl)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _manualAdvancePhase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E2C0B),
                    minimumSize: const Size(250, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    _getManualAdvanceButtonText(),
                    style: const TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
