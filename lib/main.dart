import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_or_register_menu.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
