import 'dart:async';
import 'package:flutter/material.dart';
import '../services/lobby_service.dart';
import '../models/player.dart';
import '../widgets/role_utils.dart';

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
  });

  @override
  State<NightPhaseScreen> createState() => _NightPhaseScreenState();
}

class _NightPhaseScreenState extends State<NightPhaseScreen> {
  String? _selectedPlayerId; // Track the selected player
  Timer? _timer;
  Map<String, dynamic>? _settings;
  int _remainingTime = 0;

  Future<Map<String, dynamic>> _fetchLobbySettings() async {
    return await LobbyService().getLobbySettings(widget.lobbyCode);
  }

  @override
  void initState() {
    super.initState();
    _fetchLobbySettings().then((settings) {
      setState(() {
        _settings = settings;
        _remainingTime = settings['nightPhaseDuration'] ?? 60; // Convert minutes to seconds
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

  Widget _buildNightActionUI() {
    // Rol rengini ve ikonunu belirle
    Color roleColor = RoleUtils.getRoleColor(widget.myRole ?? 'Unknown');
    IconData roleIcon = RoleUtils.getRoleIcon(widget.myRole ?? 'Unknown');

    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            'assets/images/western_town_bg.png',
            fit: BoxFit.cover,
          ),
        ),        // Foreground content
        Column(
          children: [
            // Night bar at the top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.brown,
              child: Text(
                'Night: ${widget.nightNumber}',
                style: const TextStyle(
                  fontFamily: 'Rye',
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),

            // Role logo - larger and more prominent
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: Colors.black,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                roleIcon,
                size: 80,
                color: roleColor,
              ),
            ),
            const SizedBox(height: 20),

            // Role name - larger font
            Text(
              widget.myRole ?? 'Unknown',
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),            // Timer display
            Text(
              'Time Remaining: $_remainingTime seconds',
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 30),            // Player selection area - more organized
            if (widget.players.where((p) => p.isAlive).isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.start,
                    children: widget.players
                      .where((p) => p.isAlive)
                      .map((player) => GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPlayerId = player.id;
                              });
                            },                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _selectedPlayerId == player.id
                                        ? Colors.green.withOpacity(0.8)
                                        : Colors.grey[300],
                                    border: Border.all(
                                      color: _selectedPlayerId == player.id
                                          ? Colors.white
                                          : Colors.grey[400]!,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    size: 45,
                                    color: _selectedPlayerId == player.id
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  player.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),                          ))                      .toList(),
                    ),
                  ),
                ),
            const SizedBox(height: 40),            // Action buttons - rectangular brown buttons side by side
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Skip button - sola
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: widget.isLoading
                          ? null
                          : () {                              widget.onSetNightActionResult(
                                "You chose to skip this night.",
                              );
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
                      ),                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 30), // Space between buttons

                  // Role action button - right side
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: widget.isLoading || _selectedPlayerId == null
                          ? null
                          : () {
                              widget.onNightAction(
                                'sheriffInvestigate',
                                _selectedPlayerId!,
                              );
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
                      ),                      child: const Text(
                        'Action',
                        style: TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: _buildNightActionUI());
  }
}
