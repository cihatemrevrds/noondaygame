import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_or_register_menu.dart';
import 'utils/app_theme.dart';
import 'services/lobby_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set preferred orientations to portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Eski ve terkedilmiş lobileri temizle, oyuncu alanlarını güncelle
  try {
    final lobbyService = LobbyService();

    // Start periodic cleanup service
    LobbyService.startPeriodicCleanup();

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

class NoondayApp extends StatefulWidget {
  const NoondayApp({super.key});

  @override
  State<NoondayApp> createState() => _NoondayAppState();
}

class _NoondayAppState extends State<NoondayApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LobbyService.stopPeriodicCleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // App is being terminated - perform emergency cleanup
        _performGlobalCleanup();
        break;
      case AppLifecycleState.paused:
        // App went to background - user might return, but prepare for cleanup
        break;
      case AppLifecycleState.resumed:
        // App resumed - everything is fine
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  void _performGlobalCleanup() {
    // Emergency cleanup for the entire app
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Fire and forget - clean up any lobbies this user might be in
      LobbyService().cleanupPlayerLobbies(user.uid).catchError((error) {
        print('Emergency cleanup error: $error');
      });
    }
  }

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
