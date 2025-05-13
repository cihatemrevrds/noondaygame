import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/menu_button.dart';
import '../widgets/player_avatar.dart';
import '../models/player.dart';
import '../services/lobby_service.dart';
import '../services/game_service.dart';
import 'role_selection_page.dart';

class LobbyRoomPage extends StatefulWidget {
  final String roomName;
  final String lobbyCode;

  const LobbyRoomPage({
    super.key, 
    required this.roomName, 
    required this.lobbyCode,
  });

  @override
  State<LobbyRoomPage> createState() => _LobbyRoomPageState();
}

class _LobbyRoomPageState extends State<LobbyRoomPage> {
  final LobbyService _lobbyService = LobbyService();
  final GameService _gameService = GameService();
  List<Player> players = [];
  bool _isLoading = false;
  bool _isHost = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _setupLobbyListener();
  }

  void _setupLobbyListener() {
    _lobbyService.listenToLobbyUpdates(widget.lobbyCode).listen((snapshot) {
      if (!snapshot.exists) {
        // Lobi silinmiş, ana menüye geri dön
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lobby has been deleted'),
            ),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      // Host bilgisini kontrol et
      final hostUid = data['hostUid'] as String?;
      final isHost = hostUid == _currentUserId;

      // Oyuncuları güncelle
      final playersList = (data['players'] as List<dynamic>? ?? [])
          .map((p) {
            final map = p as Map<String, dynamic>;
            return Player(
              id: map['id'] as String? ?? '',
              name: map['name'] as String? ?? 'Player',
              isLeader: map['id'] == hostUid,
            );
          })
          .toList();

      // Oyun başladıysa, rol seçim sayfasına git
      if (data['status'] == 'started' && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoleSelectionPage(
              players: playersList,
              lobbyCode: widget.lobbyCode,
              isHost: isHost,
            ),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          players = playersList;
          _isHost = isHost;
        });
      }
    });
  }

  Future<void> _leaveLobby() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_isHost) {
        // Eğer host ise, lobiyi sil
        await _lobbyService.deleteLobby(widget.lobbyCode, user.uid);
      } else {
        // Değilse, sadece lobiyi terk et
        await _lobbyService.leaveLobby(widget.lobbyCode, user.uid);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving lobby: $e'),
          ),
        );
      }
    }
  }

  Future<void> _startGame() async {
    if (!_isHost) return;
    
    if (players.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Need at least 4 players to start',
            style: TextStyle(fontFamily: 'Rye'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoleSelectionPage(
            players: players,
            lobbyCode: widget.lobbyCode,
            isHost: _isHost,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting game: $e'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyCodeToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.lobbyCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room code copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: Text(
          widget.roomName,
          style: const TextStyle(
            fontFamily: 'Rye',
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _leaveLobby,
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
                    'Players: ${players.length}',
                    style: const TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 18,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Share this code with your friends:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.brown[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.lobbyCode,
                          style: const TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 24,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white),
                          onPressed: _copyCodeToClipboard,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.75,
                ),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  return PlayerAvatar(
                    name: players[index].name,
                    isLeader: players[index].isLeader,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (players.length < 4)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Need at least 4 players to start',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  _isLoading
                      ? const CircularProgressIndicator(color: Color(0xFF4E2C0B))
                      : MenuButton(
                          text: 'NEXT',
                          onPressed: _isHost && players.length >= 4 ? _startGame : null,
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
