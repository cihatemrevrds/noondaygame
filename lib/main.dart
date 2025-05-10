import 'package:flutter/material.dart';

void main() {
  runApp(const NoondayApp());
}

class NoondayApp extends StatelessWidget {
  const NoondayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/western_town_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'NOONDAY',
              style: TextStyle(
                fontFamily: 'Rye',
                fontSize: 48,
                color: Colors.brown,
                shadows: [
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 2,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            MenuButton(text: 'LOBI KUR'),
            const SizedBox(height: 20),
            MenuButton(text: 'LOBIYE KATIL'),
            const SizedBox(height: 20),
            MenuButton(text: 'AYARLAR'),
          ],
        ),
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  final String text;

  const MenuButton({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4E2C0B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Rye',
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
