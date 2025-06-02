import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class LobbyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _cleanupTimer;

  // Getter for testing purposes
  static Timer? get cleanupTimer => _cleanupTimer;

  // Start periodic cleanup - call this once when app starts
  static void startPeriodicCleanup() {
    _cleanupTimer?.cancel(); // Cancel any existing timer

    // Run cleanup every 30 minutes
    _cleanupTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      LobbyService().cleanupOldLobbies().catchError((error) {
        print('Periodic cleanup error: $error');
      });
    });

    print('Started periodic lobby cleanup (every 30 minutes)');
  }

  // Stop periodic cleanup
  static void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    print('Stopped periodic lobby cleanup');
  }

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

      final lobbyRef = _firestore.collection('lobbies').doc(lobbyCode);
      await lobbyRef.set({
        'hostUid': hostUid,
        'hostName': hostName,
        'maxPlayers': maxPlayers,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting', // Add status field for tracking lobby state
        'players': [
          {
            'id': hostUid,
            'name': hostName,
            'isHost': true,
            'role': null, // Host için de role değeri eklendi
            'isAlive': true, // Host için de isAlive değeri eklendi
            'team': null, // Host için de team değeri eklendi
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
      print(
        'Player $playerName (ID: $playerId) attempting to join lobby: $lobbyCode',
      );

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
      final lobbyStatus = data['status'] as String? ?? 'waiting';

      // Don't let players join if the game has already started
      if (lobbyStatus != 'waiting') {
        print('Cannot join: Game has already started');
        return false;
      }

      // Check if lobby is full
      final maxPlayers = data['maxPlayers'] ?? 20;
      if (players.length >= maxPlayers) {
        print('Lobby is full');
        return false;
      }

      // Check if already in lobby - if yes, update any missing fields
      final playerIndex = players.indexWhere(
        (p) => p['id'] == playerId || p['uid'] == playerId,
      );

      if (playerIndex >= 0) {
        print('Player already in lobby, updating fields if needed');

        var existingPlayer = players[playerIndex];
        bool needsUpdate = false;

        // Ensure all required fields are present
        if (!existingPlayer.containsKey('role')) {
          existingPlayer['role'] = null;
          needsUpdate = true;
        }

        if (!existingPlayer.containsKey('isAlive')) {
          existingPlayer['isAlive'] = true;
          needsUpdate = true;
        }

        if (!existingPlayer.containsKey('team')) {
          existingPlayer['team'] = null;
          needsUpdate = true;
        }

        // Update name if it has changed
        if (existingPlayer['name'] != playerName) {
          existingPlayer['name'] = playerName;
          needsUpdate = true;
        }

        if (needsUpdate) {
          players[playerIndex] = existingPlayer;
          await lobbyRef.update({'players': players});
          print('Updated existing player data in lobby');
        }

        // Verify player can see the lobby
        await Future.delayed(const Duration(milliseconds: 500));
        return await verifyPlayerInLobby(lobbyCode, playerId);
      }

      // Add new player with all required fields
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
      print('Player successfully added to lobby');

      // Wait briefly and verify the player was added correctly
      await Future.delayed(const Duration(milliseconds: 500));
      return await verifyPlayerInLobby(lobbyCode, playerId);
    } catch (e) {
      print('Join lobby error: $e');
      return false;
    }
  }

  Future<void> leaveLobby(String lobbyCode, String playerId) async {
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
      players.removeWhere(
        (player) => player['id'] == playerId || player['uid'] == playerId,
      );

      // If no players left, delete the entire lobby
      if (players.isEmpty) {
        print('No players left in lobby, deleting lobby: $lobbyCode');
        try {
          await lobbyRef.delete();
          print('Empty lobby deleted successfully: $lobbyCode');

          // Verify deletion
          final verifyDoc = await lobbyRef.get();
          if (verifyDoc.exists) {
            print(
              'WARNING: Lobby still exists after deletion attempt! Trying again...',
            );
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
            print(
              'WARNING: Lobby still exists after host left! Trying forced delete...',
            );
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
  }

  Future<bool> deleteLobby(String lobbyCode, String hostId) async {
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
          print(
            'Lobby still exists after attempt #$attempt, trying a different approach',
          );

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

    print(
      'Final deletion status for lobby $lobbyCode: ${success ? "SUCCESS" : "FAILED"}',
    );
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
      int cleanedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final lobbyCode = doc.id;

          // Timestamp kontrolü için
          final createdAt = data['createdAt'] as Timestamp?;
          final createdTime = createdAt?.toDate();

          // Clean up lobbies that are:
          // 1. Older than 6 hours (reduced from 12 hours)
          // 2. Have no timestamp (corrupted data)
          // 3. Have empty players list
          // 4. Are stuck in "waiting" status for too long

          bool shouldCleanup = false;
          String reason = '';

          if (createdTime == null) {
            shouldCleanup = true;
            reason = 'missing timestamp';
          } else if (now.difference(createdTime).inHours > 6) {
            shouldCleanup = true;
            reason = 'older than 6 hours';
          }

          // Check for empty or invalid players list
          final players = data['players'] as List<dynamic>?;
          if (players == null || players.isEmpty) {
            shouldCleanup = true;
            reason = 'empty players list';
          }

          // Check for lobbies stuck in waiting state for more than 2 hours
          final status = data['status'] as String? ?? 'waiting';
          if (status == 'waiting' &&
              createdTime != null &&
              now.difference(createdTime).inHours > 2) {
            shouldCleanup = true;
            reason = 'stuck in waiting state for 2+ hours';
          }

          // Check for games that have been running for more than 4 hours
          if (status == 'started' &&
              createdTime != null &&
              now.difference(createdTime).inHours > 4) {
            shouldCleanup = true;
            reason = 'game running for 4+ hours';
          }

          if (shouldCleanup) {
            print('Cleaning up lobby: $lobbyCode ($reason)');
            await doc.reference.delete();
            cleanedCount++;
          }
        } catch (e) {
          print('Error processing lobby during cleanup: $e');
        }
      }

      print('Lobby cleanup completed - cleaned $cleanedCount lobbies');
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
              final player = Map<String, dynamic>.from(
                playerData as Map<String, dynamic>,
              );

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

  // Verify that a player is properly added to a lobby and has all required fields
  Future<bool> verifyPlayerInLobby(String lobbyCode, String playerId) async {
    try {
      print('Verifying player $playerId is properly in lobby $lobbyCode');

      final lobbyRef = _firestore
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());

      // Check if lobby exists
      final lobbyDoc = await lobbyRef.get();
      if (!lobbyDoc.exists) {
        print('Cannot verify player: Lobby does not exist');
        return false;
      }

      final lobbyData = lobbyDoc.data()!;
      final players = List<Map<String, dynamic>>.from(
        lobbyData['players'] ?? [],
      );

      // Find player in the lobby
      final playerIndex = players.indexWhere(
        (p) => p['id'] == playerId || p['uid'] == playerId,
      );

      if (playerIndex < 0) {
        print('Player not found in lobby data');
        return false;
      }

      // Ensure player has all required fields
      var player = players[playerIndex];
      bool updatedFields = false;

      if (!player.containsKey('role')) {
        player['role'] = null;
        updatedFields = true;
      }

      if (!player.containsKey('isAlive')) {
        player['isAlive'] = true;
        updatedFields = true;
      }

      if (!player.containsKey('team')) {
        player['team'] = null;
        updatedFields = true;
      }

      // If any fields were missing, update the player data
      if (updatedFields) {
        players[playerIndex] = player;
        await lobbyRef.update({'players': players});
        print('Updated player fields in lobby');
      }

      return true;
    } catch (e) {
      print('Error verifying player in lobby: $e');
      return false;
    }
  }

  Future<void> transferHost(String lobbyCode, String newHostId) async {
    try {
      final lobbyRef = FirebaseFirestore.instance
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());

      final doc = await lobbyRef.get();
      if (!doc.exists) {
        print('Lobby not found');
        return;
      }

      await lobbyRef.update({'hostUid': newHostId});
      print('Host transferred successfully');
    } catch (e) {
      print('Error transferring host: $e');
    }
  }

  Future<void> leaveAsHostWithTransfer(String lobbyCode, String hostId) async {
    try {
      print(
        'Host $hostId leaving lobby $lobbyCode, attempting to transfer host',
      );

      final lobbyRef = FirebaseFirestore.instance
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());

      final doc = await lobbyRef.get();
      if (!doc.exists) {
        print('Lobby not found when host is leaving');
        return;
      }

      final data = doc.data()!;
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

      // Remove the current host from players list
      players.removeWhere(
        (player) => player['id'] == hostId || player['uid'] == hostId,
      );

      // If no other players left, delete the lobby
      if (players.isEmpty) {
        print('No other players left, deleting lobby: $lobbyCode');
        await lobbyRef.delete();
        return;
      }

      // Find the next player to become host (first player in the list)
      final newHost = players.first;
      final newHostId = newHost['id'] ?? newHost['uid'] ?? '';

      if (newHostId.isEmpty) {
        print('No valid player found to transfer host to, deleting lobby');
        await lobbyRef.delete();
        return;
      }

      // Update the lobby with new host and updated players list
      await lobbyRef.update({'hostUid': newHostId, 'players': players});

      print('Host successfully transferred from $hostId to $newHostId');
    } catch (e) {
      print('Error in leaveAsHostWithTransfer: $e');
      // Fallback: try to delete the lobby if transfer fails
      try {
        await FirebaseFirestore.instance
            .collection('lobbies')
            .doc(lobbyCode.toUpperCase())
            .delete();
      } catch (deleteError) {
        print('Error in fallback deletion: $deleteError');
      }
    }
  }

  // Clean up any lobbies where a specific player is present (for app termination)
  Future<void> cleanupPlayerLobbies(String playerId) async {
    try {
      print('Cleaning up lobbies for player: $playerId');

      final lobbiesRef = _firestore.collection('lobbies');
      final snapshot = await lobbiesRef.get();

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final players = data['players'] as List<dynamic>? ?? [];

          // Check if this player is in this lobby
          final playerInLobby = players.any(
            (player) => player['id'] == playerId || player['uid'] == playerId,
          );

          if (playerInLobby) {
            final hostUid = data['hostUid'] as String?;

            if (hostUid == playerId) {
              // Player is host - delete the entire lobby
              print('Deleting lobby ${doc.id} (player was host)');
              await doc.reference.delete();
            } else {
              // Player is not host - just remove them from players list
              final updatedPlayers =
                  players
                      .where(
                        (player) =>
                            player['id'] != playerId &&
                            player['uid'] != playerId,
                      )
                      .toList();

              if (updatedPlayers.isEmpty) {
                // No players left - delete lobby
                print('Deleting empty lobby ${doc.id}');
                await doc.reference.delete();
              } else {
                // Update players list
                print('Removing player from lobby ${doc.id}');
                await doc.reference.update({'players': updatedPlayers});
              }
            }
          }
        } catch (e) {
          print('Error cleaning up lobby ${doc.id}: $e');
        }
      }

      print('Player lobby cleanup completed for: $playerId');
    } catch (e) {
      print('Error during player lobby cleanup: $e');
    }
  }
}
