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
    if (role == null) return 'Rol henüz atanmamış';

    switch (role) {
      case 'Doctor':
        return 'Her gece bir kişiyi ölümden koruyabilirsin. Kendini de koruyabilirsin.';
      case 'Gunman':
        return 'Her gece bir kişiyi öldürebilirsin. Dikkatli seç!';
      case 'Sheriff':
        return 'Her gece bir kişinin hangi takımda olduğunu öğrenebilirsin.';
      case 'Prostitute':
        return 'Her gece bir kişinin gece aksiyonunu engelleyebilirsin.';
      case 'Peeper':
        return 'Her gece bir kişinin rolünü öğrenebilirsin.';
      case 'Chieftain':
        return 'Bandit takımının liderisin. Şerif seni kasabalı olarak görür.';
      case 'Townsperson':
        return 'Kasabalısın. Gece aksiyonu yok, gündüz oylamasında banditleri bulmaya çalış.';
      default:
        return 'Bilinmeyen rol';
    }
  }
}
