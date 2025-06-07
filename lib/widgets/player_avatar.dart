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
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make it fully responsive to container size
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final avatarSize = size * 0.5; // Avatar takes 50% of container
        final fontSize = avatarSize * 0.35; // Font size relative to avatar
        final nameFontSize =
            size * 0.08; // Name font size relative to container

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF4E2C0B),
            borderRadius: BorderRadius.circular(size * 0.08),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [                  Container(
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
                    child: ClipOval(
                      child: profilePicture != null 
                        ? Image.asset(
                            'assets/images/profilePictures/$profilePicture',
                            fit: BoxFit.cover,
                            width: avatarSize,
                            height: avatarSize,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackAvatar(avatarSize, fontSize);
                            },
                          )
                        : _buildFallbackAvatar(avatarSize, fontSize),
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
              SizedBox(height: size * 0.05),
              Padding(
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
              if (isLeader) ...[
                SizedBox(height: size * 0.02),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size * 0.06,
                    vertical: size * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow[700],
                    borderRadius: BorderRadius.circular(size * 0.04),
                  ),
                  child: Text(
                    'HOST',
                    style: TextStyle(
                      fontSize: size * 0.06,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),        );
      },
    );
  }

  // Helper method to build fallback avatar with initials
  Widget _buildFallbackAvatar(double avatarSize, double fontSize) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'P',
        style: TextStyle(
          color: isDead ? Colors.white70 : Colors.brown[800],
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          decoration: isDead ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
