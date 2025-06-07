import 'dart:convert';
import 'package:http/http.dart' as http;

class MessageConfigService {
  static const String _baseUrl =
      'https://us-central1-noonday-game.cloudfunctions.net';
  static Map<String, dynamic>? _cachedConfig;

  /// Fetches the message configuration from the backend
  static Future<Map<String, dynamic>> getMessageConfig() async {
    // Return cached config if available
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/getMessageConfig'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final config = json.decode(response.body) as Map<String, dynamic>;
        _cachedConfig = config; // Cache the configuration
        return config;
      } else {
        throw Exception(
          'Failed to fetch message config: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching message config: $e');
    }
  }

  /// Gets a specific popup title from the configuration
  static Future<String> getPopupTitle(String titleKey) async {
    try {
      final config = await getMessageConfig();
      final popupTitles = config['POPUP_TITLES'] as Map<String, dynamic>?;

      if (popupTitles != null && popupTitles.containsKey(titleKey)) {
        return popupTitles[titleKey] as String;
      }

      // Return default titles if config is not available
      return _getDefaultTitle(titleKey);
    } catch (e) {
      // Return default titles if there's an error
      return _getDefaultTitle(titleKey);
    }
  }

  /// Clears the cached configuration (useful for testing or refreshing)
  static void clearCache() {
    _cachedConfig = null;
  }

  /// Default titles as fallback
  static String _getDefaultTitle(String titleKey) {
    switch (titleKey) {
      case 'QUIET_NIGHT':
        return 'zZzZz';
      case 'DEATH_EVENT':
        return 'Rest in Peace';
      case 'NIGHT_OUTCOME':
        return 'Night Outcome';
      case 'ROLE_REVEAL':
        return 'Your Role';
      case 'VOTE_RESULT':
        return 'Vote Result';
      case 'GAME_OVER':
        return 'Game Over';
      default:
        return 'Game Event';
    }
  }
}
