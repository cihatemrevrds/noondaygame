import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/player.dart';
import '../services/lobby_service.dart';
import '../services/game_service.dart';
import '../services/game_state_manager.dart';
import '../widgets/role_utils.dart';
import '../screens/night_phase_screen.dart';
import '../screens/day_phase_screen.dart';
import 'package:noondaygame/widgets/role_reveal_popup.dart';
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
      final votes = votesData.map(
        (k, v) => MapEntry(k, v.toString()),
      ); // Get phase info
      final phase = data['phase'] as String? ?? 'night';
      final gameState = data['gameState'] as String? ?? 'role_reveal';
      final dayCount = data['dayCount'] as int? ?? 1;

      // Get remaining time and night action result (if any)
      final nightActionResult =
          data['nightActionResult']?[_currentUserId] as String?;

      // Get individual night outcomes for this player
      final nightOutcomes =
          data['nightOutcomes'] as Map<String, dynamic>? ?? {};
      final myNightOutcome =
          nightOutcomes[_currentUserId] as Map<String, dynamic>? ?? {};

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

            // Update vote selection
            _votedPlayerId = votes[_currentUserId];
          }); // Show role reveal popup when game starts
          if (gameState == 'role_reveal' &&
              !_hasShownRoleReveal &&
              _myRole != null &&
              _myRole!.isNotEmpty) {
            _hasShownRoleReveal = true;
            _showRoleRevealPopup();
          }
        }
      });
    });
  }

  // Get role description
  Future<String> _getRoleDescription(String? role) async {
    return RoleUtils.getRoleDescription(role);
  }

  Future<void> _submitVote(String targetId) async {
    if (_currentGameState != 'voting_phase' || targetId == _currentUserId)
      return;

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
            },
          ),
    );
  }

  Future<void> _performNightAction(String action, String targetId) async {
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
    if (_nightOutcomes.isNotEmpty) {
      final outcomes = <String>[];
      _nightOutcomes.forEach((key, value) {
        if (value is String && value.isNotEmpty) {
          outcomes.add(value);
        }
      });

      if (outcomes.isNotEmpty) {
        _showOutcomePopups(outcomes, 0, isPrivate: true);
      }
    }
  }

  void _showEventSharingPhase() {
    // Show public night events
    List<String> events = _fetchNightEvents();
    if (events.isNotEmpty) {
      _showOutcomePopups(events, 0, isPrivate: false);
    }
  }

  void _showVotingOutcomePhase() {
    // Show voting results (handled by server-side voting outcome)
    // This phase will show elimination results, etc.
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
        return 'START NIGHT PHASE';
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

  // Determine which screen to show based on game state
  bool _shouldShowNightScreen() {
    switch (_currentGameState) {
      case 'night_phase':
        return true; // Show night screen for night actions
      case 'role_reveal':
      case 'night_outcome':
      case 'event_sharing':
      case 'discussion_phase':
      case 'voting_phase':
      case 'voting_outcome':
        return false; // Show day screen for all other phases
      default:
        return _currentPhase == 'night'; // Fallback to old logic
    }
  }

  // Get user-friendly display text for current phase
  String _getDisplayPhase() {
    switch (_currentGameState) {
      case 'role_reveal':
        return 'Role Reveal';
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
                image: AssetImage("assets/images/saloon_bg.png"),
                fit: BoxFit.cover,
              ),
            ),
            child:
                _shouldShowNightScreen()
                    ? NightPhaseScreen(
                      lobbyCode: widget.lobbyCode,
                      currentUserId: _currentUserId,
                      myRole: _myRole,
                      myRoleDesc: _myRoleDesc,
                      nightActionResult: _nightActionResult,
                      players: _players,
                      isLoading: _isLoading,
                      onNightAction: _performNightAction,
                      onSetNightActionResult:
                          (result) =>
                              setState(() => _nightActionResult = result),
                      nightNumber: _dayCount,
                    )
                    : DayPhaseScreen(
                      currentUserId: _currentUserId,
                      myRole: _myRole,
                      myRoleDesc: _myRoleDesc,
                      players: _players,
                      votedPlayerId: _votedPlayerId,
                      isLoading: _isLoading,
                      onVotePlayer: _submitVote,
                      onSetNightActionResult:
                          (result) =>
                              setState(() => _nightActionResult = result),
                      dayNumber: _dayCount,
                    ),
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
