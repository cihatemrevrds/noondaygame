import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlayerAvatar extends StatelessWidget {
  final String name;
  final bool isLeader;
  final bool isDead;
  final String? profilePicture;
  const PlayerAvatar({
    super.key,
    required this.name,
    this.isLeader = false,
    this.isDead = false,
    this.profilePicture,
  });  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make it fully responsive to container size
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final fontSize = size * 0.4; // Font size for fallback initials

        return Stack(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDead ? Colors.black54 : Colors.white,
                border: Border.all(
                  color: isLeader ? Colors.yellow[700]! : Colors.brown[700]!,
                  width: isLeader ? 3 : 2,
                ),
              ),
              child: ClipOval(
                child: profilePicture != null 
                  ? Image.asset(
                      'assets/images/profilePictures/$profilePicture',
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFallbackAvatar(size, fontSize);
                      },
                    )
                  : _buildFallbackAvatar(size, fontSize),
              ),
            ),
            if (isLeader)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.yellow[700],
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.white,
                    size: size * 0.2,
                  ),
                ),
              ),
            if (isDead)
              Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.close,
                    color: Colors.red[700],
                    size: size * 0.6,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  // Helper method to build fallback avatar with initials
  Widget _buildFallbackAvatar(double size, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDead ? Colors.black54 : Colors.white,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'P',
          style: TextStyle(
            color: isDead ? Colors.white70 : Colors.brown[800],
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            decoration: isDead ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
