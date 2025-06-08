// MOBİL LOBBY ROOM PAGE - İki kolonlu layout: Sol tarafta oyuncular, sağ tarafta rol ve ayarlar
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/player_avatar.dart';
import '../models/player.dart';
import '../models/role.dart';
import '../utils/role_icons.dart';
import '../services/lobby_service.dart';
import '../widgets/role_management_dialog.dart';
import '../widgets/game_settings_dialog.dart';
import 'game_screen.dart';
import 'main_menu.dart';

class MobileLobbyRoomPage extends StatefulWidget {
  final String roomName;
  final String lobbyCode;

  const MobileLobbyRoomPage({
    super.key,
    required this.roomName,
    required this.lobbyCode,
  });

  @override
  State<MobileLobbyRoomPage> createState() => _MobileLobbyRoomPageState();
}

class _MobileLobbyRoomPageState extends State<MobileLobbyRoomPage>
    with WidgetsBindingObserver {
  final LobbyService _lobbyService = LobbyService();
  List<Player> players = [];
  bool _isLoading = false;
  bool _isHost = false;
  String _currentUserId = '';
  Map<String, int> _currentRoles = {};
  Map<String, dynamic> _currentSettings = {};
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _leaveLobby();
    }
  }

  @override
  void dispose() {
    _lobbySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupLobbyListener() {
    _lobbySubscription = FirebaseFirestore.instance
        .collection('lobbies')
        .doc(widget.lobbyCode.toUpperCase())
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lobby has been deleted'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainMenu(
                username: FirebaseAuth.instance.currentUser?.displayName ??
                    FirebaseAuth.instance.currentUser?.email
                        ?.split('@')[0] ??
                    'Player',
              ),
            ),
            (route) => false,
          );
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final playersList = (data['players'] as List<dynamic>? ?? [])
          .map((p) {
            final map = p as Map<String, dynamic>;
            final playerId = map['id'] ?? map['uid'] ?? '';
            return Player(
              id: playerId,
              name: map['name'] ?? 'Player',
              isLeader: playerId == (data['hostUid'] ?? ''),
              role: map['role'],
              isAlive: map['isAlive'] ?? true,
              team: map['team'],
              profilePicture: map['profilePicture'] as String?,
            );
          }).toList();

      if (data['status'] == 'started') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                GameScreen(lobbyCode: widget.lobbyCode, isHost: _isHost),
          ),
        );
        return;
      }      setState(() {
        players = playersList;
        _isHost = _currentUserId == (data['hostUid'] ?? '');
        _currentRoles = Map<String, int>.from(data['roles'] ?? {});
        
        // Always populate with default values if not set
        final gameSettings = Map<String, dynamic>.from(data['gameSettings'] ?? {});
        _currentSettings = {
          'votingTime': gameSettings['votingTime'] ?? 45,
          'discussionTime': gameSettings['discussionTime'] ?? 90,
          'nightTime': gameSettings['nightTime'] ?? 60,
          'allowFirstNightKill': gameSettings['allowFirstNightKill'] ?? false,
          ...gameSettings, // Add any additional custom settings
        };
        
        _isLoading = false;
      });
    });
  }

  Future<void> _leaveLobby() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isHost) {
      await _lobbyService.leaveAsHostWithTransfer(widget.lobbyCode, user.uid);
    } else {
      await _lobbyService.leaveLobby(widget.lobbyCode, user.uid);
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MainMenu(
            username: user.displayName ?? user.email?.split('@')[0] ?? 'Player',
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
        body: jsonEncode({'lobbyCode': widget.lobbyCode, 'hostId': user.uid}),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to start game');
      }

      // Success - the lobby listener will handle navigation to GameScreen
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
  Future<void> _updateRoleDistribution(Map<String, int> newRoles) async {
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

  Future<void> _updateGameSettings(Map<String, dynamic> newSettings) async {
    try {
      await FirebaseFirestore.instance
          .collection('lobbies')
          .doc(widget.lobbyCode.toUpperCase())
          .update({'gameSettings': newSettings});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game settings updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update game settings: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.brown),
            )
          : Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/backgrounds/saloon_bg.png"),
                  fit: BoxFit.cover,
                ),
              ),              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12.0 : 16.0),
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(),
                      SizedBox(height: MediaQuery.of(context).size.width < 600 ? 12 : 16),// Main content - Two columns
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {                            // More responsive layout based on screen dimensions
                            final screenWidth = MediaQuery.of(context).size.width;
                              // Very small screens (phones in landscape or very small displays)
                            if (constraints.maxHeight < 400 || screenWidth < 600) {
                              return Column(
                                children: [
                                  // Players section - give more space for better visibility
                                  SizedBox(
                                    height: math.min(constraints.maxHeight * 0.55, 280),
                                    child: _buildPlayersSection(),
                                  ),
                                  const SizedBox(height: 6),
                                  // Roles and Settings section - more compact
                                  Expanded(
                                    child: _buildRolesAndSettingsSection(),
                                  ),
                                ],
                              );
                            } 
                            // Medium screens - still vertical but more balanced
                            else if (constraints.maxHeight < 600) {
                              return Column(
                                children: [
                                  SizedBox(
                                    height: constraints.maxHeight * 0.6,
                                    child: _buildPlayersSection(),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _buildRolesAndSettingsSection(),
                                  ),
                                ],
                              );
                            }
                            // Larger screens - side by side layout
                            else {
                              return Row(
                                children: [
                                  // Left side - Players list
                                  Expanded(
                                    flex: 1,
                                    child: _buildPlayersSection(),
                                  ),
                                  const SizedBox(width: 8),
                                  // Right side - Roles and Settings
                                  Expanded(
                                    flex: 1,
                                    child: _buildRolesAndSettingsSection(),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bottom buttons
                      _buildBottomButtons(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }  Widget _buildHeader() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown, width: 2),
      ),
      child: Column(
        children: [
          Text(
            widget.roomName,
            style: TextStyle(
              fontFamily: 'Rye',
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Code: ',
                style: TextStyle(
                  fontFamily: 'Rye',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.lobbyCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Room code copied to clipboard!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.lobbyCode,
                        style: const TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF8B4513),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PLAYERS (${players.length})',
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: player.isLeader
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: player.isLeader ? Colors.orange : Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Larger profile picture
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: PlayerAvatar(
                            name: player.name,
                            isLeader: player.isLeader,
                            isDead: !player.isAlive,
                            profilePicture: player.profilePicture,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Player info - takes up more space
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.name,
                                style: TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 16,
                                  color: player.isLeader ? Colors.orange : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (player.isLeader)
                                const Text(
                                  'Host',
                                  style: TextStyle(
                                    fontFamily: 'Rye',
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Action buttons for host
                        if (_isHost && player.id != _currentUserId)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                onPressed: () => _lobbyService.kickPlayer(
                                  widget.lobbyCode,
                                  player.id,
                                  _currentUserId,
                                ),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.star, color: Colors.orange, size: 20),
                                onPressed: () => _lobbyService.transferHost(
                                  widget.lobbyCode,
                                  player.id,
                                ),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesAndSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown, width: 2),
      ),
      child: Column(
        children: [
          // Header with buttons
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF8B4513),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _isHost
                          ? () {
                              showDialog(
                                context: context,
                                builder: (context) => RoleManagementDialog(
                                  currentRoles: _currentRoles,
                                  onRolesUpdated: _updateRoleDistribution,
                                  playerCount: players.length,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isHost ? const Color(0xFF8B4513) : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'ROLE MANAGE',
                        style: TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _isHost
                          ? () {
                              showDialog(
                                context: context,
                                builder: (context) => GameSettingsDialog(
                                  currentSettings: _currentSettings,
                                  onSettingsUpdated: _updateGameSettings,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isHost ? const Color(0xFF8B4513) : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'GAME SETTINGS',
                        style: TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // Roles section
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ROLES',
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildRolesList(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.brown),
                  // Settings section
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SETTINGS',
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildSettingsList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesList() {
    if (_currentRoles.isEmpty) {
      return const Center(
        child: Text(
          'No roles configured',
          style: TextStyle(
            fontFamily: 'Rye',
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _currentRoles.length,
      itemBuilder: (context, index) {
        final entry = _currentRoles.entries.elementAt(index);
        final roleName = entry.key;
        final roleCount = entry.value;        final role = Role(
          name: roleName,
          imageName: '', // Add required imageName parameter
          count: roleCount,
          description: '',
          team: RoleTeam.neutral,
          shortDescription: '',
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Role.getTeamColor(role.team).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Role.getTeamColor(role.team).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Role.getTeamColor(role.team).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: RoleIcons.buildRoleIcon(
                  roleName: roleName,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  roleName,
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Role.getTeamColor(role.team),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  roleCount.toString(),
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildSettingsList() {
    return ListView(
      children: [
        // Always show core timer settings (now that we populate defaults)
        _buildSettingItem(
          'Voting',
          '${_currentSettings['votingTime'] ?? 45}s',
          Icons.how_to_vote,
        ),
        _buildSettingItem(
          'Discussion',
          '${_currentSettings['discussionTime'] ?? 90}s',
          Icons.chat,
        ),
        _buildSettingItem(
          'Night',
          '${_currentSettings['nightTime'] ?? 60}s',
          Icons.nightlight_round,
        ),
        
        // Always show game rules
        _buildBooleanSettingItem(
          'First Night Kill',
          _currentSettings['allowFirstNightKill'] ?? false,
          Icons.nights_stay,
        ),
        
        // Optional settings (only if explicitly set)
        if (_currentSettings.containsKey('allowSpectators'))
          _buildBooleanSettingItem(
            'Spectators',
            _currentSettings['allowSpectators'] ?? false,
            Icons.visibility,
          ),        if (_currentSettings.containsKey('enableChat'))
          _buildBooleanSettingItem(
            'Chat',
            _currentSettings['enableChat'] ?? true,
            Icons.chat_bubble,
          ),
      ],
    );
  }

  Widget _buildSettingItem(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanSettingItem(String title, bool value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: value ? const Color(0xFF228B22) : const Color(0xFF8B0000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value ? 'ON' : 'OFF',
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildBottomButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _leaveLobby,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B4513),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'LEAVE LOBBY',
                style: TextStyle(
                  fontFamily: 'Rye',
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),        if (_isHost)
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: players.length >= 1 ? _startGame : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: players.length >= 1 ? const Color(0xFF228B22) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),                child: const Text(
                  'START GAME',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
