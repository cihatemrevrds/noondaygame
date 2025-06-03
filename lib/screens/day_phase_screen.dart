import 'dart:async';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/role_utils.dart';

class DayPhaseScreen extends StatefulWidget {
  final String currentUserId;
  final String? myRole;
  final String? myRoleDesc;
  final List<Player> players;
  final String? votedPlayerId;
  final bool isLoading;
  final Function(String) onVotePlayer;
  final Function(String?) onSetNightActionResult;
  final int dayPhaseDuration; // Duration in seconds
  final Map<String, dynamic> settings; // Add settings parameter

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
    required this.dayPhaseDuration,
    required this.settings, // Add settings parameter
  });

  @override
  _DayPhaseScreenState createState() => _DayPhaseScreenState();
}

class _DayPhaseScreenState extends State<DayPhaseScreen> {
  late int remainingTime;
  late Timer timer;

  @override
  void initState() {
    super.initState();
    remainingTime = widget.dayPhaseDuration;
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Display settings for debugging or informational purposes
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Settings: ${widget.settings}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),

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
                  RoleUtils.getRoleIcon(widget.myRole ?? 'Unknown'),
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
                  widget.myRole ?? 'Unknown',
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
                  widget.myRoleDesc ?? 'Rol açıklaması yükleniyor...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              // Kalan süre
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Kalan Süre: ${remainingTime}s',
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
            itemCount: widget.players.length,
            itemBuilder: (context, index) {
              final player = widget.players[index];
              final isCurrentUser = player.id == widget.currentUserId;
              final isSelected = widget.votedPlayerId == player.id;

              return GestureDetector(
                onTap: isCurrentUser || player.isAlive == false
                    ? null
                    : () => widget.onVotePlayer(player.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.red.withOpacity(0.7)
                        : Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentUser
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
                          color: player.isAlive == false
                              ? Colors.grey
                              : Colors.blue[300],
                        ),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: player.isAlive == false
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
                          color: player.isAlive == false
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
        if (remainingTime == 0)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Pas geç butonu
                ElevatedButton(
                  onPressed: widget.isLoading
                      ? null
                      : () {
                          widget.onSetNightActionResult("Oylamada pas geçtin.");
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
                  onPressed: widget.votedPlayerId == null || widget.isLoading
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
  }
}
