import 'package:flutter_test/flutter_test.dart';
import 'package:noondaygame/services/lobby_service.dart';

void main() {
  group('Lobby Cleanup Unit Tests', () {
    tearDown(() {
      // Always clean up after tests
      LobbyService.stopPeriodicCleanup();
    });

    test('Periodic cleanup timer can be started and stopped', () {
      // Initially no timer should be running
      expect(LobbyService.cleanupTimer, isNull);

      // Start periodic cleanup
      LobbyService.startPeriodicCleanup();
      expect(LobbyService.cleanupTimer, isNotNull);

      // Stop periodic cleanup
      LobbyService.stopPeriodicCleanup();
      expect(LobbyService.cleanupTimer, isNull);
    });

    test('Static cleanup timer is properly managed', () {
      // Ensure timer starts as null
      LobbyService.stopPeriodicCleanup();
      expect(LobbyService.cleanupTimer, isNull);

      // Start timer
      LobbyService.startPeriodicCleanup();
      final timer1 = LobbyService.cleanupTimer;
      expect(timer1, isNotNull);

      // Starting again should replace the timer
      LobbyService.startPeriodicCleanup();
      final timer2 = LobbyService.cleanupTimer;
      expect(timer2, isNotNull);
      expect(timer2, isNot(equals(timer1))); // Should be a new timer

      // Clean up
      LobbyService.stopPeriodicCleanup();
      expect(LobbyService.cleanupTimer, isNull);
    });

    test('Multiple start/stop cycles work correctly', () {
      // Multiple cycles should work without issues
      for (int i = 0; i < 3; i++) {
        expect(LobbyService.cleanupTimer, isNull);

        LobbyService.startPeriodicCleanup();
        expect(LobbyService.cleanupTimer, isNotNull);

        LobbyService.stopPeriodicCleanup();
        expect(LobbyService.cleanupTimer, isNull);
      }
    });

    test('Timer is correctly cancelled when replaced', () {
      LobbyService.startPeriodicCleanup();
      final timer1 = LobbyService.cleanupTimer;
      expect(timer1, isNotNull);
      expect(timer1!.isActive, isTrue);

      // Start again - should cancel the previous timer
      LobbyService.startPeriodicCleanup();
      expect(timer1.isActive, isFalse); // Previous timer should be cancelled

      final timer2 = LobbyService.cleanupTimer;
      expect(timer2, isNotNull);
      expect(timer2!.isActive, isTrue);
      expect(timer2, isNot(equals(timer1)));

      LobbyService.stopPeriodicCleanup();
    });
  });
}
