import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/menu_button.dart';
import '../widgets/input_field.dart';
import '../services/lobby_service.dart';
import 'lobby_room_page.dart';

class LobbySetupPage extends StatefulWidget {
  const LobbySetupPage({super.key});

  @override
  State<LobbySetupPage> createState() => _LobbySetupPageState();
}

class _LobbySetupPageState extends State<LobbySetupPage> {
  final TextEditingController _roomNameController = TextEditingController();
  final LobbyService _lobbyService = LobbyService();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _createLobby() async {
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
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception("You must be logged in to create a lobby");
      }
        final lobbyCode = await _lobbyService.createLobby(
        user.uid,
        user.displayName ?? (user.email?.split('@')[0] ?? 'Host'),
        6, // Default max players
      );
        if (lobbyCode != null) {
        print('Lobby created successfully, waiting for sync before navigation...');
        
        // Firestore senkronizasyonu için biraz bekle
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted) {
          print('Navigating to LobbyRoomPage as host');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LobbyRoomPage(
                roomName: _roomNameController.text,
                lobbyCode: lobbyCode,
              ),
            ),
          );
        }
      } else {
        throw Exception("Failed to create lobby");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Rye'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF4E2C0B))
                : MenuButton(
                    text: 'CREATE LOBBY',
                    onPressed: _createLobby,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
