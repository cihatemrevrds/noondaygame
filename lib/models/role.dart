import 'package:flutter/material.dart';

enum RoleTeam { town, bandit, neutral }

class Role {
  final String name;
  final String imageName;
  int count;
  final String description;
  final RoleTeam team;
  final String shortDescription;

  Role({
    required this.name,
    required this.imageName,
    required this.count,
    required this.description,
    required this.team,
    required this.shortDescription,
  });

  // Add copyWith method for easy modifications
  Role copyWith({
    String? name,
    String? imageName,
    int? count,
    String? description,
    RoleTeam? team,
    String? shortDescription,
  }) {
    return Role(
      name: name ?? this.name,
      imageName: imageName ?? this.imageName,
      count: count ?? this.count,
      description: description ?? this.description,
      team: team ?? this.team,
      shortDescription: shortDescription ?? this.shortDescription,
    );
  }

  // Town Team Roles
  static Role get doctor => Role(
    name: 'Doctor',
    imageName: 'doctor.png',
    count: 0,
    team: RoleTeam.town,
    shortDescription: 'Can protect one player each night from being killed',
    description:
        'Can protect one player each night from being killed.\n'
        'Can only self-protect once per game.\n'
        'Belongs to the Town team.',
  );

  static Role get sheriff => Role(
    name: 'Sheriff',
    imageName: 'sheriff.png',
    count: 0,
    team: RoleTeam.town,
    shortDescription:
        'Investigates players at night to determine if they\'re suspicious',
    description:
        'Investigates players at night to determine if they\'re suspicious or innocent.\n'
        'Chieftain appears innocent to Sheriff despite being a Bandit.\n'
        'Belongs to the Town team.',
  );

  static Role get escort => Role(
    name: 'Escort',
    imageName: 'escort.png',
    count: 0,
    team: RoleTeam.town,
    shortDescription: 'Blocks another player from using their night ability',
    description:
        'Blocks another player from using their night ability.\n'
        'Target\'s role action won\'t be processed that night.\n'
        'Belongs to the Town team.',
  );

  static Role get peeper => Role(
    name: 'Peeper',
    imageName: 'peeper.png',
    count: 0,
    team: RoleTeam.town,
    shortDescription: 'Watches a player at night and sees who visits them',
    description:
        'Watches a player at night and sees who visits them.\n'
        'Doesn\'t learn the roles of visitors, just that they visited.\n'
        'Belongs to the Town team.',
  );
  static Role get gunslinger => Role(
    name: 'Gunslinger',
    imageName: 'gunslinger.png',
    count: 0,
    team: RoleTeam.town,
    shortDescription:
        'Can select a target to shoot at night with limited bullets',    description:
        'Can select a target to shoot during night phase only.\n'
        'Has 1 bullet total for the entire game.\n'
        'When shooting, identity is revealed to everyone.\n'
        'Belongs to the Town team.',
  );

  // Bandit Team Roles
  static Role get gunman => Role(
    name: 'Gunman',
    imageName: 'gunman.png',
    count: 0,
    team: RoleTeam.bandit,
    shortDescription: 'Can kill one player each night',
    description:
        'Can kill one player each night.\n'
        'Target can be overridden by Chieftain\'s orders.\n'
        'Belongs to the Bandit team.',
  );

  static Role get chieftain => Role(
    name: 'Chieftain',
    imageName: 'chieftain.png',
    count: 0,
    team: RoleTeam.bandit,
    shortDescription: 'Issues kill orders to Gunman, overriding their choice',
    description:
        'Issues kill orders to Gunman, overriding their choice.\n'
        'Appears innocent to Sheriff investigations.\n'
        'Takes over killing if no Gunman remains.\n'
        'Belongs to the Bandit team.',
  );

  // Neutral Team Roles
  static Role get jester => Role(
    name: 'Jester',
    imageName: 'jester.png',
    count: 0,
    team: RoleTeam.neutral,
    shortDescription: 'Has no night ability, wins if voted out by the town',
    description:
        'Has no night ability.\n'
        'Wins if voted out by the town during day phase.\n'
        'Belongs to the Neutral team.',
  );

  // Get all available roles grouped by team
  static Map<RoleTeam, List<Role>> getAllRolesByTeam() {
    return {
      RoleTeam.town: [doctor, sheriff, escort, peeper, gunslinger],
      RoleTeam.bandit: [gunman, chieftain],
      RoleTeam.neutral: [jester],
    };
  }

  // Get all roles as a flat list
  static List<Role> getAllRoles() {
    final rolesByTeam = getAllRolesByTeam();
    return [
      ...rolesByTeam[RoleTeam.town]!,
      ...rolesByTeam[RoleTeam.bandit]!,
      ...rolesByTeam[RoleTeam.neutral]!,
    ];
  }

  // Get team color for UI
  static Color getTeamColor(RoleTeam team) {
    switch (team) {
      case RoleTeam.town:
        return const Color(0xFF4CAF50); // Green for citizens/town
      case RoleTeam.bandit:
        return const Color(0xFFC62828); // Red for bandits
      case RoleTeam.neutral:
        return const Color(0xFF616161); // Gray for neutrals
    }
  }

  // Get team name for display
  static String getTeamName(RoleTeam team) {
    switch (team) {
      case RoleTeam.town:
        return 'Town';
      case RoleTeam.bandit:
        return 'Bandit';
      case RoleTeam.neutral:
        return 'Neutral';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageName': imageName,
      'count': count,
      'description': description,
      'team': team.toString(),
      'shortDescription': shortDescription,
    };
  }

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      name: map['name'] ?? '',
      imageName: map['imageName'] ?? '',
      count: map['count'] ?? 0,
      description: map['description'] ?? '',
      team: RoleTeam.values.firstWhere(
        (e) => e.toString() == map['team'],
        orElse: () => RoleTeam.town,
      ),
      shortDescription: map['shortDescription'] ?? '',
    );
  }
}
