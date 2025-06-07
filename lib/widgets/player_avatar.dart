import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlayerAvatar extends StatelessWidget {
  final String name;
  final bool isLeader;
  final bool isDead;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.isLeader = false,
    this.isDead = false,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make it fully responsive to container size
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final avatarSize = size * 0.55; // Reduced avatar size to fit content
        final fontSize = avatarSize * 0.35; // Font size relative to avatar
        final nameFontSize = size * 0.1; // Smaller name font size

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Use minimum space
          children: [
            Stack(
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDead ? Colors.black54 : Colors.white,
                    border: Border.all(
                      color:
                          isLeader ? Colors.yellow[700]! : Colors.brown[700]!,
                      width: isLeader ? 3 : 2,
                    ),
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
                ),
                if (isLeader)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: avatarSize * 0.3,
                      height: avatarSize * 0.3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.yellow[700],
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Icon(
                        Icons.star,
                        color: Colors.white,
                        size: avatarSize * 0.2,
                      ),
                    ),
                  ),
                if (isDead)
                  Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.close,
                        color: Colors.red[700],
                        size: avatarSize * 0.6,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: size * 0.03), // Reduced spacing
            Flexible(
              // Use Flexible to prevent overflow
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.05),
                child: Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Rye',
                    fontSize: nameFontSize,
                    color: isDead ? Colors.grey : Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: isDead ? TextDecoration.lineThrough : null,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            if (isLeader) ...[
              SizedBox(height: size * 0.01), // Reduced spacing
              Flexible(
                // Use Flexible to prevent overflow
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size * 0.06,
                    vertical: size * 0.005, // Reduced padding
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow[700],
                    borderRadius: BorderRadius.circular(
                      size * 0.03,
                    ), // Smaller radius
                  ),
                  child: Text(
                    'HOST',
                    style: TextStyle(
                      fontSize: size * 0.05, // Smaller font
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
