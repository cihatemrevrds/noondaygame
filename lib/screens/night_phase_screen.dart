import 'dart:async';
import 'package:flutter/material.dart';
import '../services/lobby_service.dart';
import '../models/player.dart';
import '../utils/role_icons.dart';
import '../widgets/player_avatar.dart';

class NightPhaseScreen extends StatefulWidget {
  final String lobbyCode;
  final String currentUserId;
  final String? myRole;
  final String? myRoleDesc;
  final String? nightActionResult;
  final List<Player> players;
  final bool isLoading;
  final Function(String, String) onNightAction;
  final Function(String?) onSetNightActionResult;
  final int nightNumber; // Night number
  final Map<String, dynamic>? roleData; // Add roleData parameter

  const NightPhaseScreen({
    super.key,
    required this.lobbyCode,
    required this.currentUserId,
    required this.myRole,
    required this.myRoleDesc,
    required this.nightActionResult,
    required this.players,
    required this.isLoading,
    required this.onNightAction,
    required this.onSetNightActionResult,
    required this.nightNumber,
    this.roleData, // Add to constructor
  });

  @override
  State<NightPhaseScreen> createState() => _NightPhaseScreenState();
}

class _NightPhaseScreenState extends State<NightPhaseScreen> {
  String? _selectedPlayerId; // Track the selected player
  Timer? _timer;
  int _remainingTime = 0;

  // Helper method to get the correct action based on role
  String _getRoleAction(String? role) {
    switch (role) {
      case 'Doctor':
        return 'doctorProtect';
      case 'Gunman':
        return 'gunmanKill';
      case 'Sheriff':
        return 'sheriffInvestigate';
      case 'Escort':
        return 'prostituteBlock'; // Using prostituteBlock as per game_service.dart
      case 'Peeper':
        return 'peeperSpy';
      case 'Chieftain':
        return 'chieftainOrder';
      case 'Gunslinger':
        return 'gunslingerShoot';
      default:
        return ''; // No action for other roles
    }
  }

  // Helper method to get button text based on role
  String _getActionButtonText(String? role) {
    switch (role) {
      case 'Doctor':
        return 'Protect';
      case 'Gunman':
        return 'Kill';
      case 'Sheriff':
        return 'Investigate';
      case 'Escort':
        return 'Block';
      case 'Peeper':
        return 'Spy';
      case 'Chieftain':
        return 'Order Kill';
      case 'Gunslinger':
        return 'Shoot';
      default:
        return 'Action';
    }
  }

  // Helper method to check if role has night action
  bool _hasNightAction(String? role) {
    switch (role) {
      case 'Doctor':
      case 'Gunman':
      case 'Sheriff':
      case 'Escort':
      case 'Peeper':
      case 'Chieftain':
      case 'Gunslinger':
        return true;
      default:
        return false; // Jester doesn't have night actions
    }
  }

  Future<Map<String, dynamic>> _fetchLobbySettings() async {
    return await LobbyService().getLobbySettings(widget.lobbyCode);
  }

