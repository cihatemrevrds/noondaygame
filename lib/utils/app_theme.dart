import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF4E2C0B);
  static const Color secondary = Color(0xFF8B4513);
  static const Color accent = Color(0xFFD2B48C);
  static const Color background = Color(0xFFF5F5DC);
  static const Color text = Color(0xFF3E2723);
  static const Color textLight = Color(0xFF6D4C41);
  static const Color error = Color(0xFFB71C1C);
}

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontFamily: 'Rye',
    fontSize: 48,
    color: AppColors.primary,
    shadows: [
      Shadow(
        offset: Offset(2, 2),
        blurRadius: 2,
        color: Colors.black26,
      ),
    ],
  );
  
  static const TextStyle headline2 = TextStyle(
    fontFamily: 'Rye',
    fontSize: 32,
    color: AppColors.primary,
  );
  
  static const TextStyle headline3 = TextStyle(
    fontFamily: 'Rye',
    fontSize: 24,
    color: AppColors.primary,
  );
  
  static const TextStyle bodyText = TextStyle(
    fontSize: 16, 
    color: AppColors.text,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontFamily: 'Rye',
    fontSize: 20,
    color: Colors.white,
  );
}
