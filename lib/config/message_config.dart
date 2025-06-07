// Message Configuration for Noonday Game
// This file contains all popup messages and titles that can be customized
// Edit the messages below to customize the game text

class MessageConfig {
  // 🔒 Private Event Messages (keyword -> popup content)
  // These correspond to the EVENT_TYPES in the Firebase messageConfig.js
  static const Map<String, PopupContent> privateEventMessages = {
    // Doctor Messages
    'protection_result': PopupContent(
      title: '🛡️ Protection Applied',
      message: 'You protected {targetName} tonight.',
    ),
    'protection_blocked': PopupContent(
      title: '🚫 Action Blocked',
      message: 'You were blocked and could not protect anyone.',
    ),
    'protection_successful': PopupContent(
      title: '✨ Life Saved!',
      message: 'You successfully saved {targetName} from an attack!',
    ),

    // Sheriff Messages
    'investigation_result': PopupContent(
      title: '🔍 Investigation Complete',
      message: 'You investigated {targetName}. They appear {result}.',
    ),
    'investigation_blocked': PopupContent(
      title: '🚫 Action Blocked',
      message: 'You were blocked and could not investigate anyone.',
    ),

    // Escort Messages
    'block_result': PopupContent(
      title: '🚧 Target Blocked',
      message: 'You blocked {targetName} from performing their night action.',
    ),

    // Peeper Messages
    'peep_result': PopupContent(
      title: '👁️ Surveillance Report',
      message: 'You spied on {targetName}. {visitorsText}',
    ),
    'peep_blocked': PopupContent(
      title: '🚫 Action Blocked',
      message: 'You were blocked and could not spy on anyone.',
    ),

    // Gunman Messages
    'kill_success': PopupContent(
      title: '🔫 Mission Accomplished',
      message: 'You successfully killed {targetName}.',
    ),
    'kill_failed': PopupContent(
      title: '🛡️ Mission Failed',
      message: 'You tried to kill {targetName}, but they were protected.',
    ),
    'kill_blocked': PopupContent(
      title: '🚫 Action Blocked',
      message: 'You were blocked and could not kill anyone.',
    ),
    'not_selected': PopupContent(
      title: '⏸️ Standing By',
      message: 'The Chieftain gave orders to another Gunman tonight.',
    ), // Chieftain Messages
    'order_success': PopupContent(
      title: '👑 Order Executed',
      message: 'Your order was carried out. {targetName} was killed.',
    ),
    'order_failed': PopupContent(
      title: '🛡️ Order Failed',
      message: 'Your order failed. {targetName} was protected.',
    ), // Gunslinger Messages
    'gunslinger_target_selected': PopupContent(
      title: '🎯 Target Selected',
      message:
          'You selected {targetName} as your target. You will learn the outcome at the end of the night.',
    ),
    'gunslinger_shot_town': PopupContent(
      title: '💔 Friendly Fire',
      message:
          'You shot {targetName}. They were a town member. You lost your second bullet.',
    ),
    'gunslinger_shot_success': PopupContent(
      title: '🎯 Shot Fired',
      message:
          'You shot {targetName}. You have {bulletsRemaining} bullet{bulletPlural} remaining.',
    ),
    'gunslinger_no_bullets': PopupContent(
      title: '🔫 Empty Chamber',
      message: 'You have no bullets remaining.',
    ),
    'gunslinger_lost_bullet': PopupContent(
      title: '💔 Second Bullet Lost',
      message: 'You lost your second bullet for killing a town member.',
    ),
  };

  // 🌍 Public Event Messages (keyword -> popup content)
  static const Map<String, PopupContent> publicEventMessages = {
    'player_killed': PopupContent(
      title: '💀 Rest in Peace',
      message: '{playerName} was killed by Bandits.',
    ),
    'quiet_night': PopupContent(
      title: '🌙 zZzZz',
      message: 'The night was quiet. No one was harmed.',
    ),
  };

  // 🎮 Other Popup Titles
  static const Map<String, String> popupTitles = {
    'role_reveal': '🎭 Your Role',
    'vote_result': '⚖️ Vote Result',
    'game_over': '🏁 Game Over',
    'night_outcome': '🌙 Night Outcome',
  };

  // Helper method to get popup content for private events
  static PopupContent? getPrivateEventContent(String keyword) {
    return privateEventMessages[keyword];
  }

  // Helper method to get popup content for public events
  static PopupContent? getPublicEventContent(String keyword) {
    return publicEventMessages[keyword];
  }

  // Helper method to get popup title
  static String getPopupTitle(String keyword) {
    return popupTitles[keyword] ?? 'Game Event';
  }

  // Helper method to format message with variables
  static String formatMessage(String template, Map<String, String> variables) {
    String result = template;
    variables.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  // Helper method to determine event type for public events
  static String getPublicEventType(List<String> events) {
    if (events.isEmpty) return 'quiet_night';

    // Check if any event contains death/killing
    for (String event in events) {
      if (event.toLowerCase().contains('killed') ||
          event.toLowerCase().contains('died') ||
          event.toLowerCase().contains('eliminated')) {
        return 'player_killed';
      }
    }

    return 'quiet_night';
  }
}

// Data class for popup content
class PopupContent {
  final String title;
  final String message;

  const PopupContent({required this.title, required this.message});
}