  @override
  void initState() {
    super.initState();
    _fetchLobbySettings().then((settings) {
      setState(() {
        _remainingTime =
            settings['nightPhaseDuration'] ?? 60; // Convert minutes to seconds
      });
      _startTimer();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Build player selection area for roles with night actions
  Widget _buildPlayerSelectionArea() {
    if (widget.players.where((p) => p.isAlive).isEmpty) return Container();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 800 ? 40 : 20,
      ),
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width > 800 ? 30 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Center(
        child: Wrap(
          spacing: MediaQuery.of(context).size.width > 800 ? 30 : 20,
          runSpacing: MediaQuery.of(context).size.width > 800 ? 30 : 20,
          alignment: WrapAlignment.center,          children:
              widget.players
                  .where(
                    (p) {
                      // Always show alive players
                      if (!p.isAlive) return false;
                      
                      // For Doctor role, handle self-protection limitation
                      if (widget.myRole == 'Doctor') {
                        // Always show other players
                        if (p.id != widget.currentUserId) return true;
                        
                        // For self (Doctor protecting themselves):
                        // Check if doctor has already used self-protection
                        final doctorData = widget.roleData?['doctor']?[widget.currentUserId] as Map<String, dynamic>?;
                        final selfProtectionUsed = doctorData?['selfProtectionUsed'] ?? false;
                        
                        // Only show self if self-protection hasn't been used yet
                        return !selfProtectionUsed;
                      }
                      
                      // For other roles, don't show self
                      return p.id != widget.currentUserId;
                    },
                  )
                  .map(
                    (player) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPlayerId = player.id;
                        });
                      },
                      child: Column(
                        children: [
                          Container(
                            width:
                                MediaQuery.of(context).size.width > 800
                                    ? 90
                                    : 80,
                            height:
                                MediaQuery.of(context).size.width > 800
                                    ? 90
                                    : 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    _selectedPlayerId == player.id
                                        ? Colors.green
                                        : Colors.transparent,
                                width: 3,
                              ),
                            ),                            child: PlayerAvatar(
                              name: player.name,
                              isLeader: player.isLeader,
                              isDead: !player.isAlive,
                              profilePicture: player.profilePicture,
                              playerRole: player.role,
                              currentUserRole: widget.myRole,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width > 800
                                    ? 100
                                    : 80,
                            child: Text(
                              player.name,
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width > 800
                                        ? 16
                                        : 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  // Build message for roles without night actions
  Widget _buildNoActionMessage() {
    String message;
    switch (widget.myRole) {
      case 'Jester':
        message =
            'You have no night ability.\nWait for the day phase to achieve your goal.';
        break;
      default:
        message = 'You have no night action.\nWait for the night to end.';
        break;
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 800 ? 40 : 20,
      ),
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width > 800 ? 30 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'Rye',
          fontSize: MediaQuery.of(context).size.width > 800 ? 18 : 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Build action buttons
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Role action button - conditional on role capability
          if (_hasNightAction(widget.myRole))
            SizedBox(
              width: 140,
              child: ElevatedButton(
                onPressed:
                    widget.isLoading || _selectedPlayerId == null
                        ? null
                        : () {
                          String action = _getRoleAction(widget.myRole);
                          if (action.isNotEmpty) {
                            widget.onNightAction(action, _selectedPlayerId!);
                          }
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _getActionButtonText(widget.myRole),
                  style: const TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            // Placeholder for roles without night actions
            SizedBox(
              width: 140,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Wait',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNightActionUI() {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/western_town_night_bg.jpg',
            fit: BoxFit.cover,
          ),
        ),
        // Foreground content
        Positioned.fill(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Night bar at the top

                // Role logo - responsive sizing
                Container(
                  width: MediaQuery.of(context).size.width > 800 ? 140 : 100,
                  height: MediaQuery.of(context).size.width > 800 ? 140 : 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: RoleIcons.buildRoleIcon(
                    roleName: widget.myRole ?? 'Unknown',
                    size: MediaQuery.of(context).size.width > 800 ? 80 : 60,
                  ),
                ),
                const SizedBox(height: 20),

                // Role name - responsive font size
                Text(
                  widget.myRole ?? 'Unknown',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: MediaQuery.of(context).size.width > 800 ? 32 : 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Timer display
                Text(
                  'Time Remaining: $_remainingTime seconds',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: MediaQuery.of(context).size.width > 800 ? 18 : 16,
                    color: Colors.white,
                  ),
                ),

                SizedBox(
                  height: MediaQuery.of(context).size.width > 800 ? 30 : 20,
                ), // Player selection area - responsive layout
                if (_hasNightAction(widget.myRole))
                  _buildPlayerSelectionArea()
                else
                  _buildNoActionMessage(),

                const SizedBox(height: 40),

                // Action buttons - rectangular brown buttons side by side
                _buildActionButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: _buildNightActionUI());
  }
}
