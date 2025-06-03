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
  String? _myRoleDesc; // Rol açıklaması
  String? _votedPlayerId;
  bool _isLoading = false;
  String _currentUserId = '';
  String? _nightActionResult; // Gece aksiyonu sonucu
  bool _hasShownRoleReveal = false; // Role reveal popup state
  Map<String, dynamic> _currentSettings = {}; // Current game settings
  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    WidgetsBinding.instance.addObserver(this);
    _setupLobbyListener();
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
        // Game went to background - player might return
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // App is being terminated - if host, try to end game gracefully
        if (widget.isHost) {
          _performEmergencyGameCleanup();
        }
        break;
      case AppLifecycleState.resumed:
        // Game resumed
        break;
      case AppLifecycleState.hidden:
        // Game is hidden
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
    print('📡 Lobiye bağlanılıyor: ${widget.lobbyCode}');

    _lobbyService.listenToLobbyUpdates(widget.lobbyCode).listen((snapshot) {
      if (!snapshot.exists) {
        // Lobi silinmiş, ana menüye geri dön
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

      // Oyuncuları güncelle
      final playersList =
          (data['players'] as List<dynamic>? ?? [])
              .map((p) => Player.fromMap(p as Map<String, dynamic>))
              .toList();

      // Kendi rolümü bul
      final myPlayer = playersList.firstWhere(
        (p) => p.id == _currentUserId,
        orElse: () => Player(name: 'Unknown'),
      ); // Oyların durumunu al
      final votesData = data['votes'] as Map<String, dynamic>? ?? {};
      final votes = votesData.map((k, v) => MapEntry(k, v.toString()));

      // Faz bilgisini al
      final phase = data['phase'] as String? ?? 'night';
      final gameState = data['gameState'] as String? ?? '';

      // Kalan süre ve gece aksiyonu sonucu (varsa)
      final nightActionResult =
          data['nightActionResult']?[_currentUserId] as String?;

      // Rol açıklaması getir
      _getRoleDescription(myPlayer.role).then((roleDesc) {
        if (mounted) {
          setState(() {
            _players = playersList;
            _myRole = myPlayer.role;
            _myRoleDesc = roleDesc;
            _currentPhase = phase;
            _nightActionResult = nightActionResult;

            // Oy seçimini güncelle
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

      // Update current settings
      setState(() {
        _currentSettings = data['settings'] as Map<String, dynamic>? ?? {};
      });
    });
  }

  // Rol açıklamasını getir
  Future<String> _getRoleDescription(String? role) async {
    return RoleUtils.getRoleDescription(role);
  }

  Future<void> _advancePhase() async {
    final gameStateManager = GameStateManager();
    await gameStateManager.advancePhase(
      widget.lobbyCode,
      widget.isHost,
      _currentPhase,
      () => setState(() => _isLoading = true),
      (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message, style: const TextStyle(fontFamily: 'Rye')),
            ),
          );
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _submitVote(String targetId) async {
    if (_currentPhase != 'day' || targetId == _currentUserId) return;

    setState(() {
      _isLoading = true;
      _votedPlayerId = targetId; // Hemen UI'ı güncelle
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
          _votedPlayerId = null; // Hata durumunda seçimi sıfırla
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/western_town_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child:
            _currentPhase == 'night'
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
                  settings: _currentSettings, // Pass settings here
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
                      (result) => setState(() => _nightActionResult = result),
                  dayPhaseDuration: _currentSettings['discussionTime'] ?? 60, // Example: discussion time
                  settings: _currentSettings, // Pass settings here
                ),
      ),
    );
  }
}
