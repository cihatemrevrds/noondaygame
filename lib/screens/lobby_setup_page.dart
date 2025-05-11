import 'package:flutter/material.dart';
import '../widgets/menu_button.dart';
import '../widgets/input_field.dart';
import 'lobby_room_page.dart';

class LobbySetupPage extends StatefulWidget {
  const LobbySetupPage({super.key});

  @override
  State<LobbySetupPage> createState() => _LobbySetupPageState();
}

class _LobbySetupPageState extends State<LobbySetupPage> {
  final TextEditingController _roomNameController = TextEditingController();

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: const Text(
          'SETUP LOBBY',
          style: TextStyle(
            fontFamily: 'Rye',
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/saloon_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Room Name',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 16,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InputField(
                      controller: _roomNameController,
                      hintText: 'Enter room name',
                    ),                    // Player count selection removed
                  ],
                ),
              ),
              const SizedBox(height: 30),
              MenuButton(
                text: 'CREATE LOBBY',
                onPressed: () {
                  if (_roomNameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a room name',
                          style: TextStyle(fontFamily: 'Rye'),
                        ),
                      ),
                    );
                    return;
                  }                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LobbyRoomPage(
                        roomName: _roomNameController.text,
                        maxPlayers: 6, // Default to 6 players
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
