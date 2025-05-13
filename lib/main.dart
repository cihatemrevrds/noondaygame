import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_or_register_menu.dart';
import 'utils/app_theme.dart';
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
