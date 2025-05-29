// GÜNCELLENMİŞ LOBBYROOMPAGE - Sabit grid yapısı ve responsive layout entegre edildi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/menu_button.dart';
import '../models/player.dart';
import '../services/lobby_service.dart';
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

class _LobbyRoomPageState extends State<LobbyRoomPage>
    with WidgetsBindingObserver {
  final LobbyService _lobbyService = LobbyService();
  List<Player> players = [];
  bool _isLoading = false;
  bool _isHost = false;
  String _currentUserId = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _lobbySubscription;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    WidgetsBinding.instance.addObserver(this);
    _setupLobbyListener();
  }

  @override
  void dispose() {
    _lobbySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupLobbyListener() {
    setState(() => _isLoading = true);
    _lobbySubscription = _lobbyService
        .listenToLobbyUpdates(widget.lobbyCode)
        .listen((snapshot) {
          if (!snapshot.exists) {
            Navigator.popUntil(context, (route) => route.isFirst);
            return;
          }

          final data = snapshot.data();
          if (data == null) return;

          final hostUid = data['hostUid'] as String?;
          final isHost = hostUid == _currentUserId;

          final playersData = data['players'] as List<dynamic>? ?? [];
          bool currentUserFound = false;

          final playersList =
              playersData.map((p) {
                final map = p as Map<String, dynamic>;
                final playerId = map['id'] ?? map['uid'] ?? '';
                if (playerId == _currentUserId) currentUserFound = true;
                return Player(
                  id: playerId,
                  name: map['name'] ?? 'Player',
                  isLeader: playerId == hostUid,
                  role: map['role'],
                  isAlive: map['isAlive'] ?? true,
                  team: map['team'],
                );
              }).toList();

          if (data['status'] == 'started') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) => RoleSelectionPage(
                      players: playersList,
                      lobbyCode: widget.lobbyCode,
                      isHost: isHost,
                    ),
              ),
            );
            return;
          }

          setState(() {
            players = playersList;
            _isHost = isHost;
            _isLoading = false;
          });
        });
  }

  Future<void> _leaveLobby() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_isHost) {
      await _lobbyService.deleteLobby(widget.lobbyCode, user.uid);
    } else {
      await _lobbyService.leaveLobby(widget.lobbyCode, user.uid);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _startGame() async {
    if (!_isHost || players.length < 4) return;
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance
        .collection('lobbies')
        .doc(widget.lobbyCode)
        .update({'status': 'started'});
    setState(() => _isLoading = false);
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
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.brown),
              )
              : LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage("assets/images/saloon_bg.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.exit_to_app),
                                color: Colors.white,
                                onPressed: _leaveLobby,
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'LOBBY CODE',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        widget.lobbyCode,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          color: Colors.white,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Colors.white,
                                        ),
                                        onPressed: _copyCodeToClipboard,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: players.length,
                                      itemBuilder: (context, index) {
                                        final player = players[index];
                                        return ListTile(
                                          title: Text(
                                            player.name,
                                            style: const TextStyle(
                                              fontFamily: 'Rye',
                                            ),
                                          ),
                                          leading: const CircleAvatar(
                                            backgroundColor: Colors.brown,
                                          ),
                                          trailing:
                                              _isHost &&
                                                      player.id !=
                                                          _currentUserId
                                                  ? Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.red,
                                                        ),
                                                        onPressed:
                                                            () => _lobbyService
                                                                .kickPlayer(
                                                                  widget
                                                                      .lobbyCode,
                                                                  player.id,
                                                                  _currentUserId,
                                                                ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.star,
                                                          color: Colors.orange,
                                                        ),
                                                        onPressed:
                                                            () => _lobbyService
                                                                .transferHost(
                                                                  widget
                                                                      .lobbyCode,
                                                                  player.id,
                                                                ),
                                                      ),
                                                    ],
                                                  )
                                                  : null,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "ROLES CONTAINER",
                                        style: TextStyle(fontFamily: 'Rye'),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              "GAME SETTINGS",
                                              style: TextStyle(
                                                fontFamily: 'Rye',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_isHost)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8.0,
                                          ),
                                          child: MenuButton(
                                            text: 'START GAME',
                                            onPressed:
                                                players.length >= 4
                                                    ? _startGame
                                                    : null,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
