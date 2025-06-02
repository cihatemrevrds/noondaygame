// GÜNCELLENMİŞ LOBBYROOMPAGE - Sabit grid yapısı ve responsive layout entegre edildi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/menu_button.dart';
import '../models/player.dart';
import '../models/role.dart';
import '../services/lobby_service.dart';
import '../widgets/role_management_dialog.dart';
import 'game_screen.dart';
import 'main_menu.dart';

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
  Map<String, int> _currentRoles = {};
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
            // Lobby deleted, navigate to main menu since user is already logged in
            final user = FirebaseAuth.instance.currentUser;
            if (mounted && user != null) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => MainMenu(
                        username:
                            user.displayName ??
                            user.email?.split('@')[0] ??
                            'Player',
                      ),
                ),
                (route) => false,
              );
            }
            return;
          }
          final data = snapshot.data();
          if (data == null) return;

          final hostUid = data['hostUid'] as String?;
          final isHost = hostUid == _currentUserId;

          // Load current roles configuration
          final rolesData = data['roles'] as Map<String, dynamic>? ?? {};
          final currentRoles = <String, int>{};
          rolesData.forEach((key, value) {
            if (value is int && value > 0) {
              currentRoles[key] = value;
            }
          });
          final playersData = data['players'] as List<dynamic>? ?? [];

          final playersList =
              playersData.map((p) {
                final map = p as Map<String, dynamic>;
                final playerId = map['id'] ?? map['uid'] ?? '';
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
                    (context) =>
                        GameScreen(lobbyCode: widget.lobbyCode, isHost: isHost),
              ),
            );
            return;
          }
          setState(() {
            players = playersList;
            _isHost = isHost;
            _currentRoles = currentRoles;
            _isLoading = false;
          });
        });
  }

  Future<void> _leaveLobby() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_isHost) {
      // If host is leaving, transfer host to another player instead of deleting lobby
      await _lobbyService.leaveAsHostWithTransfer(widget.lobbyCode, user.uid);
    } else {
      await _lobbyService.leaveLobby(widget.lobbyCode, user.uid);
    }
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder:
              (context) => MainMenu(
                username:
                    user.displayName ?? user.email?.split('@')[0] ?? 'Player',
              ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _startGame() async {
    if (!_isHost || players.length < 1) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final response = await http.post(
        Uri.parse('https://startgame-uerylfny3q-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'lobbyCode': widget.lobbyCode, 'hostId': user.uid}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to start game');
      }

      // Success - the lobby listener will handle navigation to RoleSelectionPage
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start game: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyCodeToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.lobbyCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room code copied to clipboard')),
    );
  }

  Future<void> _showRoleManagementDialog() async {
    showDialog(
      context: context,
      builder:
          (context) => RoleManagementDialog(
            currentRoles: _currentRoles,
            onRolesUpdated: _updateRoles,
          ),
    );
  }

  Future<void> _updateRoles(Map<String, int> newRoles) async {
    try {
      await FirebaseFirestore.instance
          .collection('lobbies')
          .doc(widget.lobbyCode.toUpperCase())
          .update({'roles': newRoles});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Roles updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update roles: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                                    child: Column(
                                      children: [
                                        // Header with manage button
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF8B4513),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(10),
                                              topRight: Radius.circular(10),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'ROLES',
                                                style: TextStyle(
                                                  fontFamily: 'Rye',
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (_isHost)
                                                InkWell(
                                                  onTap:
                                                      _showRoleManagementDialog,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFD2691E,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.settings,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'MANAGE',
                                                          style: TextStyle(
                                                            fontFamily: 'Rye',
                                                            fontSize: 12,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Roles list
                                        Expanded(
                                          child:
                                              _currentRoles.isEmpty
                                                  ? const Center(
                                                    child: Padding(
                                                      padding: EdgeInsets.all(
                                                        16,
                                                      ),
                                                      child: Text(
                                                        'No roles configured.\nHost can manage roles above.',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontFamily: 'Rye',
                                                          fontSize: 14,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  : ListView.builder(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    itemCount:
                                                        _currentRoles.length,
                                                    itemBuilder: (
                                                      context,
                                                      index,
                                                    ) {
                                                      final entry =
                                                          _currentRoles.entries
                                                              .elementAt(index);
                                                      final roleName =
                                                          entry.key;
                                                      final roleCount =
                                                          entry.value;
                                                      final allRoles =
                                                          Role.getAllRoles();
                                                      final role = allRoles
                                                          .firstWhere(
                                                            (r) =>
                                                                r.name ==
                                                                roleName,
                                                            orElse:
                                                                () => Role(
                                                                  name:
                                                                      roleName,
                                                                  imageName: '',
                                                                  count:
                                                                      roleCount,
                                                                  description:
                                                                      '',
                                                                  team:
                                                                      RoleTeam
                                                                          .neutral,
                                                                  shortDescription:
                                                                      '',
                                                                ),
                                                          );

                                                      return Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Role.getTeamColor(
                                                                role.team,
                                                              ).withOpacity(
                                                                0.1,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                Role.getTeamColor(
                                                                  role.team,
                                                                ).withOpacity(
                                                                  0.3,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              width: 32,
                                                              height: 32,
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    Role.getTeamColor(
                                                                      role.team,
                                                                    ).withOpacity(
                                                                      0.2,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                              child: Icon(
                                                                _getRoleIcon(
                                                                  roleName,
                                                                ),
                                                                color:
                                                                    Role.getTeamColor(
                                                                      role.team,
                                                                    ),
                                                                size: 20,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                roleName,
                                                                style: const TextStyle(
                                                                  fontFamily:
                                                                      'Rye',
                                                                  fontSize: 14,
                                                                  color:
                                                                      Colors
                                                                          .black87,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical: 4,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    Role.getTeamColor(
                                                                      role.team,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                roleCount
                                                                    .toString(),
                                                                style: const TextStyle(
                                                                  fontFamily:
                                                                      'Rye',
                                                                  fontSize: 12,
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                        ),

                                        // Total count
                                        if (_currentRoles.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF654321),
                                              borderRadius: BorderRadius.only(
                                                bottomLeft: Radius.circular(10),
                                                bottomRight: Radius.circular(
                                                  10,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.group,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Total: ${_currentRoles.values.fold(0, (sum, count) => sum + count)}',
                                                  style: const TextStyle(
                                                    fontFamily: 'Rye',
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
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
                                                players.length >= 1
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

  IconData _getRoleIcon(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'doctor':
        return Icons.local_hospital;
      case 'sheriff':
        return Icons.security;
      case 'escort':
        return Icons.block;
      case 'peeper':
        return Icons.visibility;
      case 'gunslinger':
        return Icons.gps_fixed;
      case 'gunman':
        return Icons.gps_off;
      case 'chieftain':
        return Icons.star;
      case 'jester':
        return Icons.theater_comedy;
      default:
        return Icons.person;
    }
  }
}
