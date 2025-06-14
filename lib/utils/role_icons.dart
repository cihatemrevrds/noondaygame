import 'package:flutter/material.dart';

/// Bu sınıf, oyundaki rol ikonlarını yönetmek için kullanılır.
/// Roller için ikonları merkezi bir yerden yönetmeyi sağlar.
class RoleIcons {
  // Rol ikon yolları için temel dizin
  static const String _basePath = 'assets/images/roles/';
  
  // Her rol için sabit yollar (JPG formatında)
  static const String peeper = '${_basePath}peeper.jpg';
  static const String doctor = '${_basePath}doctor.jpg';
  static const String sheriff = '${_basePath}sheriff.jpg';
  static const String escort = '${_basePath}escort.jpg';
  static const String gunman = '${_basePath}gunman.jpg';
  static const String gunslinger = '${_basePath}gunslinger.jpg';
  static const String jester = '${_basePath}jester.jpg';  
  static const String chieftain = '${_basePath}chieftain.jpg';
  
  /// Rol ismine göre ikon yolu döndürür
  static String getRoleIconPath(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'peeper': return peeper;
      case 'doctor': return doctor;
      case 'sheriff': return sheriff;
      case 'escort': return escort;
      case 'gunman': return gunman;
      case 'gunslinger': return gunslinger;
      case 'jester': return jester;      case 'chieftain': return chieftain;
      default: return peeper; // Bilinmeyen rol için varsayılan ikon olarak peeper kullanılıyor
    }
  }
  
  /// Rol ikonu widget'ı oluşturur
  static Widget buildRoleIcon({
    required String roleName, 
    double size = 40.0,
    bool withBackground = false,
    Color backgroundColor = Colors.white,
    double backgroundRadius = 50.0,
  }) {
    final iconPath = getRoleIconPath(roleName);
    
    // Yuvarlak ikon için ClipOval kullanılıyor, ClipRRect yerine
    Widget icon = Container(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          iconPath,
          width: size,
          height: size,
          fit: BoxFit.cover, // Resmi tam olarak dolduracak şekilde kırp
        ),
      ),
    );
    
    if (withBackground) {
      return Container(
        width: size * 1.5,
        height: size * 1.5,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(child: icon),
      );
    }
    
    return icon;
  }
  
  /// Oyun içi görüntülenecek büyük rol ikonu oluşturur
  static Widget buildGameRoleIcon({
    required String roleName,
    double size = 70.0,
    bool withText = true,
    TextStyle? textStyle,
  }) {
    Widget icon = RoleIcons.buildRoleIcon(
      roleName: roleName,
      size: size,
      withBackground: true,
      backgroundColor: Colors.white,
    );
    
    if (!withText) {
      return icon;
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 10),
        Text(
          roleName.substring(0, 1).toUpperCase() + roleName.substring(1),
          style: textStyle ?? const TextStyle(
            fontSize: 28, 
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(2, 2),
                blurRadius: 3.0,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
