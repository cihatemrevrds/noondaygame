class GameConfig {
  // Game rules
  static const int minPlayers = 1;
  static const int maxPlayers = 12;
  static const int defaultPlayerCount = 6;
  
  // Role configuration
  static Map<String, int> getDefaultRoleCounts(int playerCount) {
    // Base configuration
    final Map<String, int> roles = {
      'Sheriff': 1,
      'Deputy': 0,
      'Outlaw': 2,
      'Renegade': 1,
    };
    
    // Adjust based on player count
    if (playerCount >= 7) {
      roles['Deputy'] = 2;
      roles['Outlaw'] = 3;
    } else if (playerCount >= 5) {
      roles['Deputy'] = 1;
    }
    
    if (playerCount >= 8) {
      roles['Outlaw'] = 4;
    }
    
    return roles;
  }
  
  // Game durations
  static const int turnDurationSeconds = 30;
  static const int voteDurationSeconds = 20;
  
  // Room code generator
  static String generateRoomCode() {
    // In a real app, this would generate a random code
    return 'ABCD';
  }
}
