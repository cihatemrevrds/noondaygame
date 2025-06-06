class UserSettings {
  String nickname;
  String email;
  String profilePicture;
  bool soundEnabled;
  double soundVolume;
  bool musicEnabled;
  double musicVolume;

  UserSettings({
    this.nickname = '',
    this.email = '',
    this.profilePicture = 'sheriff.jpg',
    this.soundEnabled = true,
    this.soundVolume = 0.8,
    this.musicEnabled = true,
    this.musicVolume = 0.6,
  });

  // Create settings from a map (e.g. for Firebase)
  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      nickname: map['nickname'] ?? '',
      email: map['email'] ?? '',
      profilePicture: map['profilePicture'] ?? 'sheriff.jpg',
      soundEnabled: map['soundEnabled'] ?? true,
      soundVolume: map['soundVolume']?.toDouble() ?? 0.8,
      musicEnabled: map['musicEnabled'] ?? true,
      musicVolume: map['musicVolume']?.toDouble() ?? 0.6,
    );
  }

  // Convert settings to a map (e.g. for Firebase)
  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'email': email,
      'profilePicture': profilePicture,
      'soundEnabled': soundEnabled,
      'soundVolume': soundVolume,
      'musicEnabled': musicEnabled,
      'musicVolume': musicVolume,
    };
  }

  // Create a copy with modified fields
  UserSettings copyWith({
    String? nickname,
    String? email,
    String? profilePicture,
    bool? soundEnabled,
    double? soundVolume,
    bool? musicEnabled,
    double? musicVolume,
  }) {
    return UserSettings(
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      profilePicture: profilePicture ?? this.profilePicture,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
    );
  }
}
