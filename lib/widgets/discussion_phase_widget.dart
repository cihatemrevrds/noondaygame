import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/player_avatar.dart';
import '../widgets/bullet_timer_widget.dart';

class DiscussionPhaseWidget extends StatefulWidget {
  final List<Player> players;
  final int remainingTime; // in seconds
  final int totalTime; // total phase duration in seconds
  final String currentUserId;
  final String? myRole;

  const DiscussionPhaseWidget({
    super.key,
    required this.players,
    required this.remainingTime,
    required this.totalTime,
    required this.currentUserId,
    this.myRole,
  });

  @override
  State<DiscussionPhaseWidget> createState() => _DiscussionPhaseWidgetState();
}

class _DiscussionPhaseWidgetState extends State<DiscussionPhaseWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Left side - Timer and Discussion text
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bullet Timer
                  BulletTimerWidget(
                    remainingTime: widget.remainingTime,
                    totalTime: widget.totalTime, // Use actual discussion time
                    size: 120,
                    activeBulletColor: Colors.white,
                    inactiveBulletColor: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(height: 32),
                  // Discussion text
                  const Text(
                    'DISCUSSION',
                    style: TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 24), // Right side - Players Grid
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _buildPlayersGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersGrid() {
    // Ensure we have exactly 20 slots (4 columns x 5 rows)
    final gridPlayers = List<Player?>.filled(20, null);

    // Fill with actual players
    for (int i = 0; i < widget.players.length && i < 20; i++) {
      gridPlayers[i] = widget.players[i];
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 20,
      itemBuilder: (context, index) {
        final player = gridPlayers[index];

        if (player == null) {
          // Empty slot
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
            ),
            child: const Center(
              child: Icon(Icons.person_outline, color: Colors.grey, size: 24),
            ),
          );
        }
        // Player slot
        final isCurrentUser = player.id == widget.currentUserId;        return Container(
          decoration:
              isCurrentUser
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue, width: 3),
                  )
                  : null,
          child: Column(
            children: [
              Expanded(
                child: PlayerAvatar(
                  name: player.name,
                  isLeader: player.isLeader,
                  isDead: !player.isAlive,
                  profilePicture: player.profilePicture,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  player.name,
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 10,
                    color: player.isAlive ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    decoration: player.isAlive ? null : TextDecoration.lineThrough,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
