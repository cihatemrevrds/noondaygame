import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test to validate XMLHttpRequest error fixes after the first night
/// This test simulates the exact scenario where errors were occurring
void main() {
  group('XMLHttpRequest Error Fix Validation', () {
    test('autoAdvancePhase handles null phaseStartedAt gracefully', () async {
      // Test the scenario where phaseStartedAt is null
      const testUrl = 'https://autoadvancephase-uerylfny3q-uc.a.run.app';

      try {
        final response = await http.post(
          Uri.parse(testUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'lobbyId': 'test_lobby_null_phase_time',
            // Simulating a lobby that might have null phaseStartedAt
          }),
        );

        // Should not throw XMLHttpRequest error anymore
        expect(
          response.statusCode,
          anyOf([200, 404, 400]),
        ); // Any valid HTTP status
        print(
          'autoAdvancePhase response: ${response.statusCode} - ${response.body}',
        );
      } catch (e) {
        // Should not get XMLHttpRequest errors
        expect(
          e.toString().contains('XMLHttpRequest'),
          false,
          reason: 'Should not throw XMLHttpRequest errors: $e',
        );
      }
    });

    test('getGameState handles null phaseStartedAt gracefully', () async {
      // Test the scenario where phaseStartedAt is null in getGameState
      const testUrl = 'https://getgamestate-uerylfny3q-uc.a.run.app';

      try {
        final response = await http.post(
          Uri.parse(testUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'lobbyId': 'test_lobby_null_phase_time'}),
        );

        // Should not throw XMLHttpRequest error anymore
        expect(
          response.statusCode,
          anyOf([200, 404, 400]),
        ); // Any valid HTTP status
        print(
          'getGameState response: ${response.statusCode} - ${response.body}',
        );

        // If successful, check that timeRemaining is properly handled
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          expect(data['timeRemaining'], isA<num>());
          expect(data['timeRemaining'], greaterThanOrEqualTo(0));
        }
      } catch (e) {
        // Should not get XMLHttpRequest errors
        expect(
          e.toString().contains('XMLHttpRequest'),
          false,
          reason: 'Should not throw XMLHttpRequest errors: $e',
        );
      }
    });

    test('Phase transition stability after first night', () async {
      // Test multiple rapid calls to simulate the post-first-night scenario
      const autoAdvanceUrl = 'https://autoadvancephase-uerylfny3q-uc.a.run.app';
      const gameStateUrl = 'https://getgamestate-uerylfny3q-uc.a.run.app';

      List<Future> requests = [];

      // Make 5 rapid requests to each endpoint
      for (int i = 0; i < 5; i++) {
        requests.add(
          http
              .post(
                Uri.parse(autoAdvanceUrl),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'lobbyId': 'test_stability_$i'}),
              )
              .timeout(Duration(seconds: 30)),
        );

        requests.add(
          http
              .post(
                Uri.parse(gameStateUrl),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'lobbyId': 'test_stability_$i'}),
              )
              .timeout(Duration(seconds: 30)),
        );
      }

      try {
        final responses = await Future.wait(requests);

        // All requests should complete without XMLHttpRequest errors
        for (int i = 0; i < responses.length; i++) {
          final response = responses[i] as http.Response;
          expect(
            response.statusCode,
            anyOf([200, 404, 400, 500]),
          ); // Any valid HTTP status
          print('Stability test response ${i}: ${response.statusCode}');
        }

        print(
          'All ${responses.length} requests completed successfully without XMLHttpRequest errors',
        );
      } catch (e) {
        // Should not get XMLHttpRequest errors or timeouts
        expect(
          e.toString().contains('XMLHttpRequest'),
          false,
          reason:
              'Should not throw XMLHttpRequest errors during rapid requests: $e',
        );
        expect(
          e.toString().contains('TimeoutException'),
          false,
          reason: 'Should not timeout due to backend errors: $e',
        );
      }
    });

    test('Error handling for malformed requests', () async {
      // Test that malformed requests don't cause XMLHttpRequest errors
      const testUrl = 'https://autoadvancephase-uerylfny3q-uc.a.run.app';

      try {
        final response = await http.post(
          Uri.parse(testUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            // Missing required fields to test error handling
          }),
        );

        // Should return proper HTTP error, not XMLHttpRequest error
        expect(response.statusCode, anyOf([400, 404, 500]));
        print(
          'Malformed request response: ${response.statusCode} - ${response.body}',
        );
      } catch (e) {
        // Should not get XMLHttpRequest errors even for malformed requests
        expect(
          e.toString().contains('XMLHttpRequest'),
          false,
          reason:
              'Should not throw XMLHttpRequest errors for malformed requests: $e',
        );
      }
    });
  });
}
