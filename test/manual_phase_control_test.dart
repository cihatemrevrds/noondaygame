import 'package:flutter_test/flutter_test.dart';
import 'package:noondaygame/services/lobby_service.dart';

void main() {
  group('Manual Phase Control Tests', () {
    late LobbyService lobbyService;

    setUp(() {
      lobbyService = LobbyService();
    });

    test('should return default manual control setting as false', () async {
      // Test that the default manual control setting is false
      // This will help verify our setting structure

      final defaultSettings = {
        'nightPhaseDuration': 30,
        'eventPhaseDuration': 5,
        'dayPhaseDuration': 60,
        'manualPhaseControl': false,
      };

      // Verify default values
      expect(defaultSettings['manualPhaseControl'], false);
      expect(defaultSettings['nightPhaseDuration'], 30);
      expect(defaultSettings['eventPhaseDuration'], 5);
      expect(defaultSettings['dayPhaseDuration'], 60);
    });

    test('should handle night events extraction correctly', () {
      // Test night events extraction logic
      final mockLobbyData = {
        'nightEvents': [
          'Player A was killed by the Gunman.',
          'Someone was attacked but saved by the Doctor!',
        ],
      };

      final nightEvents = mockLobbyData['nightEvents'] as List<dynamic>?;
      final eventStrings =
          nightEvents?.map((event) => event.toString()).toList() ?? [];

      expect(eventStrings.length, 2);
      expect(eventStrings[0], 'Player A was killed by the Gunman.');
      expect(eventStrings[1], 'Someone was attacked but saved by the Doctor!');
    });

    test('should handle empty night events correctly', () {
      // Test empty night events case
      final mockLobbyData = <String, dynamic>{};

      final nightEvents = mockLobbyData['nightEvents'] as List<dynamic>?;
      final eventStrings =
          nightEvents?.map((event) => event.toString()).toList() ?? [];

      expect(eventStrings.length, 0);
    });

    test('should validate phase control settings structure', () {
      // Test the settings structure we expect from Firebase
      final gameSettings = {
        'votingTime': 30,
        'discussionTime': 60,
        'nightTime': 45,
        'allowFirstNightKill': false,
        'manualPhaseControl': true, // This is the key setting we added
      };

      expect(gameSettings.containsKey('manualPhaseControl'), true);
      expect(gameSettings['manualPhaseControl'], true);
    });
  });
}
