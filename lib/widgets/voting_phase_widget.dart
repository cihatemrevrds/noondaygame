import 'package:flutter/material.dart';
import '../models/player.dart';
import '../widgets/player_avatar.dart';

class VotingPhaseWidget extends StatefulWidget {
  final List<Player> players;
  final int remainingTime; // in seconds
  final String currentUserId;
  final String? myRole;
  final Function(String?)? onVoteChanged; // Callback when vote changes

  const VotingPhaseWidget({
    super.key,
    required this.players,
    required this.remainingTime,
    required this.currentUserId,
    this.myRole,
    this.onVoteChanged,
  });

  @override
  State<VotingPhaseWidget> createState() => _VotingPhaseWidgetState();
}

class _VotingPhaseWidgetState extends State<VotingPhaseWidget>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;
  String? _selectedPlayerId; // The player ID we're voting for

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
                                      ? Colors.orange
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
    // Ensure we have exactly 20 slots (4 columns x 5 rows)
    final gridPlayers = List<Player?>.filled(20, null);

    // Fill with actual players
    for (int i = 0; i < widget.players.length && i < 20; i++) {
      gridPlayers[i] = widget.players[i];
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9, // Slightly adjusted for smaller buttons
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

        // Can't vote for yourself or dead players
        final canVote = player.id != widget.currentUserId && player.isAlive;
        final isCurrentUser = player.id == widget.currentUserId;
        final isSelected = _selectedPlayerId == player.id;

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
              // Player Avatar
              Expanded(                child: PlayerAvatar(
                  name: player.name,
                  isLeader: player.isLeader,
                  isDead: !player.isAlive,
                  profilePicture: player.profilePicture,
                ),
              ), // Vote Button
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
          ),
        );
      },
    );
  }
}
