import 'package:flutter/material.dart';

class RoleUtils {
  static Color getRoleColor(String role) {
    switch (role) {
      // Citizens (Green shades)
      case 'Doctor':
        return const Color(0xFF2E7D32); // Dark Green
      case 'Sheriff':
        return const Color(0xFF388E3C); // Medium Green
      case 'Escort':
        return const Color(0xFF43A047); // Light Green
      case 'Peeper':
        return const Color(0xFF4CAF50); // Standard Green
      case 'Gunslinger':
        return const Color(0xFF66BB6A); // Lighter Green
      // Bandits (Red shades)
      case 'Gunman':
        return const Color(0xFFC62828); // Dark Red
      case 'Chieftain':
        return const Color(0xFFD32F2F); // Medium Red
      // Neutrals (Gray shades)
      case 'Jester':
        return const Color(0xFF616161); // Medium Gray
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
      case 'Gunslinger':
        return Icons.local_fire_department; // Gun/shooting icon
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
      case 'Gunslinger': // Gunslinger can act during day or night
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
        return 'You are the leader of the bandit team. Sheriff sees you as innocent.';
      case 'Gunslinger':
        return 'You have 2 bullets to shoot players during any phase. If you kill a town member, you lose your second bullet.';
      default:
        return 'Unknown role';
    }
  }
}
