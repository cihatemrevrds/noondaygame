// GÜNCELLENMİŞ LOBBYROOMPAGE - Sabit grid yapısı ve responsive layout entegre edildi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/menu_button.dart';
import '../widgets/player_avatar.dart';
import '../models/player.dart';
import '../models/role.dart';
import '../utils/role_icons.dart';
import '../services/lobby_service.dart';
import '../widgets/role_management_dialog.dart';
import '../widgets/game_settings_dialog.dart';
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
  void dispose() {
    _lobbySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes to prevent lobby leaks
    switch (state) {
      case AppLifecycleState.paused:
        // App went to background (Alt+Tab, minimized, etc.) - do nothing
        // Users should stay in lobby when switching between apps
        break;
      case AppLifecycleState.detached:
        // App is being terminated - immediate cleanup
        _performEmergencyCleanup();
        break;
      case AppLifecycleState.inactive:
        // App is inactive but not necessarily closing - do nothing
        // This can happen during transitions or when system dialogs appear
        break;
      case AppLifecycleState.resumed:
        // App resumed - nothing to do since we don't schedule cleanup on pause
        break;
      case AppLifecycleState.hidden:
        // App is hidden - do nothing for now
        // This is a newer state that indicates the app is not visible
        break;
    }
  }

  void _performEmergencyCleanup() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Don't wait for the result, just fire and forget
      if (_isHost) {
        _lobbyService.leaveAsHostWithTransfer(widget.lobbyCode, user.uid);
      } else {
        _lobbyService.leaveLobby(widget.lobbyCode, user.uid);
      }
    }
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
          final isHost =
              hostUid == _currentUserId; // Load current roles configuration
          final rolesData = data['roles'] as Map<String, dynamic>? ?? {};
          final currentRoles = <String, int>{};
          rolesData.forEach((key, value) {
            if (value is int && value > 0) {
              currentRoles[key] = value;
            }
          }); // Load current game settings
          final settingsData =
              data['gameSettings'] as Map<String, dynamic>? ?? {};
          final currentSettings = <String, dynamic>{
            'votingTime': settingsData['votingTime'] ?? 45,
            'discussionTime': settingsData['discussionTime'] ?? 90,
            'nightTime': settingsData['nightTime'] ?? 60,
            'allowFirstNightKill': settingsData['allowFirstNightKill'] ?? false,
          };

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
                  profilePicture: map['profilePicture'] as String?,
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
            _currentSettings = currentSettings;
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
            playerCount: players.length,
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

  Future<void> _showGameSettingsDialog() async {
    showDialog(
      context: context,
      builder:
          (context) => GameSettingsDialog(
            currentSettings: _currentSettings,
            onSettingsUpdated: _updateGameSettings,
          ),
    );
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
                        image: AssetImage(
                          "assets/images/backgrounds/saloon_bg.png",
                        ),
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
                                    child: Column(
                                      children: [
                                        // Header
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
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'PLAYERS',
                                                style: TextStyle(
                                                  fontFamily: 'Rye',
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Players list
                                        Expanded(
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
                                                leading: SizedBox(
                                                  width: 32,
                                                  height: 32,
                                                  child: PlayerAvatar(
                                                    name: player.name,
                                                    isLeader: player.isLeader,
                                                    isDead: !player.isAlive,
                                                    profilePicture:
                                                        player.profilePicture,
                                                  ),
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
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              onPressed:
                                                                  () => _lobbyService
                                                                      .kickPlayer(
                                                                        widget
                                                                            .lobbyCode,
                                                                        player
                                                                            .id,
                                                                        _currentUserId,
                                                                      ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.star,
                                                                color:
                                                                    Colors
                                                                        .orange,
                                                              ),
                                                              onPressed:
                                                                  () => _lobbyService
                                                                      .transferHost(
                                                                        widget
                                                                            .lobbyCode,
                                                                        player
                                                                            .id,
                                                                      ),
                                                            ),
                                                          ],
                                                        )
                                                        : null,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
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
                                                              child:
                                                                  RoleIcons.buildRoleIcon(
                                                                    roleName:
                                                                        roleName,
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
                                          child: Column(
                                            children: [
                                              // Header with manage button
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 16,
                                                    ),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF8B4513),
                                                  borderRadius:
                                                      BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(10),
                                                        topRight:
                                                            Radius.circular(10),
                                                      ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text(
                                                      'GAME SETTINGS',
                                                      style: TextStyle(
                                                        fontFamily: 'Rye',
                                                        fontSize: 18,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    if (_isHost)
                                                      InkWell(
                                                        onTap:
                                                            _showGameSettingsDialog,
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
                                                              color:
                                                                  Colors
                                                                      .white54,
                                                            ),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons.tune,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                size: 16,
                                                              ),
                                                              SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                'CHANGE RULES',
                                                                style: TextStyle(
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
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ), // Settings list
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      // Timer Settings
                                                      _buildSettingItem(
                                                        'Voting Time',
                                                        '${_currentSettings['votingTime'] ?? 45}s',
                                                        Icons.how_to_vote,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildSettingItem(
                                                        'Discussion Time',
                                                        '${_currentSettings['discussionTime'] ?? 90}s',
                                                        Icons.chat,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildSettingItem(
                                                        'Night Time',
                                                        '${_currentSettings['nightTime'] ?? 60}s',
                                                        Icons.nightlight_round,
                                                      ),

                                                      // Divider between timer and rule settings
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      Container(
                                                        height: 1,
                                                        color: Colors.black26,
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 12,
                                                      ), // Game Rule Settings
                                                      _buildBooleanSettingItem(
                                                        'First Night Kill',
                                                        _currentSettings['allowFirstNightKill'] ??
                                                            false,
                                                        Icons.nightlight_round,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildBooleanSettingItem(
                                                        'Disable Win Conditions',
                                                        _currentSettings['disableWinConditions'] ??
                                                            false,
                                                        Icons.bug_report,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
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

  Widget _buildSettingItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
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
  }

  Widget _buildBooleanSettingItem(String title, bool value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:
                  value
                      ? const Color(0xFF228B22)
                      : const Color(
                        0xFF8B0000,
                      ), // Green for true, Red for false
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value ? 'ON' : 'OFF',
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
  }
}
