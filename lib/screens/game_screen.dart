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
  String? _myRoleDesc; // Rol açıklaması
  String? _votedPlayerId;
  bool _isVotingPhase = false;
  bool _isLoading = false;
  String _currentUserId = '';  Map<String, String> _votes = {};
  String? _nightActionResult; // Gece aksiyonu sonucu
  int _phaseSecondsLeft = 0; // Faz için kalan süre
  bool _hasShownRoleReveal = false; // Role reveal popup state
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
    // Emergency cleanup when app is terminated during game
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.isHost) {
      // Fire and forget - delete the lobby to end the game
      _lobbyService.deleteLobby(widget.lobbyCode, user.uid);
    }
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
      );

      // Oyların durumunu al
      final votesData = data['votes'] as Map<String, dynamic>? ?? {};
      final votes = votesData.map((k, v) => MapEntry(k, v.toString()));      // Faz bilgisini al
      final phase = data['phase'] as String? ?? 'night';
      final gameState = data['gameState'] as String? ?? '';
      final dayCount = data['dayCount'] as int? ?? 1;

      // Kalan süre ve gece aksiyonu sonucu (varsa)
      final remainingSeconds = data['remainingSeconds'] as int? ?? 0;
      final nightActionResult = data['nightActionResult']?[_currentUserId] as String?;

      // Rol açıklaması getir
      _getRoleDescription(myPlayer.role).then((roleDesc) {
        if (mounted) {
          setState(() {
            _players = playersList;
            _myRole = myPlayer.role;
            _myRoleDesc = roleDesc;
            _currentPhase = phase;
            _dayCount = dayCount;
            _isVotingPhase = phase == 'day';
            _votes = votes;
            _phaseSecondsLeft = remainingSeconds;
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
    });
  }

  // Rol açıklamasını getir
  Future<String> _getRoleDescription(String? role) async {
    if (role == null) return 'Rol henüz atanmamış';

    switch (role) {
      case 'Doctor':
        return 'Her gece bir kişiyi ölümden koruyabilirsin. Kendini de koruyabilirsin.';
      case 'Gunman':
        return 'Her gece bir kişiyi öldürebilirsin. Dikkatli seç!';
      case 'Sheriff':
        return 'Her gece bir kişinin hangi takımda olduğunu öğrenebilirsin.';
      case 'Prostitute':
        return 'Her gece bir kişinin gece aksiyonunu engelleyebilirsin.';
      case 'Peeper':
        return 'Her gece bir kişinin rolünü öğrenebilirsin.';
      case 'Chieftain':
        return 'Bandit takımının liderisin. Şerif seni kasabalı olarak görür.';
      case 'Townsperson':
        return 'Kasabalısın. Gece aksiyonu yok, gündüz oylamasında banditleri bulmaya çalış.';
      default:
        return 'Bilinmeyen rol';
    }
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
          ),    );
  }

  void _showRoleRevealPopup() {
    if (_myRole == null || _myRole!.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RoleRevealPopup(
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
          result = await _gameService.doctorProtect(widget.lobbyCode, _currentUserId, targetId);
          break;
          
        case 'gunmanKill':
          result = await _gameService.gunmanKill(widget.lobbyCode, _currentUserId, targetId);
          break;
          
        case 'sheriffInvestigate':
          result = await _gameService.sheriffInvestigate(widget.lobbyCode, _currentUserId, targetId);
          break;
          
        case 'prostituteBlock':
          result = await _gameService.prostituteBlock(widget.lobbyCode, _currentUserId, targetId);
          break;
          
        case 'peeperSpy':
          result = await _gameService.peeperSpy(widget.lobbyCode, _currentUserId, targetId);
          break;
      }
      
      if (mounted && result != null) {
        setState(() => _nightActionResult = result);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result,
              style: const TextStyle(fontFamily: 'Rye'),
            ),
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

  // Test fonksiyonu - geliştirme sırasında kullanılabilir
  void _testRoleActions() {
    if (_myRole == null) return;
    
    print('Test: $_myRole rolü için aksiyon testi yapılıyor');
    
    // Rastgele bir oyuncu seçelim
    if (_players.isNotEmpty) {
      final testPlayer = _players.where((p) => p.id != _currentUserId).first;
      
      switch (_myRole) {
        case 'Doctor':
          _performNightAction('doctorProtect', testPlayer.id);
          break;
        case 'Gunman':
          _performNightAction('gunmanKill', testPlayer.id);
          break;
        case 'Sheriff':
          _performNightAction('sheriffInvestigate', testPlayer.id);
          break;
        case 'Prostitute':
          _performNightAction('prostituteBlock', testPlayer.id);
          break;
        case 'Peeper':
          _performNightAction('peeperSpy', testPlayer.id);
          break;
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Doctor':
        return Colors.blue;
      case 'Gunman':
        return Colors.red;
      case 'Sheriff':
        return Colors.green;
      case 'Prostitute':
        return Colors.pink;
      case 'Peeper':
        return Colors.orange;
      case 'Chieftain':
        return Colors.brown;
      case 'Townsperson':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Doctor':
        return Icons.healing;
      case 'Gunman':
        return Icons.sports_bar; // Gun ikonu olarak sports_bar kullanıyoruz
      case 'Sheriff':
        return Icons.star;
      case 'Prostitute':
        return Icons.favorite;
      case 'Peeper':
        return Icons.visibility;
      case 'Chieftain':
        return Icons.verified_user;
      case 'Townsperson':
        return Icons.person;
      default:
        return Icons.help;
    }
  }

  bool _hasNightAction(String role) {
    switch (role) {
      case 'Doctor':
      case 'Gunman':
      case 'Sheriff':
      case 'Prostitute':
      case 'Peeper':
        return true;
      default:
        return false;
    }
  }
  Widget _buildNightActionUI() {
    // Rol rengini ve ikonunu belirle
    Color roleColor = _getRoleColor(_myRole ?? 'Unknown');
    IconData roleIcon = _getRoleIcon(_myRole ?? 'Unknown');
    
    // Rol aksiyonu adını belirle
    String actionName;
    String actionType;
    
    switch (_myRole) {
      case 'Doctor':
        actionName = 'Koru';
        actionType = 'doctorProtect';
        break;
      case 'Gunman':
        actionName = 'Öldür';
        actionType = 'gunmanKill';
        break;
      case 'Sheriff':
        actionName = 'Araştır';
        actionType = 'sheriffInvestigate';
        break;
      case 'Prostitute':
        actionName = 'Engelle';
        actionType = 'prostituteBlock';
        break;
      case 'Peeper':
        actionName = 'Gözetle';
        actionType = 'peeperSpy';
        break;
      default:
        actionName = 'Aksiyon';
        actionType = '';
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst kısım - Rol bilgisi ve ikonu
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Rol ikonu
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: roleColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Icon(
                    roleIcon,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Rol adı
                Text(
                  _myRole ?? 'Unknown',
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Rol açıklaması
                Text(
                  _myRoleDesc ?? 'Rol açıklaması yükleniyor...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Aksiyon sonucu (varsa)
                if (_nightActionResult != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      _nightActionResult!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
                
                // Aksiyon butonları
                _hasNightAction(_myRole ?? '') 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pas geç butonu
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () {
                                // Pas geçme işlemi
                                setState(() => _nightActionResult = "Bu gece aksiyon yapmamayı seçtin.");
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[700],
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Pas Geç',
                                style: TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Rol aksiyonu butonu
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () {
                                // Oyuncu seçim modunu aç
                                _showPlayerSelectionModal(actionName, actionType);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: roleColor,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                actionName,
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
                    )
                  : const Text(
                      'Gece aksiyonu bulunmuyor',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Oyuncu seçim modalını göster
  void _showPlayerSelectionModal(String actionName, String actionType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF2D1B0E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getRoleColor(_myRole ?? ''),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getRoleIcon(_myRole ?? ''), 
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "$actionName - Oyuncu Seç",
                      style: const TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _players.where((p) => p.isAlive).length,
                  itemBuilder: (context, index) {
                    final player = _players.where((p) => p.isAlive).toList()[index];
                    
                    // Rolüne göre bazı oyuncuları hariç tutma
                    bool canTarget = true;
                    
                    switch (_myRole) {
                      case 'Gunman':
                      case 'Sheriff':
                      case 'Prostitute':
                      case 'Peeper':
                        canTarget = player.id != _currentUserId; // Kendisi hedeflenemez
                        break;
                    }
                    
                    if (!canTarget) return const SizedBox.shrink();
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Card(
                        color: Colors.brown.withOpacity(0.7),
                        elevation: 4,
                        child: InkWell(
                          onTap: _isLoading
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _performNightAction(actionType, player.id);
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.grey[400],
                                  child: Text(
                                    player.name.isNotEmpty ? player.name[0].toUpperCase() : "?",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    player.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'Rye',
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // İptal butonu
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'İptal',
                      style: TextStyle(
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
      },
    );
  }

  Widget _buildPlayerGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive grid layout
        final screenWidth = constraints.maxWidth;
        // Determine optimal grid layout based on number of players and screen size
        int crossAxisCount;
        double aspectRatio;

        // Always show at least 4 columns for testing and UI layout consistency
        if (_players.length <= 4) {
          crossAxisCount = 4; // Changed from 2 to 4 for minimum layout
        } else if (_players.length <= 9) {
          crossAxisCount = 4; // Keep 4 columns for better visual spacing
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
                  _isVotingPhase && player.isAlive && player.id != _currentUserId
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
    );
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Üst kısım: Rol bilgisi
            Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Column(
                children: [
                  // Rol ikonu
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.brown[700],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getRoleIcon(_myRole ?? 'Unknown'),
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Rol adı
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _myRole ?? 'Unknown',
                      style: const TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Rol açıklaması
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _myRoleDesc ?? 'Rol açıklaması yükleniyor...',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Orta kısım: Oyuncu profilleri
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, // Her satırda 5 oyuncu
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _players.where((p) => p.isAlive).length,
                itemBuilder: (context, index) {
                  final player = _players.where((p) => p.isAlive).toList()[index];
                  final isSelected = _votedPlayerId == player.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _votedPlayerId = player.id;
                      });
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.brown[800] : Colors.brown[600],
                            border: Border.all(
                              color: isSelected ? Colors.yellow : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_outline, // Anonim kullanıcı simgesi
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          player.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Alt kısım: Aksiyon butonları
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pas geç butonu
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() => _nightActionResult = "Bu gece aksiyon yapmamayı seçtin.");
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[800],
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Pas Geç',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Rol aksiyonu butonu
                  ElevatedButton(
                    onPressed: _votedPlayerId == null || _isLoading
                        ? null
                        : () {
                            _performNightAction(_myRole ?? '', _votedPlayerId!);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[800],
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Aksiyon',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
