import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../models/player.dart';
import '../services/lobby_service.dart';
import '../services/game_service.dart';
import '../widgets/player_avatar.dart';
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
  int _dayCount = 1;
  String? _myRole;
  String? _votedPlayerId;
  bool _isVotingPhase = false;
  bool _isLoading = false;
  String _currentUserId = '';
  Map<String, String> _votes = {};
  bool _hasShownRoleReveal = false;
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
    // Emergency cleanup when app is terminated during game
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.isHost) {
      // Fire and forget - delete the lobby to end the game
      _lobbyService.deleteLobby(widget.lobbyCode, user.uid);
    }
  }

  void _setupLobbyListener() {
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
      );

      // Oyların durumunu al
      final votesData = data['votes'] as Map<String, dynamic>? ?? {};
      final votes = votesData.map(
        (k, v) => MapEntry(k, v.toString()),
      ); // Faz bilgisini al
      final phase = data['phase'] as String? ?? 'night';
      final gameState = data['gameState'] as String? ?? '';
      final dayCount = data['dayCount'] as int? ?? 1;

      if (mounted) {
        setState(() {
          _players = playersList;
          _myRole = myPlayer.role;
          _currentPhase = phase;
          _dayCount = dayCount;
          _isVotingPhase = phase == 'day';
          _votes = votes;

          // Oy seçimini güncelle
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
  }

  Future<void> _advancePhase() async {
    if (!widget.isHost) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Gündüzse ve oylar verilmişse, sonuçlandır
      if (_currentPhase == 'day') {
        await _gameService.processVotes(widget.lobbyCode);
      }

      final result = await _gameService.advancePhase(
        widget.lobbyCode,
        user.uid,
      );
      if (result == null) throw Exception('Failed to advance phase');

      final newPhase = result['newPhase'] as String? ?? 'night';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Phase changed to ${newPhase.toUpperCase()}',
              style: const TextStyle(fontFamily: 'Rye'),
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
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    if (!widget.isHost) return;

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
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    await _lobbyService.deleteLobby(widget.lobbyCode, user.uid);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error ending game: $e')),
                      );
                    }
                  }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_currentPhase.toUpperCase()} - DAY $_dayCount',
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
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _currentPhase == 'day'
                        ? 'Vote to eliminate a player!'
                        : 'Night falls... Be quiet!',
                    style: const TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 18,
                      color: Colors.brown,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate responsive grid layout
                  final screenWidth = constraints.maxWidth;
                  // Determine optimal grid layout based on number of players and screen size
                  int crossAxisCount;
                  double aspectRatio;

                  // Always show at least 4 columns for testing and UI layout consistency
                  if (_players.length <= 4) {
                    crossAxisCount =
                        4; // Changed from 2 to 4 for minimum layout
                  } else if (_players.length <= 9) {
                    crossAxisCount =
                        4; // Keep 4 columns for better visual spacing
                  } else if (_players.length <= 16) {
                    crossAxisCount = 4;
                  } else {
                    crossAxisCount = 5;
                  }

                  // Adjust for very wide screens
                  if (screenWidth > 1200 && _players.length > 6) {
                    crossAxisCount = math.min(crossAxisCount + 1, 6);
                  }

                  // Calculate square aspect ratio with padding for text
                  aspectRatio = 1.0; // Square frames

                  // Calculate spacing based on screen size
                  final spacing = math.max(8.0, screenWidth * 0.01);
                  final padding = math.max(12.0, screenWidth * 0.02);

                  return GridView.builder(
                    padding: EdgeInsets.all(padding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: aspectRatio,
                    ),
                    itemCount: _players.length,
                    itemBuilder: (context, index) {
                      final player = _players[index];
                      final isVoted = _votedPlayerId == player.id;
                      final voteCount =
                          _votes.values.where((id) => id == player.id).length;

                      return GestureDetector(
                        onTap:
                            _isVotingPhase && player.isAlive
                                ? () => _submitVote(player.id)
                                : null,
                        child: Container(
                          decoration: BoxDecoration(
                            border:
                                isVoted
                                    ? Border.all(color: Colors.green, width: 3)
                                    : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              PlayerAvatar(
                                name: player.name,
                                isLeader: player.isLeader,
                                isDead: !player.isAlive,
                              ),
                              if (voteCount > 0 && _isVotingPhase)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$voteCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (widget.isHost) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(
                          color: Color(0xFF4E2C0B),
                        )
                        : ElevatedButton(
                          onPressed: _advancePhase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E2C0B),
                            minimumSize: const Size(250, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentPhase == 'day'
                                ? 'END DAY & COUNT VOTES'
                                : 'START NEW DAY',
                            style: const TextStyle(
                              fontFamily: 'Rye',
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
