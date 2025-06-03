import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/player.dart';
import '../widgets/player_avatar.dart';

class PlayerGridWidget extends StatelessWidget {
  final List<Player> players;
  final String? votedPlayerId;
  final Map<String, String> votes;
  final bool isVotingPhase;
  final String currentUserId;
  final Function(String) onPlayerTap;

  const PlayerGridWidget({
    super.key,
    required this.players,
    required this.votedPlayerId,
    required this.votes,
    required this.isVotingPhase,
    required this.currentUserId,
    required this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive grid layout
        final screenWidth = constraints.maxWidth;
        // Determine optimal grid layout based on number of players and screen size
        int crossAxisCount;
        double aspectRatio;

        // Always show at least 4 columns for testing and UI layout consistency
        if (players.length <= 4) {
          crossAxisCount = 4; // Changed from 2 to 4 for minimum layout
        } else if (players.length <= 9) {
          crossAxisCount = 4; // Keep 4 columns for better visual spacing
        } else if (players.length <= 16) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 5;
        }

        // Adjust for very wide screens
        if (screenWidth > 1200 && players.length > 6) {
          crossAxisCount = math.min(crossAxisCount + 1, 6);
        }

        // Calculate square aspect ratio with padding for text
        aspectRatio = 1.0; // Square frames

        // Calculate spacing based on screen size
        final spacing = math.max(8.0, screenWidth * 0.01);
        final padding = math.max(12.0, screenWidth * 0.02);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            final isVoted = votedPlayerId == player.id;
            final voteCount =
                votes.values.where((id) => id == player.id).length;

            return GestureDetector(
              onTap:
                  isVotingPhase && player.isAlive && player.id != currentUserId
                      ? () => onPlayerTap(player.id)
                      : null,
              child: Container(
                decoration: BoxDecoration(
                  border:
                      isVoted
                          ? Border.all(color: Colors.green, width: 3)
                          : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    PlayerAvatar(
                      name: player.name,
                      isLeader: player.isLeader,
                      isDead: !player.isAlive,
                    ),
                    if (voteCount > 0 && isVotingPhase)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$voteCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
