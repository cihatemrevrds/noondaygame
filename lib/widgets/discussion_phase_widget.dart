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
      child: Column(
        children: [
          // Top - Timer and Discussion text (centered)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
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
                  size: 100, // Slightly smaller for mobile
                  activeBulletColor: Colors.white,
                  inactiveBulletColor: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                // Discussion text
                const Text(
                  'DISCUSSION',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 20,
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

          // Bottom - Players Grid
          Expanded(
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
    // Use responsive grid layout based on actual player count
    int crossAxisCount = 4; // Default to 4 columns

    // Adjust columns based on player count for better layout
    if (widget.players.length <= 6) {
      crossAxisCount = 3;
    } else if (widget.players.length <= 12) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 5;
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.players.length, // Only show actual players
      itemBuilder: (context, index) {
        final player = widget.players[index];
        final isCurrentUser = player.id == widget.currentUserId;

        return Container(
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
                    decoration:
                        player.isAlive ? null : TextDecoration.lineThrough,
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
