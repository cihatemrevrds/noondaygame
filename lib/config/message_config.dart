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
      message: 'You shot {targetName}. You can rest now.',
    ),
    'gunslinger_no_bullets': PopupContent(
      title: '🔫 Empty Chamber',
      message: 'You have no bullets remaining.',
    ),
    'gunslinger_lost_bullet': PopupContent(
      title: '💔 Second Bullet Lost',
      message: 'You lost your second bullet for killing a town member.',
    ), // Death Notification Messages (for victims)
    'player_death': PopupContent(
      title: '💀 Your Final Moment',
      message: 'You were killed by {killerTeam}! Your role was {victimRole}.',
    ),

    // First Night Kill Disabled Messages
    'first_night_kill_disabled': PopupContent(
      title: '🛡️ First Night Protection',
      message:
          'Kill actions are disabled on the first night. No one can be harmed tonight.',
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
  // 🏆 Win/Lose Condition Messages
  static const Map<String, WinLoseContent> winLoseMessages = {
    // Town Victory Messages
    'town_victory': WinLoseContent(
      victoryTitle: 'VICTORY!',
      defeatTitle: 'DEFEAT',
      victoryMessage:
          'The Town has triumphed!\nAll bandits have been eliminated.',
      defeatMessage:
          'The Town has triumphed!\nAll bandits have been eliminated.',
      icon: '🏛️',
    ),

    // Bandit Victory Messages
    'bandit_victory_majority': WinLoseContent(
      victoryTitle: 'VICTORY!',
      defeatTitle: 'DEFEAT',
      victoryMessage:
          'The Bandits have taken over!\nThe town has fallen to the outlaws.',
      defeatMessage:
          'The Bandits have taken over!\nThe town has fallen to the outlaws.',
      icon: '🔫',
    ),

    'bandit_victory_no_gunslinger': WinLoseContent(
      victoryTitle: 'VICTORY!',
      defeatTitle: 'DEFEAT',
      victoryMessage:
          'The Bandits have taken over!\nWith no Gunslinger to challenge them, the outlaws seize control.',
      defeatMessage:
          'The Bandits have taken over!\nWith no Gunslinger to challenge them, the outlaws seize control.',
      icon: '🔫',
    ),

    // Jester Victory Messages
    'jester_victory_vote_out': WinLoseContent(
      victoryTitle: 'VICTORY!',
      defeatTitle: 'DEFEAT',
      victoryMessage:
          'The Jester wins!\nChaos reigns as the fool gets the last laugh.',
      defeatMessage:
          'The Jester wins!\nChaos reigns as the fool gets the last laugh.',
      icon: '🃏',
    ),

    'jester_victory_last_standing': WinLoseContent(
      victoryTitle: 'VICTORY!',
      defeatTitle: 'DEFEAT',
      victoryMessage:
          'The Jester has won!\nVictory through survival and cunning.',
      defeatMessage:
          'The Jester has won!\nVictory through survival and cunning.',
      icon: '🃏',
    ),

    // Draw/Tie Messages
    'draw_all_eliminated': WinLoseContent(
      victoryTitle: 'DRAW',
      defeatTitle: 'DRAW',
      victoryMessage:
          'It\'s a Draw!\nAll players have been eliminated. No one wins.',
      defeatMessage:
          'It\'s a Draw!\nAll players have been eliminated. No one wins.',
      icon: '⚖️',
    ),

    // Generic Neutral Victory (for any neutral role winning by last standing)
    'neutral_victory_last_standing': WinLoseContent(
      victoryTitle: 'VICTORY!',
      defeatTitle: 'DEFEAT',
      victoryMessage:
          '{winner} has won!\nVictory through survival and cunning.',
      defeatMessage: '{winner} has won!\nVictory through survival and cunning.',
      icon: '🏆',
    ),

    // Fallback messages
    'game_ended_unexpectedly': WinLoseContent(
      victoryTitle: 'GAME OVER',
      defeatTitle: 'GAME OVER',
      victoryMessage: 'Game ended unexpectedly.',
      defeatMessage: 'Game ended unexpectedly.',
      icon: '🏁',
    ),
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

  // Helper method to get win/lose content
  static WinLoseContent? getWinLoseContent(String winner, String winType) {
    switch (winner) {
      case 'Town':
        return winLoseMessages['town_victory'];
      case 'Bandit':
        if (winType == 'no_gunslinger_parity') {
          return winLoseMessages['bandit_victory_no_gunslinger'];
        } else {
          return winLoseMessages['bandit_victory_majority'];
        }
      case 'Jester':
        if (winType == 'jester_vote_out') {
          return winLoseMessages['jester_victory_vote_out'];
        } else {
          return winLoseMessages['jester_victory_last_standing'];
        }
      case 'Draw':
        return winLoseMessages['draw_all_eliminated'];
      default:
        // For neutral role wins by last standing
        if (winType == 'last_standing') {
          return winLoseMessages['neutral_victory_last_standing'];
        }
        return winLoseMessages['game_ended_unexpectedly'];
    }
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

// Data class for win/lose content
class WinLoseContent {
  final String victoryTitle;
  final String defeatTitle;
  final String victoryMessage;
  final String defeatMessage;
  final String icon;

  const WinLoseContent({
    required this.victoryTitle,
    required this.defeatTitle,
    required this.victoryMessage,
    required this.defeatMessage,
    required this.icon,
  });
}
