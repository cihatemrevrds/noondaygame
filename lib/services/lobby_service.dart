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

      final lobbyRef = _firestore.collection('lobbies').doc(lobbyCode);

      await lobbyRef.set({
        'hostUid': hostUid,
        'hostName': hostName,
        'maxPlayers': maxPlayers,
        'createdAt': FieldValue.serverTimestamp(),
        'players': [
          {'uid': hostUid, 'name': hostName, 'isHost': true},
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
  }

  Future<void> leaveLobby(String lobbyCode, String playerId) async {
    try {
      final lobbyRef = FirebaseFirestore.instance
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());

      final doc = await lobbyRef.get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      players.removeWhere((player) => player['id'] == playerId);
      await lobbyRef.update({'players': players});
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
      players.removeWhere((player) => player['id'] == playerIdToKick);
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
    try {
      final lobbyRef = _firestore
          .collection('lobbies')
          .doc(lobbyCode.toUpperCase());
      final doc = await lobbyRef.get();

      if (!doc.exists) {
        print('Lobby not found');
        return false;
      }

      final data = doc.data()!;
      if (data['hostUid'] != hostId) {
        print('Only host can delete the lobby');
        return false;
      }

      await lobbyRef.delete();
      return true;
    } catch (e) {
      print('Delete lobby error: $e');
      return false;
    }
  }
}
