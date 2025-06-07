import 'package:flutter/material.dart';
import 'dart:math';

class BulletTimerWidget extends StatelessWidget {
  final int remainingTime;
  final int totalTime;
  final double size;
  final Color activeBulletColor;
  final Color inactiveBulletColor;

  const BulletTimerWidget({
    super.key,
    required this.remainingTime,
    required this.totalTime,
    this.size = 120.0,
    this.activeBulletColor = Colors.white,
    this.inactiveBulletColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: BulletTimerPainter(
          remainingTime: remainingTime,
          totalTime: totalTime,
          activeBulletColor: activeBulletColor,
          inactiveBulletColor: inactiveBulletColor,
        ),
        child: Center(
          child: Text(
            _formatTime(remainingTime),
            style: TextStyle(
              fontFamily: 'Rye',
              fontSize: size * 0.16, // Responsive font size
              fontWeight: FontWeight.bold,
              color: remainingTime <= 30 ? Colors.red : Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class BulletTimerPainter extends CustomPainter {
  final int remainingTime;
  final int totalTime;
  final Color activeBulletColor;
  final Color inactiveBulletColor;

  BulletTimerPainter({
    required this.remainingTime,
    required this.totalTime,
    required this.activeBulletColor,
    required this.inactiveBulletColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4; // Radius for bullet circle
    final bulletWidth = size.width * 0.04; // Width of each bullet
    final bulletHeight =
        size.width * 0.12; // Height of each bullet (more elongated)

    // Fixed number of bullets (30 bullets for visual appeal)
    const bulletCount = 30;

    // Calculate which bullets should be active based on remaining time
    // Each bullet represents (totalTime / bulletCount) seconds
    final timePerBullet = totalTime / bulletCount;
    final activeBullets =
        totalTime > 0 ? (remainingTime / timePerBullet).ceil() : 0;

    // Paint bullets around the circle
    for (int i = 0; i < bulletCount; i++) {
      // Calculate angle for this bullet (starting from top 12 o'clock, going clockwise)
      final angle = (i * 2 * pi / bulletCount) - (pi / 2); // Start from top

      // Calculate bullet position
      final bulletX = center.dx + radius * cos(angle);
      final bulletY = center.dy + radius * sin(angle);
      final bulletCenter = Offset(bulletX, bulletY);

      // Determine if this bullet should be active based on remaining time
      // Bullets disappear from the end (index 0 = first bullet, stays active longest)
      final isActive = i < activeBullets;
      final bulletColor = isActive ? activeBulletColor : inactiveBulletColor;

      // Create bullet shape (rounded rectangle oriented towards center)
      final bulletRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: bulletCenter,
          width: bulletWidth,
          height: bulletHeight,
        ),
        Radius.circular(bulletWidth / 2),
      );

      // Rotate bullet to point towards center
      canvas.save();
      canvas.translate(bulletCenter.dx, bulletCenter.dy);
      canvas.rotate(angle + pi / 2); // Rotate to point inward
      canvas.translate(-bulletCenter.dx, -bulletCenter.dy);

      // Create paint for the bullet
      final paint =
          Paint()
            ..color = bulletColor
            ..style = PaintingStyle.fill;

      // Add shadow for active bullets
      if (isActive) {
        final shadowPaint =
            Paint()
              ..color = Colors.black.withOpacity(0.4)
              ..style = PaintingStyle.fill;
        final shadowRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: bulletCenter + const Offset(1, 1),
            width: bulletWidth + 1,
            height: bulletHeight + 1,
          ),
          Radius.circular(bulletWidth / 2),
        );
        canvas.drawRRect(shadowRect, shadowPaint);
      }

      // Draw the bullet
      canvas.drawRRect(bulletRect, paint);

      // Add metallic highlight for active bullets
      if (isActive) {
        final highlightPaint =
            Paint()
              ..color = bulletColor.withOpacity(0.6)
              ..style = PaintingStyle.fill;
        final highlightRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: bulletCenter - Offset(bulletWidth * 0.2, 0),
            width: bulletWidth * 0.3,
            height: bulletHeight * 0.7,
          ),
          Radius.circular(bulletWidth / 4),
        );
        canvas.drawRRect(highlightRect, highlightPaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is BulletTimerPainter) {
      return oldDelegate.remainingTime != remainingTime ||
          oldDelegate.totalTime != totalTime ||
          oldDelegate.activeBulletColor != activeBulletColor ||
          oldDelegate.inactiveBulletColor != inactiveBulletColor;
    }
    return true;
  }
}
