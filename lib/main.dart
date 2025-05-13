import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_or_register_menu.dart';
import 'utils/app_theme.dart';
import 'services/lobby_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set preferred orientations to portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
    // Eski ve terkedilmiş lobileri temizle, oyuncu alanlarını güncelle
  try {
    final lobbyService = LobbyService();
    
    // Uygulama başlatıldığında eski lobileri temizle
    lobbyService.cleanupOldLobbies().catchError((error) {
      print('Error during initial lobby cleanup: $error');
    });
    
    // Eksik oyuncu alanlarını güncelle
    lobbyService.updatePlayerFields().catchError((error) {
      print('Error during player fields update: $error');
    });
  } catch (e) {
    print('Could not initialize lobby services: $e');
  }
  
  runApp(const NoondayApp());
}

class NoondayApp extends StatelessWidget {
  const NoondayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noonday Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Rye',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
      ),
      home: const LoginOrRegisterMenu(),
    );
  }
}
