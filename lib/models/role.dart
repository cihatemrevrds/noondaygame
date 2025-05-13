class Role {
  final String name;
  final String imageName;
  int count;
  final String description;

  Role({
    required this.name,
    required this.imageName,
    required this.count,
    required this.description,
  });
  
  // Add copyWith method for easy modifications
  Role copyWith({
    String? name,
    String? imageName,
    int? count,
    String? description,
  }) {
    return Role(
      name: name ?? this.name,
      imageName: imageName ?? this.imageName,
      count: count ?? this.count,
      description: description ?? this.description,
    );
  }

  // Predefined roles as static getters
  static Role get sheriff => Role(
        name: 'Sheriff',
        imageName: 'sheriff.png',
        count: 1,
        description: 'Lead the town to capture all outlaws.\n\n'
            'The Sheriff must protect the town and eliminate all Outlaws and the Renegade. '
            'As the only player whose role is known to all from the start, the Sheriff is often targeted first.',
      );

  static Role get deputy => Role(
        name: 'Deputy',
        imageName: 'deputy.png',
        count: 1,
        description: 'Help the sheriff capture all outlaws.\n\n'
            'Deputies work with the Sheriff to eliminate all Outlaws and the Renegade. '
            'Their loyalty is to the law and they must protect the Sheriff at all costs.',
      );

  static Role get outlaw => Role(
        name: 'Outlaw',
        imageName: 'outlaw.png',
        count: 2,
        description: 'Capture the sheriff and eliminate the deputies.\n\n'
            'Outlaws seek to eliminate the Sheriff and anyone who stands in their way. '
            'They often work together, but their primary goal is the Sheriff\'s demise.',
      );

  static Role get renegade => Role(
        name: 'Renegade',
        imageName: 'renegade.png',
        count: 1,
        description: 'Be the last player standing. Work with both sides depending on the situation.\n\n'
            'The Renegade plays a complex game of shifting alliances. They must be the last one standing, '
            'which means helping the weaker side until the time is right to betray everyone.',
      );

  // Get all standard roles as a list
  static List<Role> getStandardRoles() {
    return [
      sheriff,
      deputy,
      outlaw,
      renegade,
    ];
  }
  // The constructor is already defined at the top of the file

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageName': imageName,
      'count': count,
      'description': description,
    };
  }

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      name: map['name'] ?? '',
      imageName: map['imageName'] ?? '',
      count: map['count'] ?? 0,
      description: map['description'] ?? '',
    );
  }
}
