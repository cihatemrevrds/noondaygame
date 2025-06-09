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
      child: Column(
        children: [
          // Top - Timer and Voting text (centered)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bullet Timer
                BulletTimerWidget(
                  remainingTime: widget.remainingTime,
                  totalTime: widget.totalTime, // Use actual voting time
                  size: 100, // Slightly smaller for mobile
                  activeBulletColor: Colors.orange,
                  inactiveBulletColor: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 16), // Voting text
                const Text(
                  'VOTING',
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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

          // Bottom - Players Grid with voting buttons
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 800;

        // Use responsive grid layout based on platform and player count
        int crossAxisCount;
        double childAspectRatio;
        double spacing;

        if (isMobile) {
          // Mobile layout - keep existing behavior
          crossAxisCount = 3; // Default to 3 columns for mobile

          // Adjust columns based on player count for better layout
          if (widget.players.length <= 4) {
            crossAxisCount = 2;
          } else if (widget.players.length <= 9) {
            crossAxisCount = 3;
          } else {
            crossAxisCount = 4;
          }
          childAspectRatio =
              0.75; // Reduced to make room for larger text and buttons
          spacing = 8;
        } else {
          // Web layout - more columns with smaller avatars
          if (widget.players.length <= 4) {
            crossAxisCount = 6;
          } else if (widget.players.length <= 9) {
            crossAxisCount = 6;
          } else if (widget.players.length <= 16) {
            crossAxisCount = 8;
          } else {
            crossAxisCount = 10;
          }

          childAspectRatio =
              0.75; // Reduced to make room for larger text and buttons
          spacing = 12;
        }

        final isCurrentPlayerAlive = widget.players.any((p) => p.id == widget.currentUserId)
    ? widget.players.firstWhere((p) => p.id == widget.currentUserId).isAlive
    : false;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: widget.players.length,
          itemBuilder: (context, index) {
            final player = widget.players[index];

            // Can't vote for yourself or dead players
            final canVote = player.id != widget.currentUserId && player.isAlive;
            final isSelected = _selectedPlayerId == player.id;
            final isCurrentUser = player.id == widget.currentUserId;

            return Container(
              decoration:
                  isCurrentUser
                      ? BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 3),
                      )
                      : isSelected
                      ? BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange, width: 3),
                      )
                      : null,
              child: Column(
                children: [
                  // Player Avatar - Fixed size instead of Expanded
                  SizedBox(
                    height: 60, // Fixed height for avatar
                    child: PlayerAvatar(
                      name: player.name,
                      isLeader: player.isLeader,
                      isDead: !player.isAlive,
                      profilePicture: player.profilePicture,
                      playerRole: player.role,
                      currentUserRole: widget.myRole,
                    ),
                  ),
                  const SizedBox(height: 4), // Space between avatar and name
                  // Player name - Larger font
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      player.name,
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 12, // Increased from 8 to 12
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
                  const SizedBox(
                    height: 4,
                  ), // Space between name and button                  // Vote Button - Compact size
                  if (isCurrentPlayerAlive && canVote)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: SizedBox(
                        width: 50, // Fixed width instead of full width
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () => _toggleVote(player.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isSelected
                                    ? Colors.orange
                                    : const Color(0xFF8B4513),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            minimumSize: const Size(0, 28),
                          ),
                          child: Text(
                            isSelected ? 'REMOVE' : 'VOTE',
                            style: const TextStyle(
                              fontFamily: 'Rye',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    // Placeholder for dead players or current user
                    const SizedBox(height: 28),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
