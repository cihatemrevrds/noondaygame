import '../models/player.dart';

// Team definitions for win condition checking
class WinConditionChecker {
  static const Map<String, List<String>> teams = {
    'Town': ['Doctor', 'Sheriff', 'Escort', 'Peeper', 'Gunslinger'],
    'Bandit': ['Gunman', 'Chieftain'],
    'Neutral': ['Jester'],
  };

  // Get team for a specific role
  static String? getTeamByRole(String role) {
    for (final entry in teams.entries) {
      if (entry.value.contains(role)) {
        return entry.key;
      }
    }
    return null;
  }
  // Check if role distribution would create immediate win condition
  static Map<String, dynamic> checkRoleDistribution(
    Map<String, int> roleDistribution,
    int playerCount,
  ) {
    // Create fake players list with the given role distribution
    final List<Player> mockPlayers = [];
    int playerId = 1;

    for (final entry in roleDistribution.entries) {
      final roleName = entry.key;
      final roleCount = entry.value;

      for (int i = 0; i < roleCount; i++) {
        mockPlayers.add(Player(
          id: playerId.toString(),
          name: 'Player $playerId',
          isLeader: false,
          role: roleName,
          isAlive: true,
        ));
        playerId++;
      }
    }

    // If total roles don't match player count, that's already an error
    if (mockPlayers.length != playerCount) {
      return {
        'isValid': false,
        'error': 'Role count (${mockPlayers.length}) doesn\'t match player count ($playerCount)',
      };
    }

    // Check for immediate win conditions
    final winCondition = checkWinConditions(mockPlayers);
    if (winCondition['gameOver'] == true) {
      return {
        'isValid': false,
        'error': 'This role distribution would create an immediate win condition',
        'details': '${winCondition['winner']} team would win immediately',
        'winCondition': winCondition,
      };
    }

    return {'isValid': true};
  }

  // Check win conditions for a list of players
  static Map<String, dynamic> checkWinConditions(List<Player> players) {
    if (players.isEmpty) {
      return {'gameOver': false};
    }

    // Count alive players by team
    final Map<String, int> aliveCount = {
      'Town': 0,
      'Bandit': 0,
      'Neutral': 0,
      'Total': 0,
    };

    for (final player in players) {
      if (player.isAlive) {
        aliveCount['Total'] = aliveCount['Total']! + 1;
        final team = getTeamByRole(player.role ?? '');
        if (team != null && aliveCount.containsKey(team)) {
          aliveCount[team] = aliveCount[team]! + 1;
        }
      }
    }

    // Check win conditions
    String? winningTeam;
    bool gameOver = false;
    String? winType;

    // Town wins if all bandits are eliminated and there are still town members alive
    if (aliveCount['Bandit'] == 0 && aliveCount['Town']! > 0) {
      winningTeam = 'Town';
      gameOver = true;
      winType = 'elimination';
    }

    // Bandits win if they outnumber the town (not equal)
    if (aliveCount['Bandit']! > 0 && aliveCount['Bandit']! > aliveCount['Town']!) {
      winningTeam = 'Bandit';
      gameOver = true;
      winType = 'majority';
    }
    // Special Bandit win condition: If Bandits equal Town AND no Gunslinger alive
    else if (aliveCount['Bandit']! > 0 && aliveCount['Bandit'] == aliveCount['Town']) {
      // Check if there's a living Gunslinger in Town
      final hasLivingGunslinger = players.any((p) => 
        p.isAlive && p.role == 'Gunslinger'
      );
      
      if (!hasLivingGunslinger) {
        winningTeam = 'Bandit';
        gameOver = true;
        winType = 'no_gunslinger_parity';
      }
    }

    // Check for Jester win condition - if Jester was voted out
    final jesterWinner = players.any((p) => 
      p.role == 'Jester' && 
      !p.isAlive && 
      p.eliminatedBy == 'vote'
    );

    if (jesterWinner) {
      // Jester wins immediately when voted out - no other conditions needed
      winningTeam = 'Jester';
      gameOver = true;
      winType = 'jester_vote_out';
    }

    // Special case: If only neutral players remain alive (last man standing)
    if (!gameOver && aliveCount['Total']! > 0 && aliveCount['Town'] == 0 && aliveCount['Bandit'] == 0) {
      // Find the last remaining neutral player
      final lastNeutral = players.where((p) => p.isAlive && getTeamByRole(p.role ?? '') == 'Neutral').firstOrNull;
      if (lastNeutral != null && aliveCount['Total'] == 1) {
        winningTeam = lastNeutral.role;
        gameOver = true;
        winType = 'last_standing';
      }
    }

    // Check for draw condition - if no players are alive
    if (!gameOver && aliveCount['Total'] == 0) {
      winningTeam = 'Draw';
      gameOver = true;
      winType = 'draw';
    }

    if (gameOver && winningTeam != null) {
      return {
        'gameOver': true,
        'winner': winningTeam,
        'winType': winType,
        'aliveCount': aliveCount,
      };
    }

    return {'gameOver': false};
  }
}
