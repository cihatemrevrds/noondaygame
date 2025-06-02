// Configuration file for recommended role settings based on player count
// Developers can easily modify these settings to balance the game

class RecommendedRoles {
  // Recommended role configurations for different player counts
  static const Map<int, Map<String, int>> _recommendations = {
    // 4 players (Minimum game size)
    4: {'Sheriff': 1, 'Doctor': 1, 'Gunman': 1, 'Chieftain': 1},

    // 5 players
    5: {'Sheriff': 1, 'Doctor': 1, 'Escort': 1, 'Gunman': 1, 'Chieftain': 1},

    // 6 players
    6: {
      'Sheriff': 1,
      'Doctor': 1,
      'Escort': 1,
      'Gunman': 1,
      'Chieftain': 1,
      'Jester': 1,
    },

    // 7 players
    7: {
      'Sheriff': 1,
      'Doctor': 1,
      'Escort': 1,
      'Peeper': 1,
      'Gunman': 1,
      'Chieftain': 1,
      'Jester': 1,
    },

    // 8 players
    8: {
      'Sheriff': 1,
      'Doctor': 1,
      'Escort': 1,
      'Peeper': 1,
      'Gunslinger': 1,
      'Gunman': 1,
      'Chieftain': 1,
      'Jester': 1,
    },

    // 9 players
    9: {
      'Sheriff': 1,
      'Doctor': 1,
      'Escort': 1,
      'Peeper': 1,
      'Gunslinger': 1,
      'Gunman': 2,
      'Chieftain': 1,
      'Jester': 1,
    },

    // 10 players
    10: {
      'Sheriff': 1,
      'Doctor': 1,
      'Escort': 1,
      'Peeper': 1,
      'Gunslinger': 2,
      'Gunman': 2,
      'Chieftain': 1,
      'Jester': 1,
    },

    // 11 players
    11: {
      'Sheriff': 1,
      'Doctor': 1,
      'Escort': 1,
      'Peeper': 1,
      'Gunslinger': 2,
      'Gunman': 2,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 12 players
    12: {
      'Sheriff': 1,
      'Doctor': 2,
      'Escort': 1,
      'Peeper': 1,
      'Gunslinger': 2,
      'Gunman': 2,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 13 players
    13: {
      'Sheriff': 1,
      'Doctor': 2,
      'Escort': 1,
      'Peeper': 2,
      'Gunslinger': 2,
      'Gunman': 2,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 14 players
    14: {
      'Sheriff': 1,
      'Doctor': 2,
      'Escort': 2,
      'Peeper': 2,
      'Gunslinger': 2,
      'Gunman': 3,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 15 players
    15: {
      'Sheriff': 1,
      'Doctor': 2,
      'Escort': 2,
      'Peeper': 2,
      'Gunslinger': 3,
      'Gunman': 3,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 16 players
    16: {
      'Sheriff': 1,
      'Doctor': 3,
      'Escort': 2,
      'Peeper': 2,
      'Gunslinger': 3,
      'Gunman': 3,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 17 players
    17: {
      'Sheriff': 1,
      'Doctor': 3,
      'Escort': 2,
      'Peeper': 3,
      'Gunslinger': 3,
      'Gunman': 3,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 18 players
    18: {
      'Sheriff': 1,
      'Doctor': 3,
      'Escort': 3,
      'Peeper': 3,
      'Gunslinger': 3,
      'Gunman': 3,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 19 players
    19: {
      'Sheriff': 1,
      'Doctor': 3,
      'Escort': 3,
      'Peeper': 3,
      'Gunslinger': 4,
      'Gunman': 3,
      'Chieftain': 2,
      'Jester': 1,
    },

    // 20 players (Maximum game size)
    20: {
      'Sheriff': 1,
      'Doctor': 4,
      'Escort': 3,
      'Peeper': 3,
      'Gunslinger': 4,
      'Gunman': 3,
      'Chieftain': 2,
      'Jester': 1,
    },
  };

  /// Get recommended role configuration for a specific player count
  /// Returns null if no recommendation exists for that player count
  static Map<String, int>? getRecommended(int playerCount) {
    return _recommendations[playerCount];
  }

  /// Get the closest recommended configuration for player counts not directly supported
  /// Falls back to the nearest lower player count configuration
  static Map<String, int>? getClosestRecommended(int playerCount) {
    if (_recommendations.containsKey(playerCount)) {
      return _recommendations[playerCount];
    }

    // Find the highest player count that's less than or equal to the requested count
    int? closestCount;
    for (int count in _recommendations.keys) {
      if (count <= playerCount) {
        if (closestCount == null || count > closestCount) {
          closestCount = count;
        }
      }
    }

    return closestCount != null ? _recommendations[closestCount] : null;
  }

  /// Check if recommendations exist for a specific player count
  static bool hasRecommendation(int playerCount) {
    return _recommendations.containsKey(playerCount);
  }

  /// Get all supported player counts
  static List<int> getSupportedPlayerCounts() {
    return _recommendations.keys.toList()..sort();
  }

  /// Get the minimum and maximum supported player counts
  static int get minPlayerCount =>
      _recommendations.keys.reduce((a, b) => a < b ? a : b);
  static int get maxPlayerCount =>
      _recommendations.keys.reduce((a, b) => a > b ? a : b);

  /// Validate if a role configuration follows recommended patterns
  /// This can be useful for game balance analysis
  static bool isBalanced(Map<String, int> roles, int playerCount) {
    final totalRoles = roles.values.fold(0, (sum, count) => sum + count);
    if (totalRoles != playerCount) return false;

    // Check if there's at least one town role and one bandit role
    bool hasTown = false;
    bool hasBandit = false;

    final townRoles = ['Sheriff', 'Doctor', 'Escort', 'Peeper', 'Gunslinger'];
    final banditRoles = ['Gunman', 'Chieftain'];

    for (String role in roles.keys) {
      if (townRoles.contains(role) && roles[role]! > 0) {
        hasTown = true;
      }
      if (banditRoles.contains(role) && roles[role]! > 0) {
        hasBandit = true;
      }
    }

    return hasTown && hasBandit;
  }

  /// Get role distribution summary for display purposes
  static Map<String, int> getRoleDistribution(Map<String, int> roles) {
    final townRoles = ['Sheriff', 'Doctor', 'Escort', 'Peeper', 'Gunslinger'];
    final banditRoles = ['Gunman', 'Chieftain'];
    final neutralRoles = ['Jester'];

    int townCount = 0;
    int banditCount = 0;
    int neutralCount = 0;

    for (String role in roles.keys) {
      final count = roles[role] ?? 0;
      if (townRoles.contains(role)) {
        townCount += count;
      } else if (banditRoles.contains(role)) {
        banditCount += count;
      } else if (neutralRoles.contains(role)) {
        neutralCount += count;
      }
    }

    return {'Town': townCount, 'Bandit': banditCount, 'Neutral': neutralCount};
  }
}
