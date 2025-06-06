import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/menu_button.dart';
import '../services/lobby_service.dart';
import 'lobby_setup_page.dart';
import 'lobby_room_page.dart';
import 'settings_page.dart';
import 'phase_testing_screen.dart';

class MainMenu extends StatefulWidget {
  final String username;

  const MainMenu({super.key, required this.username});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final TextEditingController _roomCodeController = TextEditingController();
  final LobbyService _lobbyService = LobbyService();
  bool _isLoading = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  void _showJoinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    hintText: 'e.g. ABCDE',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    // Force uppercase
                    if (value != value.toUpperCase()) {
                      _roomCodeController.text = value.toUpperCase();
                      _roomCodeController
                          .selection = TextSelection.fromPosition(
                        TextPosition(offset: value.length),
                      );
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
    print('=== JOIN ROOM STARTED ===');
    print('Attempting to join room with code: $code');

    if (code.isEmpty) {
      print('ERROR: Empty room code');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a room code')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('ERROR: User is null');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You need to be logged in')));
      return;
    }

    print('Current user: ${user.uid}');

    // Set loading state like host does
    setState(() {
      _isLoading = true;
    });

    try {
      print('Starting join process...');
      final playerName =
          user.displayName ??
          (widget.username.isNotEmpty
              ? widget.username
              : user.email?.split('@')[0] ?? 'Player');

      print('Player name: $playerName');
      print('Attempting to join lobby with code: $code as $playerName');

      // First join attempt
      print('First join attempt starting...');
      bool success = await _lobbyService.joinLobby(code, user.uid, playerName);
      print('First join attempt result: $success');

      // If first attempt fails, try one more time after a short delay
      if (!success) {
        print('First join attempt failed, waiting 1 second...');
        await Future.delayed(const Duration(milliseconds: 1000));
        print('Starting retry attempt...');
        success = await _lobbyService.joinLobby(code, user.uid, playerName);
        print('Retry attempt result: $success');
      }

      if (success) {
        print(
          'Lobby joined successfully, waiting for sync before navigation...',
        );

        // Firestore senkronizasyonu için biraz bekle (host gibi)
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          print('Navigating to LobbyRoomPage as player');

          // HOST GİBİ PUSH KULLAN (pushReplacement değil)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      LobbyRoomPage(roomName: 'Room $code', lobbyCode: code),
            ),
          );
          print('Navigation to LobbyRoomPage completed');
        }
      } else {
        throw Exception("Failed to join lobby");
      }
    } catch (e) {
      print('Exception caught in _joinRoom: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _roomCodeController.clear();
      print('_joinRoom completed - room code cleared');
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
            const SizedBox(height: 20),
            Text(
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
                  MaterialPageRoute(
                    builder: (context) => const LobbySetupPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF4E2C0B))
                : MenuButton(
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
            const SizedBox(height: 20),
            MenuButton(
              text: 'PHASE TESTING',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PhaseTestingScreen(),
                  ),
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
