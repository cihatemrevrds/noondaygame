import 'package:flutter/material.dart';
import 'dart:async';
import '../models/player.dart';
import '../widgets/role_utils.dart';
import '../services/lobby_service.dart';

class TimerWidget extends StatefulWidget {
  final int dayPhaseDuration;

  const TimerWidget({super.key, required this.dayPhaseDuration});

  @override
  _TimerWidgetState createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  late int remainingTime;
  late Timer timer;

  @override
  void initState() {
    super.initState();
    remainingTime = widget.dayPhaseDuration;
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        setState(() {
          remainingTime--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Kalan Süre: ${remainingTime}s',
      style: const TextStyle(
        fontFamily: 'Rye',
        fontSize: 20,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class DayPhaseScreen extends StatelessWidget {
  final String currentUserId;
  final String? myRole;
  final String? myRoleDesc;
  final List<Player> players;
  final String? votedPlayerId;
  final bool isLoading;
  final Function(String) onVotePlayer;
  final Function(String?) onSetNightActionResult;

  const DayPhaseScreen({
    super.key,
    required this.currentUserId,
    required this.myRole,
    required this.myRoleDesc,
    required this.players,
    required this.votedPlayerId,
    required this.isLoading,
    required this.onVotePlayer,
    required this.onSetNightActionResult,
  });
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: LobbyService().getLobbySettings('lobbyCode'), // Replace 'lobbyCode' with actual lobby code
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Safely retrieve dayPhaseDuration with a default value
        final dayPhaseDuration = snapshot.data!['dayPhaseDuration'] ?? 60; // Default to 60 seconds if null

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Timer Section
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: TimerWidget(dayPhaseDuration: dayPhaseDuration),
            ),

            // Üst kısım: Rol bilgisi
            Padding(
              padding: const EdgeInsets.only(top: 20), // Reduced from 50 to 20
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
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      RoleUtils.getRoleIcon(myRole ?? 'Unknown'),
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Rol adı
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      myRole ?? 'Unknown',
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
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      myRoleDesc ?? 'Rol açıklaması yükleniyor...',
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
                  crossAxisCount: 3,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isCurrentUser = player.id == currentUserId;
                  final isSelected = votedPlayerId == player.id;

                  return GestureDetector(
                    onTap:
                        isCurrentUser || player.isAlive == false
                            ? null
                            : () => onVotePlayer(player.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.red.withValues(alpha: 0.7)
                                : Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isCurrentUser
                                  ? Colors.yellow
                                  : isSelected
                                  ? Colors.red
                                  : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Oyuncu avatarı
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  player.isAlive == false
                                      ? Colors.grey
                                      : Colors.blue[300],
                            ),
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color:
                                  player.isAlive == false
                                      ? Colors.grey[400]
                                      : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Oyuncu adı
                          Text(
                            player.name,
                            style: TextStyle(
                              fontFamily: 'Rye',
                              fontSize: 12,
                              color:
                                  player.isAlive == false
                                      ? Colors.grey[400]
                                      : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (player.isAlive == false)
                            const Text(
                              'ÖLDÜ',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Alt kısım: Aksiyon butonları
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Pas geç butonu
                  ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : () {
                          onSetNightActionResult("Oylamada pas geçtin.");
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
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
                    onPressed:
                        votedPlayerId == null || isLoading
                            ? null
                            : () {
                          // Bu durumda day phase'de oy verme işlemi yapılır
                          // Oylama mekanizması farklı olduğu için burası güncellenebilir
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[800],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Oy Ver',
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
        );
      },
    );
  }
}
