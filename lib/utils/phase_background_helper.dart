import 'package:flutter/material.dart';

/// Helper utility for determining which sky background to use for different phases
class PhaseBackgroundHelper {
  /// Determines which sky background asset to use based on the current game state
  /// Returns the asset path for the appropriate sky background
  static String getSkyBackground(String gameState) {
    switch (gameState) {
      // Sky day phases
      case 'event_sharing':
      case 'discussion_phase':
      case 'voting_phase':
      case 'voting_outcome':
        return 'assets/images/backgrounds/sky_day.jpg';

      // Sky night phases
      case 'role_reveal':
      case 'night_phase':
      case 'night_outcome':
        return 'assets/images/backgrounds/sky_night.jpg';

      // Default fallback to day sky
      default:
        return 'assets/images/backgrounds/sky_day.jpg';
    }
  }

  /// Checks if the current phase should use a sky background
  static bool shouldUseSkyBackground(String gameState) {
    // All game phases should use sky backgrounds
    return [
      'role_reveal',
      'night_phase',
      'night_outcome',
      'event_sharing',
      'discussion_phase',
      'voting_phase',
      'voting_outcome',
    ].contains(gameState);
  }

  /// Gets the appropriate text color for the sky background
  static Color getTextColor(String gameState) {
    // Night phases use lighter text for better contrast
    switch (gameState) {
      case 'role_reveal':
      case 'night_phase':
      case 'night_outcome':
        return const Color(0xFFFFFFFF); // Pure white for night

      case 'event_sharing':
      case 'discussion_phase':
      case 'voting_phase':
      case 'voting_outcome':
        return const Color(0xFFFFFFFF); // White for day as well for consistency

      default:
        return const Color(0xFFFFFFFF);
    }
  }
}
