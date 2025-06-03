import 'package:flutter/material.dart';

class RoleUtils {
  static Color getRoleColor(String role) {
    switch (role) {
      case 'Doctor':
        return Colors.blue;
      case 'Gunman':
        return Colors.red;
      case 'Sheriff':
        return Colors.green;
      case 'Prostitute':
        return Colors.pink;
      case 'Peeper':
        return Colors.orange;
      case 'Chieftain':
        return Colors.brown;
      case 'Townsperson':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  static IconData getRoleIcon(String role) {
    switch (role) {
      case 'Doctor':
        return Icons.healing;
      case 'Gunman':
        return Icons.sports_bar; // Gun ikonu olarak sports_bar kullanıyoruz
      case 'Sheriff':
        return Icons.star;
      case 'Prostitute':
        return Icons.favorite;
      case 'Peeper':
        return Icons.visibility;
      case 'Chieftain':
        return Icons.verified_user;
      case 'Townsperson':
        return Icons.person;
      default:
        return Icons.help;
    }
  }

  static bool hasNightAction(String role) {
    switch (role) {
      case 'Doctor':
      case 'Gunman':
      case 'Sheriff':
      case 'Prostitute':
      case 'Peeper':
        return true;
      default:
        return false;
    }
  }
  static Future<String> getRoleDescription(String? role) async {
    if (role == null) return 'Role not assigned yet';

    switch (role) {
      case 'Doctor':
        return 'Each night you can protect one person from death. You can protect yourself.';
      case 'Gunman':
        return 'Each night you can kill one person. Choose carefully!';
      case 'Sheriff':
        return 'Each night you can learn which team a person belongs to.';
      case 'Prostitute':
        return 'Each night you can block someone\'s night action.';
      case 'Peeper':
        return 'Each night you can learn someone\'s role.';
      case 'Chieftain':
        return 'You are the leader of the bandit team. Sheriff sees you as a townsperson.';
      case 'Townsperson':
        return 'You are a townsperson. No night action, try to find bandits in day voting.';
      default:
        return 'Unknown role';
    }
  }
}
