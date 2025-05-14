class Player {
  final String id;
  final String name;
  final bool isLeader;
  final String? role;
  final bool isAlive;
  final String? team;

  Player({
    required this.name, 
    this.isLeader = false,
    this.id = '',
    this.role,
    this.isAlive = true,
    this.team,
  });

  // Create Player from Firestore map
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown',
      isLeader: map['isHost'] as bool? ?? false,
      role: map['role'] as String?,
      isAlive: map['isAlive'] as bool? ?? true,
      team: map['team'] as String?,
    );
  }

  // Convert Player to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isHost': isLeader,
      'role': role,
      'isAlive': isAlive,
      'team': team,
    };
  }

  // Create a copy with modified fields
  Player copyWith({
    String? id,
    String? name,
    bool? isLeader,
    String? role,
    bool? isAlive,
    String? team,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      isLeader: isLeader ?? this.isLeader,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
      team: team ?? this.team,
    );
  }
}
