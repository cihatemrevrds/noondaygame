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
  String? _myRole;
  String? _myRoleDesc; // Role description
  String? _votedPlayerId;  bool _isLoading = false;
  String _currentUserId = '';  String? _nightActionResult; // Night action result
  bool _hasShownRoleReveal = false; // Role reveal popup state

  int _nightPhaseDuration = 30; // Default value
  int _eventPhaseDuration = 5; // Default value
  int _dayPhaseDuration = 60; // Default value
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

      // Oyuncuları güncelle
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

      // Get phase info
      final phase = data['phase'] as String? ?? 'night';
      final gameState = data['gameState'] as String? ?? '';
      final dayCount = data['dayCount'] as int? ?? 1;

      // Get remaining time and night action result (if any)
      final nightActionResult =
          data['nightActionResult']?[_currentUserId] as String?;

      // Get role description
      _getRoleDescription(myPlayer.role).then((roleDesc) {
        if (mounted) {
          setState(() {
            _players = playersList;
            _myRole = myPlayer.role;
            _myRoleDesc = roleDesc;
            _currentPhase = phase;
            _nightActionResult = nightActionResult;
            _dayCount = dayCount;

            // Update vote selection
            _votedPlayerId = votes[_currentUserId];
          });

          // Show role reveal popup when game starts
          if (gameState == 'role_reveal' &&
              !_hasShownRoleReveal &&
              _myRole != null &&
              _myRole!.isNotEmpty) {
            _hasShownRoleReveal = true;
            _showRoleRevealPopup();
          }
        }
      });
    });  }  
  
  // Get role description
  Future<String> _getRoleDescription(String? role) async {
    return RoleUtils.getRoleDescription(role);
  }

  Future<void> _submitVote(String targetId) async {
    if (_currentPhase != 'day' || targetId == _currentUserId) return;

    setState(() {      _isLoading = true;
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
      }    }
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
    if (_currentPhase == 'night') {
      _startNightPhase();
    } else if (_currentPhase == 'event') {
      _startEventPhase();
    } else if (_currentPhase == 'day') {
      _startDayPhase();
    }
  }

  Future<void> _fetchPhaseDurations() async {
    try {
      final lobbySettings = await _lobbyService.getLobbySettings(
        widget.lobbyCode,
      );
      setState(() {
        _nightPhaseDuration = lobbySettings['nightPhaseDuration'] ?? 30;
        _eventPhaseDuration = lobbySettings['eventPhaseDuration'] ?? 5;
        _dayPhaseDuration = lobbySettings['dayPhaseDuration'] ?? 60;
        _manualPhaseControl = lobbySettings['manualPhaseControl'] ?? false;
      });
    } catch (e) {
      print('Error fetching phase durations: $e');
    }
  }

  void _startNightPhase() {
    setState(() {
      _currentPhase = 'night';
    });

    if (!_manualPhaseControl) {
      // Automatic timer-based transition
      Future.delayed(Duration(seconds: _nightPhaseDuration), () {
        if (mounted) {
          setState(() {
            _currentPhase = 'event';
          });
          _startGameLoop();
        }
      });
    }
    // If manual control is enabled, host will manually advance phase
  }

  void _startEventPhase() {
    setState(() {
      _currentPhase = 'event';
    });
    List<String> events = _fetchNightEvents();

    if (!_manualPhaseControl) {
      // Automatic event popups
      _showEventPopups(events, 0);
    } else {
      // Manual control - host can advance when ready
      // Events are still shown but phase doesn't auto-advance
      _showEventPopups(events, 0, manualControl: true);
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

  void _showEventPopups(
    List<String> events,
    int index, {
    bool manualControl = false,
  }) {
    if (index >= events.length) {
      if (!manualControl) {
        setState(() {
          _currentPhase = 'day';
        });
        _startGameLoop();
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(content: Text(events[index])),
    );

    Duration delay =
        manualControl
            ? Duration(seconds: _eventPhaseDuration)
            : Duration(seconds: _eventPhaseDuration);

    Future.delayed(delay, () {
      if (mounted) {
        Navigator.of(context).pop();
        _showEventPopups(events, index + 1, manualControl: manualControl);
      }
    });
  }

  void _startDayPhase() {
    setState(() {
      _currentPhase = 'day';
    });

    if (!_manualPhaseControl) {
      // Automatic timer-based transition
      Future.delayed(Duration(seconds: _dayPhaseDuration), () {
        if (mounted) {
          setState(() {
            _currentPhase = 'night';
          });
          _startGameLoop();
        }
      });
    }
    // If manual control is enabled, host will manually advance phase
  }

  // Manual advance method for host
  void _manualAdvancePhase() {
    if (!widget.isHost || !_manualPhaseControl) return;

    switch (_currentPhase) {
      case 'night':
        setState(() {
          _currentPhase = 'event';
        });
        _startGameLoop();
        break;
      case 'event':
        setState(() {
          _currentPhase = 'day';
        });
        _startGameLoop();
        break;
      case 'day':
        setState(() {
          _currentPhase = 'night';
        });
        _startGameLoop();
        break;
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
              _currentPhase.toUpperCase(),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/saloon_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child:            _currentPhase == 'night'
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
                      (result) => setState(() => _nightActionResult = result),
                  nightNumber: _dayCount,
                )                : DayPhaseScreen(
                  currentUserId: _currentUserId,
                  myRole: _myRole,
                  myRoleDesc: _myRoleDesc,
                  players: _players,
                  votedPlayerId: _votedPlayerId,
                  isLoading: _isLoading,
                  onVotePlayer: _submitVote,
                  onSetNightActionResult:
                      (result) => setState(() => _nightActionResult = result),
                  dayNumber: _dayCount,
                ),

      ),
    );
  }

  String _getPhaseDescription() {
    switch (_currentPhase) {
      case 'night':
        return 'Night falls... Execute your role actions!';
      case 'event':
        return 'Morning events are being revealed...';
      case 'day':
        return 'Day phase - Discuss and vote to eliminate a suspect!';
      default:
        return 'Game in progress...';
    }
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case 'night':
        return NightPhaseScreen(
          lobbyCode: widget.lobbyCode,
          currentUserId: _currentUserId,
          myRole: _myRole,
          myRoleDesc: _myRoleDesc,
          nightActionResult: _nightActionResult,
          players: _players,
          isLoading: _isLoading,
          onNightAction: _performNightAction,
          onSetNightActionResult: (result) {
            setState(() {
              _nightActionResult = result;
            });
          },
        );
      case 'day':
        return DayPhaseScreen(
          currentUserId: _currentUserId,
          myRole: _myRole,
          myRoleDesc: _myRoleDesc,
          players: _players,
          votedPlayerId: _votedPlayerId,
          isLoading: _isLoading,
          onVotePlayer: _submitVote,
          onSetNightActionResult: (result) {
            setState(() {
              _nightActionResult = result;
            });
          },
        );
      default:
        return const Center(
          child: Text(
            'Preparing next phase...',
            style: TextStyle(
              fontFamily: 'Rye',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        );
    }
  }

  Widget _buildHostControls() {
    if (_isLoading) {
      return const CircularProgressIndicator(color: Color(0xFF4E2C0B));
    }

    if (_manualPhaseControl) {
      return ElevatedButton(
        onPressed: _manualAdvancePhase,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4E2C0B),
          minimumSize: const Size(250, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _getManualAdvanceButtonText(),
          style: const TextStyle(
            fontFamily: 'Rye',
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: _advancePhase,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4E2C0B),
          minimumSize: const Size(250, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _currentPhase == 'day' ? 'END DAY & COUNT VOTES' : 'ADVANCE PHASE',
          style: const TextStyle(
            fontFamily: 'Rye',
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      );
    }
  }

  String _getManualAdvanceButtonText() {
    switch (_currentPhase) {
      case 'night':
        return 'START EVENT PHASE';
      case 'event':
        return 'START DAY PHASE';
      case 'day':
        return 'START NIGHT PHASE';
      default:
        return 'ADVANCE PHASE';
    }
  }
}
