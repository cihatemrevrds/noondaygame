import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/player_avatar.dart';
import '../widgets/bullet_timer_widget.dart';

class VotingPhaseWidget extends StatefulWidget {
  final List<Player> players;
  final int remainingTime; // in seconds
  final int totalTime; // total phase duration in seconds
  final String currentUserId;
  final String? myRole;
  final Function(String?)? onVoteChanged; // Callback when vote changes

  const VotingPhaseWidget({
    super.key,
    required this.players,
    required this.remainingTime,
    required this.totalTime,
    required this.currentUserId,
    this.myRole,
    this.onVoteChanged,
  });

  @override
  State<VotingPhaseWidget> createState() => _VotingPhaseWidgetState();
}

class _VotingPhaseWidgetState extends State<VotingPhaseWidget> {
  String? _selectedPlayerId; // The player ID we're voting for
  @override
  void initState() {
    super.initState();
  }

  void _toggleVote(String playerId) {
    setState(() {
      if (_selectedPlayerId == playerId) {
        // Remove vote from currently selected player
        _selectedPlayerId = null;
      } else {
        // Vote for this player (automatically removes vote from previous player)
        _selectedPlayerId = playerId;
      }
    });

    // Notify parent widget about vote change
    if (widget.onVoteChanged != null) {
      widget.onVoteChanged!(_selectedPlayerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Left side - Timer and Voting text
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
                    totalTime: widget.totalTime, // Use actual voting time
                    size: 120,
                    activeBulletColor: Colors.orange,
                    inactiveBulletColor: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(height: 32),
                  // Voting text
                  const Text(
                    'VOTING',
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
                  const SizedBox(height: 16),
                  // Current vote status
                  if (_selectedPlayerId != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: Text(
                        'Voting for:\n${widget.players.firstWhere((p) => p.id == _selectedPlayerId).name}',
                        style: const TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: const Text(
                        'No vote cast',
                        style: TextStyle(
                          fontFamily: 'Rye',
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Right side - Players Grid with voting buttons
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.9, // Slightly adjusted for smaller buttons
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: widget.players.length,
          itemBuilder: (context, index) {
            final player = widget.players[index];

            // Can't vote for yourself or dead players
            final canVote = player.id != widget.currentUserId && player.isAlive;
            final isSelected = _selectedPlayerId == player.id;

            return Column(
              children: [
                // Player Avatar
                Expanded(
                  child: PlayerAvatar(
                    name: player.name,
                    isLeader: player.isLeader,
                    isDead: !player.isAlive,
                  ),
                ),
                // Vote Button
                if (canVote)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 2.0,
                      left: 4.0,
                      right: 4.0,
                      bottom: 2.0,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 20,
                      child: ElevatedButton(
                        onPressed: () => _toggleVote(player.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSelected
                                  ? Colors.orange
                                  : const Color(0xFF8B4513),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 1,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          minimumSize: const Size(0, 20),
                        ),
                        child: Text(
                          isSelected ? 'REMOVE' : 'VOTE',
                          style: const TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  // Placeholder for dead players or current user
                  const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }
}
