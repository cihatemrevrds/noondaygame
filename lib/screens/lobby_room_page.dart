import 'package:flutter/material.dart';
import '../widgets/menu_button.dart';
import '../widgets/player_avatar.dart';
import '../models/player.dart';
import 'role_selection_page.dart';

class LobbyRoomPage extends StatefulWidget {
  final String roomName;
  final int maxPlayers;

  const LobbyRoomPage({
    super.key, 
    required this.roomName, 
    required this.maxPlayers,
  });

  @override
  State<LobbyRoomPage> createState() => _LobbyRoomPageState();
}

class _LobbyRoomPageState extends State<LobbyRoomPage> {  // Mock players - in a real app, this would come from a server
  late List<Player> players;
  late String roomCode;
  // Generate a random room code with letters and numbers
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed similar looking characters (0,O,1,I)
    String result = '';
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    
    for (int i = 0; i < 4; i++) {
      final index = (random + i * 7) % chars.length;
      result += chars[index];
    }
    
    return result;
  }

  @override
  void initState() {
    super.initState();    // Initialize with some mock players - using realistic usernames
    players = [
      Player(name: 'JohnDoe87', isLeader: true),
      Player(name: 'CowboyGamer', isLeader: false),
      Player(name: 'SaloonKeeper', isLeader: false),
      Player(name: 'GunSlinger42', isLeader: false),
      Player(name: 'DesertRider', isLeader: false),
    ];
    
    // Generate a 4-character alphanumeric room code
    roomCode = _generateRoomCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: Text(
          widget.roomName,
          style: const TextStyle(
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
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
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
                children: [                  Text(
                    'Players: ${players.length}',
                    style: const TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 18,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Share this code with your friends:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.brown[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          roomCode,  // Using the generated room code
                          style: const TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 24,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white),
                          onPressed: () {
                            // Implement copy to clipboard
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Room code copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, // 4 avatars per row
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 20, // Increased spacing to accommodate usernames
                  childAspectRatio: 0.75, // Adjust for taller cells to fit usernames better
                ),
                itemCount: players.length, // Only show actual players
                itemBuilder: (context, index) {
                  return PlayerAvatar(
                    name: players[index].name,
                    isLeader: players[index].isLeader,
                  );
                },
              ),
            ),Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (players.length < 4)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Need at least 4 players to start',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),                  MenuButton(
                    text: 'NEXT',
                    onPressed: players.length >= 4
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoleSelectionPage(players: players),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
