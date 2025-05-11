class Player {
  final String name;
  final bool isLeader;

  Player({
    required this.name, 
    required this.isLeader,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isLeader': isLeader,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      name: map['name'] ?? '',
      isLeader: map['isLeader'] ?? false,
    );
  }
}
