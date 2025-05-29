import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/menu_button.dart';
import '../services/lobby_service.dart';
import 'lobby_setup_page.dart';
import 'lobby_room_page.dart';
import 'settings_page.dart';

class MainMenu extends StatefulWidget {
  final String username;

  const MainMenu({super.key, required this.username});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final TextEditingController _roomCodeController = TextEditingController();
  final LobbyService _lobbyService = LobbyService();

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  void _showJoinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'JOIN ROOM',
          style: TextStyle(
            fontFamily: 'Rye',
            fontSize: 24,
            color: Colors.brown,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter room code:',
              style: TextStyle(fontFamily: 'Rye', color: Colors.brown),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomCodeController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                hintText: 'e.g. ABCDE',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                // Force uppercase
                if (value != value.toUpperCase()) {
                  _roomCodeController.text = value.toUpperCase();
                  _roomCodeController.selection = TextSelection.fromPosition(
                      TextPosition(offset: value.length));
                }
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.brown,
                fontWeight: FontWeight.bold,
                fontFamily: 'Rye',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _joinRoom(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'JOIN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Rye',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinRoom(BuildContext context) async {
    final code = _roomCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code')),
      );
      return;
    }

    // Close dialog first
    Navigator.pop(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );    try {      final playerName = user.displayName ?? 
                        (widget.username.isNotEmpty ? widget.username : user.email?.split('@')[0] ?? 'Player');
      
      print('Attempting to join lobby with code: $code as $playerName');
      
      // First join attempt
      bool success = await _lobbyService.joinLobby(
        code,
        user.uid,
        playerName,
      );
      
      // If first attempt fails, try one more time after a short delay
      if (!success) {
        await Future.delayed(const Duration(milliseconds: 1000));
        print('First join attempt failed, retrying...');
        success = await _lobbyService.joinLobby(
          code,
          user.uid,
          playerName,
        );
      }
      
      // Verify player is in the lobby
      if (success) {
        print('Successfully joined lobby, verifying player data');
        success = await _lobbyService.verifyPlayerInLobby(code, user.uid);
      }      // Remove loading indicator BEFORE any navigation
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (success) {
        print('Verification successful, navigating to LobbyRoomPage');
        
        // Check if widget is still mounted before navigation
        if (context.mounted) {
          // Use pushReplacement instead of push to avoid stack issues
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LobbyRoomPage(
                roomName: 'Room $code',
                lobbyCode: code,
              ),
            ),
          );
        }      } else {
        print('Failed to join or verify lobby');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to join room. Check your code and try again.')),
          );
        }
      }
    } catch (e) {
      // Remove loading indicator safely
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      _roomCodeController.clear();
    }
  }

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
            const SizedBox(height: 20),            Text(
              'Welcome, ${widget.username}!',
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
              onPressed: () => _showJoinDialog(context),
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
