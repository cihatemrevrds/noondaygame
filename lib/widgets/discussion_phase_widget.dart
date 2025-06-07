import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/player_avatar.dart';

class DiscussionPhaseWidget extends StatefulWidget {
  final List<Player> players;
  final int remainingTime; // in seconds
  final String currentUserId;
  final String? myRole;

  const DiscussionPhaseWidget({
    super.key,
    required this.players,
    required this.remainingTime,
    required this.currentUserId,
    this.myRole,
  });

  @override
  State<DiscussionPhaseWidget> createState() => _DiscussionPhaseWidgetState();
}

class _DiscussionPhaseWidgetState extends State<DiscussionPhaseWidget>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize timer animation
    _timerController = AnimationController(
      duration: Duration(seconds: widget.remainingTime),
      vsync: this,
    );

    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _timerController, curve: Curves.linear));

    // Start the timer
    _timerController.forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
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
                  // Circular Timer
                  Container(
                    width: 120,
                    height: 120,
                    child: Stack(
                      children: [
                        // Background circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 3,
                            ),
                          ),
                        ),
                        // Progress circle
                        AnimatedBuilder(
                          animation: _timerAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: _timerAnimation.value,
                                strokeWidth: 6,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _timerAnimation.value > 0.3
                                      ? Colors.white
                                      : Colors.red,
                                ),
                              ),
                            );
                          },
                        ),
                        // Time text
                        Center(
                          child: AnimatedBuilder(
                            animation: _timerAnimation,
                            builder: (context, child) {
                              final remainingSeconds =
                                  (widget.remainingTime * _timerAnimation.value)
                                      .round();
                              return Text(
                                _formatTime(remainingSeconds),
                                style: TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      remainingSeconds <= 30
                                          ? Colors.red
                                          : Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.8),
                                      blurRadius: 4,
                                      offset: const Offset(1, 1),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
