import 'package:flutter/material.dart';
import '../widgets/menu_button.dart';
import 'lobby_setup_page.dart';
import 'settings_page.dart';

class MainMenu extends StatelessWidget {
  final String username;

  const MainMenu({super.key, required this.username});

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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
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
            const SizedBox(height: 20),
            Text(
              'Welcome, $username!',
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 20,
                color: Colors.brown,
              ),
            ),
            const Spacer(),
            MenuButton(
              text: 'CREATE ROOM',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LobbySetupPage()),
                );
              },
            ),
            const SizedBox(height: 20),
            MenuButton(
              text: 'JOIN ROOM',
              onPressed: () {
                // Implement joining a room
                // This could show a dialog for entering a room code
              },
            ),
            const SizedBox(height: 20),
            MenuButton(
              text: 'SETTINGS',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
