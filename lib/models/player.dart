class Player {
  final String id;
  final String name;
  final bool isLeader;
  final String? role;
  final bool isAlive;

  Player({
    required this.name, 
    this.isLeader = false,
    this.id = '',
    this.role,
    this.isAlive = true,
  });

  // Create Player from Firestore map
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown',
      isLeader: map['isHost'] as bool? ?? false,
      role: map['role'] as String?,
      isAlive: map['isAlive'] as bool? ?? true,
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
    };
  }

  // Create a copy with modified fields
  Player copyWith({
    String? id,
    String? name,
    bool? isLeader,
    String? role,
    bool? isAlive,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      isLeader: isLeader ?? this.isLeader,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
    );
  }
}
