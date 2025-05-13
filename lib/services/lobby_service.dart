import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LobbyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate random 5-letter lobby code
  String generateLobbyCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random();
    return List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
  }
  Future<String?> createLobby(
    String hostUid,
    String hostName,
    int maxPlayers,
  ) async {
    try {
      final lobbyCode = generateLobbyCode();

      final lobbyRef = _firestore.collection('lobbies').doc(lobbyCode);      await lobbyRef.set({
        'hostUid': hostUid,
        'hostName': hostName,
        'maxPlayers': maxPlayers,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting',  // Add status field for tracking lobby state
        'players': [
          {
            'id': hostUid, 
            'name': hostName, 
            'isHost': true,
            'role': null,       // Host için de role değeri eklendi
            'isAlive': true,    // Host için de isAlive değeri eklendi
            'team': null        // Host için de team değeri eklendi
          },
        ],
      });

      return lobbyCode;
    } catch (e) {
      print('Error creating lobby: $e');
      return null;
    }
  }

  Future<bool> joinLobby(
    String lobbyCode,
    String playerId,
    String playerName,
  ) async {
    try {
      final lobbyRef = FirebaseFirestore.instance
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());

      final doc = await lobbyRef.get();

      if (!doc.exists) {
        print('Lobby not found');
        return false;
      }

      final data = doc.data()!;
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

      // Check if lobby is full
      final maxPlayers = data['maxPlayers'] ?? 20;
      if (players.length >= maxPlayers) {
        print('Lobby is full');
        return false;
      }

      // Check if already in lobby
      final alreadyIn = players.any((p) => p['id'] == playerId);
      if (alreadyIn) {
        print('Player already in lobby');
        return true;
      }

      final newPlayer = {
        'id': playerId,
        'name': playerName,
        'isHost': false,
        'role': null,
        'isAlive': true,
        'team': null,
      };

      players.add(newPlayer);

      await lobbyRef.update({'players': players});
      return true;
    } catch (e) {
      print('Join lobby error: $e');
      return false;
    }
  }  Future<void> leaveLobby(String lobbyCode, String playerId) async {
    try {
      print('Player $playerId leaving lobby: $lobbyCode');
      
      final lobbyRef = FirebaseFirestore.instance
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());

      final doc = await lobbyRef.get();
      if (!doc.exists) {
        print('Lobby not found when player is leaving');
        return;
      }

      final data = doc.data()!;
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      
      // Remove this player from the list
      players.removeWhere((player) => player['id'] == playerId || player['uid'] == playerId);
      
      // If no players left, delete the entire lobby
      if (players.isEmpty) {
        print('No players left in lobby, deleting lobby: $lobbyCode');
        try {
          await lobbyRef.delete();
          print('Empty lobby deleted successfully: $lobbyCode');
          
          // Verify deletion
          final verifyDoc = await lobbyRef.get();
          if (verifyDoc.exists) {
            print('WARNING: Lobby still exists after deletion attempt! Trying again...');
            await FirebaseFirestore.instance
                .collection('lobbies')
                .doc(lobbyCode.toUpperCase())
                .delete();
          }
        } catch (deleteError) {
          print('Error deleting empty lobby: $deleteError');
          // One last force delete attempt
          try {
            await FirebaseFirestore.instance
                .collection('lobbies')
                .doc(lobbyCode.toUpperCase())
                .delete();
          } catch (_) {}
        }
        return;
      }
      
      // Check if the host is leaving
      final hostUid = data['hostUid'];
      if (hostUid == playerId) {
        print('Host $playerId is leaving lobby $lobbyCode');
        // Host is leaving - delete the entire lobby regardless of other players
        try {
          await lobbyRef.delete();
          print('Lobby deleted successfully after host left: $lobbyCode');
          
          // Verify deletion
          final verifyDoc = await lobbyRef.get();
          if (verifyDoc.exists) {
            print('WARNING: Lobby still exists after host left! Trying forced delete...');
            await FirebaseFirestore.instance
                .collection('lobbies')
                .doc(lobbyCode.toUpperCase())
                .delete();
          }
        } catch (deleteError) {
          print('Error deleting lobby after host left: $deleteError');
          // One last force delete attempt
          try {
            await FirebaseFirestore.instance
                .collection('lobbies')
                .doc(lobbyCode.toUpperCase())
                .delete();
          } catch (_) {}
        }
        return;
      } else {
        // Regular player leaving, just update the players list
        await lobbyRef.update({'players': players});
        print('Regular player successfully removed from lobby');
      }
    } catch (e) {
      print('Leave lobby error: $e');
    }
  }
  Future<void> kickPlayer(
    String lobbyCode,
    String playerIdToKick,
    String hostId,
  ) async {
    try {
      final lobbyRef = FirebaseFirestore.instance
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());

      final doc = await lobbyRef.get();
      if (!doc.exists) return;

      final data = doc.data()!;
      if (data['hostUid'] != hostId) {
        print('Only host can kick players.');
        return;
      }

      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      
      // İlgili oyuncuyu çıkar
      players.removeWhere((player) => player['id'] == playerIdToKick);
      
      // Tüm oyuncuların gerekli alanları var mı kontrol et
      for (int i = 0; i < players.length; i++) {
        final player = players[i];
        if (!player.containsKey('role')) player['role'] = null;
        if (!player.containsKey('isAlive')) player['isAlive'] = true;
        if (!player.containsKey('team')) player['team'] = null;
      }
      
      await lobbyRef.update({'players': players});
    } catch (e) {
      print('Kick player error: $e');
    }
  }

  Future<bool> updateRoles(
    String lobbyCode,
    Map<String, int> selectedRoles,
  ) async {
    try {
      final lobbyRef = FirebaseFirestore.instance
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());

      final doc = await lobbyRef.get();

      if (!doc.exists) {
        print('Lobby not found');
        return false;
      }

      await lobbyRef.update({'roles': selectedRoles});
      return true;
    } catch (e) {
      print('Update roles error: $e');
      return false;
    }
  }

  Future<bool> startGame(String lobbyCode, String hostId) async {
    try {
      final uri = Uri.parse(
        'https://us-central1-noondaygame.cloudfunctions.net/startGame',
      ); // Bölgen farklıysa düzenle

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'lobbyCode': lobbyCode, 'hostId': hostId}),
      );

      if (response.statusCode == 200) {
        print("Game started!");
        return true;
      } else {
        print("Start game failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Start game error: $e");
      return false;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToLobbyUpdates(
    String lobbyCode,
  ) {
    final lobbyRef = _firestore
        .collection('lobbies')
        .doc(lobbyCode.toUpperCase());
    return lobbyRef.snapshots();
  }  Future<bool> deleteLobby(String lobbyCode, String hostId) async {
    print('Attempting to delete lobby: $lobbyCode by host: $hostId');
    bool success = false;
    
    // Try multiple times to ensure deletion works
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('Delete attempt #$attempt for lobby: $lobbyCode');
        
        final lobbyRef = _firestore
            .collection('lobbies')
            .doc(lobbyCode.toUpperCase());
        
        // First check if the lobby exists
        final doc = await lobbyRef.get();
        
        if (!doc.exists) {
          print('Lobby already deleted or not found: $lobbyCode');
          return true; // Consider it a success if the lobby is already gone
        }
        
        // Force delete regardless of host (for reliability)
        await lobbyRef.delete();
        print('Lobby deletion command sent: $lobbyCode');
        
        // Verify the deletion worked with a small delay
        await Future.delayed(const Duration(milliseconds: 500));
        final verifyDoc = await lobbyRef.get();
        
        if (!verifyDoc.exists) {
          print('Lobby deletion verified: $lobbyCode');
          success = true;
          break; // Successfully deleted
        } else {
          print('Lobby still exists after attempt #$attempt, trying a different approach');
          
          // Try direct Firestore reference on last attempt
          if (attempt == 3) {
            await FirebaseFirestore.instance
                .collection('lobbies')
                .doc(lobbyCode.toUpperCase())
                .delete();
                
            // Final verification
            await Future.delayed(const Duration(milliseconds: 500));
            final finalCheck = await lobbyRef.get();
            success = !finalCheck.exists;
          }
        }
      } catch (e) {
        print('Delete lobby error on attempt #$attempt: $e');
        // Continue to next attempt
      }
    }
    
    print('Final deletion status for lobby $lobbyCode: ${success ? "SUCCESS" : "FAILED"}');
    return success;
  }

  // Eski veya terkedilmiş lobileri temizle
  Future<void> cleanupOldLobbies() async {
    try {
      print('Checking for abandoned lobbies to cleanup');
      
      final lobbiesRef = _firestore.collection('lobbies');
      final now = DateTime.now();
      
      // Get all lobbies
      final snapshot = await lobbiesRef.get();
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final lobbyCode = doc.id;
          
          // Timestamp kontrolü için
          final createdAt = data['createdAt'] as Timestamp?;
          final createdTime = createdAt?.toDate();
          
          // Eğer 12 saatten eski bir lobi ise veya timestamp yoksa
          if (createdTime == null || now.difference(createdTime).inHours > 12) {
            print('Cleaning up old lobby: $lobbyCode (created: ${createdTime ?? "unknown time"})');
            await doc.reference.delete();
            continue;
          }
          
          // Oyuncular listesi boş olan veya 1'den az oyuncusu olan lobileri temizle
          final players = data['players'] as List<dynamic>?;
          if (players == null || players.isEmpty) {
            print('Cleaning up empty lobby: $lobbyCode');
            await doc.reference.delete();
          }
        } catch (e) {
          print('Error processing lobby during cleanup: $e');
        }
      }
      
      print('Lobby cleanup completed');
    } catch (e) {
      print('Error during lobby cleanup: $e');
    }
  }

  // Mevcut lobilerdeki oyuncuların eksik alanlarını güncelle
  Future<void> updatePlayerFields() async {
    try {
      print('Checking and updating missing player fields in lobbies');
      
      final lobbiesRef = _firestore.collection('lobbies');
      
      // Get all lobbies
      final snapshot = await lobbiesRef.get();
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final lobbyCode = doc.id;
          
          bool needsUpdate = false;
          final List<Map<String, dynamic>> updatedPlayers = [];
          
          final players = data['players'] as List<dynamic>?;
          if (players != null && players.isNotEmpty) {
            for (var playerData in players) {
              final player = Map<String, dynamic>.from(playerData as Map<String, dynamic>);
              
              // Eksik alanları kontrol edip ekliyoruz
              if (!player.containsKey('role')) {
                player['role'] = null;
                needsUpdate = true;
              }
              
              if (!player.containsKey('isAlive')) {
                player['isAlive'] = true;
                needsUpdate = true;
              }
              
              if (!player.containsKey('team')) {
                player['team'] = null;
                needsUpdate = true;
              }
              
              updatedPlayers.add(player);
            }
            
            // Güncelleme gerekiyorsa veritabanını güncelle
            if (needsUpdate) {
              print('Updating player fields in lobby: $lobbyCode');
              await doc.reference.update({'players': updatedPlayers});
            }
          }
        } catch (e) {
          print('Error updating player fields in lobby: $e');
        }
      }
      
      print('Player field updates completed');
    } catch (e) {
      print('Error during player field updates: $e');
    }
  }
}
