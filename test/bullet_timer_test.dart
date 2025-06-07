// Test the bullet timer calculation logic

void main() {
  print('=== Bullet Timer Calculation Test ===\n');

  // Test case 1: 15 seconds with 30 bullets
  testBulletCalculation(totalTime: 15, bulletCount: 30);

  // Test case 2: 45 seconds with 30 bullets
  testBulletCalculation(totalTime: 45, bulletCount: 30);

  // Test case 3: 120 seconds with 30 bullets
  testBulletCalculation(totalTime: 120, bulletCount: 30);
}

void testBulletCalculation({required int totalTime, required int bulletCount}) {
  print('--- Test: ${totalTime}s total time with $bulletCount bullets ---');

  final timePerBullet = totalTime / bulletCount;
  print('Time per bullet: ${timePerBullet.toStringAsFixed(2)}s');

  // Test at different remaining times
  final testTimes = [totalTime, totalTime ~/ 2, totalTime ~/ 4, 5, 1, 0];

  for (final remainingTime in testTimes) {
    if (remainingTime <= totalTime) {
      final activeBullets =
          totalTime > 0 ? (remainingTime / timePerBullet).ceil() : 0;
      print(
        '  Remaining: ${remainingTime}s → Active bullets: $activeBullets/$bulletCount',
      );
    }
  }
  print('');
}
