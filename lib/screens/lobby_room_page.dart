import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../widgets/menu_button.dart';
import '../widgets/player_avatar.dart';
import '../models/player.dart';
import '../services/lobby_service.dart';
import 'role_selection_page.dart';

class LobbyRoomPage extends StatefulWidget {
  final String roomName;
  final String lobbyCode;

  const LobbyRoomPage({
    super.key, 
    required this.roomName, 
    required this.lobbyCode,
  });

  @override
  State<LobbyRoomPage> createState() => _LobbyRoomPageState();
}

class _LobbyRoomPageState extends State<LobbyRoomPage> with WidgetsBindingObserver {  final LobbyService _lobbyService = LobbyService();
  List<Player> players = [];
  bool _isLoading = false;
  bool _isHost = false;
  String _currentUserId = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _lobbySubscription;
  @override
  void initState() {
    super.initState();
    developer.log("=== LobbyRoomPage initState started ===", name: 'LobbyRoomPage');
    
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    developer.log("Current user ID: $_currentUserId", name: 'LobbyRoomPage');
    developer.log("Lobby code: ${widget.lobbyCode}", name: 'LobbyRoomPage');
    developer.log("Room name: ${widget.roomName}", name: 'LobbyRoomPage');
    
    WidgetsBinding.instance.addObserver(this);
    developer.log("Added widget observer", name: 'LobbyRoomPage');
      // Add 5-second force-stop mechanism for debugging
    Timer(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        developer.log("!!! FORCE STOP: Still loading after 5 seconds !!!", name: 'LobbyRoomPage');
        developer.log("Current state - isLoading: $_isLoading, isHost: $_isHost, players count: ${players.length}", name: 'LobbyRoomPage');
        developer.log("Subscription active: ${_lobbySubscription != null}", name: 'LobbyRoomPage');
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    developer.log("About to call _setupLobbyListener", name: 'LobbyRoomPage');
    _setupLobbyListener();
    developer.log("=== LobbyRoomPage initState completed ===", name: 'LobbyRoomPage');
  }
    @override
  void dispose() {
    // Clean up when this Widget is removed from the widget tree
    _lobbySubscription?.cancel();
    
    // Try to clean up the lobby when leaving the page
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (_isHost) {
        // Force delete the lobby if host is leaving
        FirebaseFirestore.instance
            .collection('lobbies')
            .doc(widget.lobbyCode.toUpperCase())
            .delete()
            .catchError((e) {
              developer.log("Error during dispose cleanup: $e", name: 'LobbyRoomPage');
            });
      }
    }
    
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle states
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      // App is being killed or sent to background, try to leave lobby gracefully
      _cleanupLobby();
    }
  }
    void _cleanupLobby() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      developer.log("App lifecycle changed, cleaning up lobby", name: 'LobbyRoomPage');
      
      // Regardless of host status, try to remove player and lobby if needed
      if (_isHost) {
        // For host, always delete the entire lobby
        developer.log("Host's app is closing, deleting lobby forcefully", name: 'LobbyRoomPage');
        
        // First try with the service
        final success = await _lobbyService.deleteLobby(widget.lobbyCode, user.uid);
        
        // If that fails, try direct approach
        if (!success) {
          developer.log("Direct Firestore deletion attempt on app close", name: 'LobbyRoomPage');
          await FirebaseFirestore.instance
              .collection('lobbies')
              .doc(widget.lobbyCode.toUpperCase())
              .delete()
              .timeout(const Duration(seconds: 5), onTimeout: () {
                developer.log("Deletion timed out, app is probably closing", name: 'LobbyRoomPage');
                return;
              });
        }
      } else {
        // For regular player, just leave the lobby
        await _lobbyService.leaveLobby(widget.lobbyCode, user.uid);
      }
    } catch (e) {
      developer.log("Error during lobby cleanup: $e", name: 'LobbyRoomPage');
      // Last resort - direct deletion attempt with minimal error handling
      try {
        await FirebaseFirestore.instance
            .collection('lobbies')
            .doc(widget.lobbyCode.toUpperCase())
            .delete();
      } catch (_) {}
    }
  }  void _setupLobbyListener() {
    developer.log("=== _setupLobbyListener started ===", name: 'LobbyRoomPage');
    
    // Show loading indicator initially
    setState(() {
      _isLoading = true;
    });
    developer.log("Set loading state to true", name: 'LobbyRoomPage');
    
    try {
      developer.log("Creating lobby subscription for code: ${widget.lobbyCode}", name: 'LobbyRoomPage');      _lobbySubscription = _lobbyService.listenToLobbyUpdates(widget.lobbyCode).listen(
        (snapshot) {
          // Her setState'den önce mounted kontrolü
          if (!mounted) {
            developer.log("Widget not mounted, skipping state update", name: 'LobbyRoomPage');
            return;
          }
          
          developer.log("=== Lobby snapshot received ===", name: 'LobbyRoomPage');
          developer.log("Snapshot exists: ${snapshot.exists}", name: 'LobbyRoomPage');
          
          if (!snapshot.exists) {
            developer.log("Lobby doesn't exist, navigating back to main menu", name: 'LobbyRoomPage');
            // Lobby has been deleted, return to main menu
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lobby has been deleted'),
                ),
              );
              Navigator.popUntil(context, (route) => route.isFirst);
            }
            return;
          }

          final data = snapshot.data();
          if (data == null) {
            developer.log("Received null data from lobby snapshot", name: 'LobbyRoomPage');
            return;
          }

          developer.log("Received lobby data: ${data.toString()}", name: 'LobbyRoomPage');
          
          // Check host information
          final hostUid = data['hostUid'] as String?;
          if (hostUid == null) {
            developer.log("Host UID is missing in lobby data", name: 'LobbyRoomPage');
          } else {
            developer.log("Host UID: $hostUid", name: 'LobbyRoomPage');
          }
          
          final isHost = hostUid == _currentUserId;
          developer.log("Current user is host: $isHost", name: 'LobbyRoomPage');          // Update players
          try {
            developer.log("Processing players data...", name: 'LobbyRoomPage');
            final playersData = data['players'] as List<dynamic>? ?? [];
            developer.log("Raw players data: $playersData", name: 'LobbyRoomPage'); // RAW DATA LOG
            developer.log("Number of players in lobby: ${playersData.length}", name: 'LobbyRoomPage');
            
            // Check if current user is in the players list
            bool currentUserFound = false;
            final playersList = playersData
                .map((p) {
                  final map = p as Map<String, dynamic>;
                  developer.log("Processing player data: $map", name: 'LobbyRoomPage'); // EACH PLAYER LOG
                  
                  // Check for all possible ID field names
                  final playerId = map['id'] as String? ?? 
                                  map['uid'] as String? ?? 
                                  map['userId'] as String? ?? 
                                  map['playerId'] as String? ?? '';
                  
                  developer.log("Player ID extracted: '$playerId', Current user: '$_currentUserId'", name: 'LobbyRoomPage');
                  
                  // Check if this is the current player
                  if (playerId == _currentUserId) {
                    developer.log("✅ FOUND CURRENT USER IN PLAYERS LIST!", name: 'LobbyRoomPage');
                    currentUserFound = true;
                  }
                  
                  return Player(
                    id: playerId,
                    name: map['name'] as String? ?? 'Player',
                    isLeader: playerId == hostUid,
                    role: map['role'] as String?,
                    isAlive: map['isAlive'] as bool? ?? true,
                    team: map['team'] as String?,
                  );
                })
                .toList();
            
            if (!currentUserFound) {
              developer.log("❌ CRITICAL: Current user NOT FOUND in players list!", name: 'LobbyRoomPage');
              developer.log("Current user ID: '$_currentUserId'", name: 'LobbyRoomPage');
              developer.log("All player IDs found: ${playersList.map((p) => p.id).toList()}", name: 'LobbyRoomPage');
            }
                
            // Check if game has started
            final gameStatus = data['status'];
            developer.log("Current lobby status: $gameStatus", name: 'LobbyRoomPage');
            
            if (gameStatus == 'started' && mounted) {
              developer.log("Game status is 'started', navigating to RoleSelectionPage", name: 'LobbyRoomPage');
              // Prevent multiple navigations by adding a flag
              if (!Navigator.of(context).canPop() || 
                  ModalRoute.of(context)?.settings.name != 'role_selection') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'role_selection'),
                    builder: (context) => RoleSelectionPage(
                      players: playersList,
                      lobbyCode: widget.lobbyCode,
                      isHost: isHost,
                    ),
                  ),
                );
              }
              return;
            }

            developer.log("About to update UI state...", name: 'LobbyRoomPage');
            if (mounted) {
              setState(() {
                players = playersList;
                _isHost = isHost;
                _isLoading = false;  // Hide loading indicator once data is processed
              });
              developer.log("UI state updated successfully - Loading: false, Players: ${players.length}, IsHost: $_isHost", name: 'LobbyRoomPage');
            }
          } catch (e) {
            developer.log("Error processing lobby data: $e", name: 'LobbyRoomPage');
            if (mounted) {
              setState(() {
                _isLoading = false;  // Hide loading indicator on error
              });
              // Show error to user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading lobby data: $e')),
              );
            }
          }
        },
        onError: (e) {
          developer.log("Error in lobby listener: $e", name: 'LobbyRoomPage');
          if (mounted) {
            setState(() {
              _isLoading = false;  // Hide loading indicator on error
            });
            // Show error to user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error listening to lobby updates: $e')),
            );
          }
        },
      );
      developer.log("Lobby subscription created successfully", name: 'LobbyRoomPage');
    } catch (e) {
      developer.log("Exception while setting up lobby listener: $e", name: 'LobbyRoomPage');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to lobby: $e')),
        );
      }
    }
    
    developer.log("=== _setupLobbyListener completed ===", name: 'LobbyRoomPage');
  }
  Future<void> _leaveLobby() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        developer.log("Cannot leave lobby: User not logged in", name: 'LobbyRoomPage');
        Navigator.pop(context);
        return;
      }

      if (_isHost) {
        // Eğer host ise, lobiyi sil
        developer.log("Host is leaving, attempting to delete lobby: ${widget.lobbyCode}", name: 'LobbyRoomPage');
        final success = await _lobbyService.deleteLobby(widget.lobbyCode, user.uid);
        
        if (success) {
          developer.log("Lobby successfully deleted", name: 'LobbyRoomPage');
        } else {
          // Try one more time with direct Firestore access if the service method failed
          developer.log("Failed to delete lobby via service, trying direct Firestore access", name: 'LobbyRoomPage');
          try {
            await FirebaseFirestore.instance
                .collection('lobbies')
                .doc(widget.lobbyCode.toUpperCase())
                .delete();
            developer.log("Lobby deleted via direct Firestore access", name: 'LobbyRoomPage');
          } catch (innerError) {
            developer.log("Failed to delete lobby: $innerError", name: 'LobbyRoomPage');
            // Continue with navigation even if deletion failed
          }
        }
      } else {
        // Değilse, sadece lobiyi terk et
        developer.log("Non-host player leaving lobby", name: 'LobbyRoomPage');
        await _lobbyService.leaveLobby(widget.lobbyCode, user.uid);
      }

      // Always return to the main menu, even if there was an error
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      developer.log("Exception when leaving lobby: $e", name: 'LobbyRoomPage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving lobby: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
        // Still return to the main menu
        Navigator.pop(context);
      }
    }
  }
  Future<void> _startGame() async {
    if (!_isHost) return;
    
    if (players.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Need at least 4 players to start',
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
      if (user == null) throw Exception('User not logged in');
      
      // Update lobby status to 'started' in Firestore
      await FirebaseFirestore.instance
        .collection('lobbies')
        .doc(widget.lobbyCode)
        .update({'status': 'started'});
      
      // The listener will automatically navigate to RoleSelectionPage for all players
      developer.log("Game started, lobby status updated to 'started'", name: 'LobbyRoomPage');
      
      // Only navigate manually if the listener doesn't trigger
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoleSelectionPage(
              players: players,
              lobbyCode: widget.lobbyCode,
              isHost: _isHost,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting game: $e'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyCodeToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.lobbyCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room code copied to clipboard')),
    );
  }

  // Build a loading view with western style
  Widget _buildLoadingView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/saloon_bg.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Loading Lobby...',
              style: TextStyle(
                fontFamily: 'Rye',
                fontSize: 24,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 3,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Colors.brown,
              strokeWidth: 5,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // If loading takes too long, allow cancellation
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'Rye',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _leaveLobby,
          ),
        ],
      ),
      body: _isLoading
        ? _buildLoadingView()
        : Container(
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
                children: [
                  Text(
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
                          widget.lobbyCode,
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
                          onPressed: _copyCodeToClipboard,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.75,
                ),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  return PlayerAvatar(
                    name: players[index].name,
                    isLeader: players[index].isLeader,
                  );
                },
              ),
            ),
            Padding(
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
                    ),
                  _isLoading
                      ? const CircularProgressIndicator(color: Color(0xFF4E2C0B))
                      : MenuButton(
                          text: 'NEXT',
                          onPressed: _isHost && players.length >= 4 ? _startGame : null,
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
