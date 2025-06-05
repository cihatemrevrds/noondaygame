import 'package:http/http.dart' as http;
import 'dart:convert';

class EventsService {
  static const String baseUrl =
      'https://us-central1-noondaygame.cloudfunctions.net';

  /// Get both public and private events for a player
  static Future<Map<String, dynamic>?> getGameEvents(
    String lobbyCode,
    String playerId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getGameState?lobbyCode=$lobbyCode'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return {
          'nightEvents':
              data['nightEvents'] ?? [], // Public events for everyone
          'privateEvents':
              data['privateEvents']?[playerId], // Private events for this player only
          'gameState': data['gameState'],
          'phase': data['phase'],
          'timeRemaining': data['timeRemaining'],
        };
      }
    } catch (e) {
      print('Error getting game events: $e');
    }
    return null;
  }

  /// Check if player has private events to show during night outcome phase
  static bool hasPrivateEvents(
    Map<String, dynamic>? gameData,
    String playerId,
  ) {
    if (gameData == null) return false;

    final privateEvents = gameData['privateEvents'];
    return privateEvents != null && privateEvents.containsKey(playerId);
  }

  /// Check if there are public events to show during event sharing phase
  static bool hasPublicEvents(Map<String, dynamic>? gameData) {
    if (gameData == null) return false;

    final nightEvents = gameData['nightEvents'] as List?;
    return nightEvents != null && nightEvents.isNotEmpty;
  }

  /// Get the appropriate events based on current game phase
  static List<String> getEventsForPhase(
    Map<String, dynamic>? gameData,
    String playerId,
  ) {
    if (gameData == null) return [];

    final gameState = gameData['gameState'];

    switch (gameState) {
      case 'night_outcome':
        // Show private events (only what this player experienced)
        final privateEvent = gameData['privateEvents']?[playerId];
        if (privateEvent != null) {
          return [privateEvent['message'] ?? 'No specific events for you.'];
        }
        return ['You had a quiet night.'];

      case 'event_sharing':
        // Show public events (what everyone sees)
        final nightEvents = gameData['nightEvents'] as List?;
        return nightEvents?.cast<String>() ??
            ['The night was quiet. No one was harmed.'];

      default:
        return [];
    }
  }

  /// Get event type for styling purposes
  static String getEventType(Map<String, dynamic>? gameData, String playerId) {
    if (gameData == null) return 'neutral';

    final gameState = gameData['gameState'];

    if (gameState == 'night_outcome') {
      final privateEvent = gameData['privateEvents']?[playerId];
      if (privateEvent != null) {
        final type = privateEvent['type'];
        switch (type) {
          case 'kill_success':
          case 'investigation_result':
          case 'peep_result':
          case 'protection_result':
          case 'protection_successful':
          case 'block_result':
            return 'success';
          case 'kill_failed':
          case 'kill_blocked':
          case 'investigation_blocked':
          case 'protection_blocked':
          case 'peep_blocked':
            return 'blocked';
          default:
            return 'neutral';
        }
      }
    } else if (gameState == 'event_sharing') {
      final nightEvents = gameData['nightEvents'] as List?;
      if (nightEvents != null && nightEvents.isNotEmpty) {
        final firstEvent = nightEvents.first.toString().toLowerCase();
        if (firstEvent.contains('killed') || firstEvent.contains('died')) {
          return 'death';
        } else if (firstEvent.contains('saved') ||
            firstEvent.contains('protected')) {
          return 'save';
        } else if (firstEvent.contains('blocked')) {
          return 'blocked';
        }
      }
    }

    return 'neutral';
  }

  /// Format event message for display
  static String formatEventMessage(String message, String eventType) {
    switch (eventType) {
      case 'success':
        return '✅ $message';
      case 'blocked':
        return '🚫 $message';
      case 'death':
        return '💀 $message';
      case 'save':
        return '🛡️ $message';
      default:
        return '📢 $message';
    }
  }
}
