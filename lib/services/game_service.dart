// filepath: c:\Users\victus\VsCodeCalisma\noondaygame\lib\services\game_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/role.dart';

class GameService {
  // Bölgenize göre URL'i değiştirin - örneğin, 'us-central1-noondaygame.cloudfunctions.net'
  final String _baseUrl = 'https://us-central1-noondaygame.cloudfunctions.net';

  // Oyunu başlat
  Future<bool> startGame(String lobbyCode, String hostId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/startGame'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lobbyCode': lobbyCode,
          'hostId': hostId,
        }),
      );

      if (response.statusCode == 200) {
        print('Game started successfully');
        return true;
      } else {
        print('Error starting game: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception during startGame: $e');
      return false;
    }
  }

  // Oyun fazını ilerlet (gündüz/gece)
  Future<Map<String, dynamic>?> advancePhase(String lobbyCode, String hostId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/advancePhase'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lobbyCode': lobbyCode,
          'hostId': hostId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error advancing phase: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception during advancePhase: $e');
      return null;
    }
  }

  // Oy gönder
  Future<bool> submitVote(String lobbyCode, String voterId, String targetId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/submitVote'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lobbyCode': lobbyCode,
          'voterId': voterId,
          'targetId': targetId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error submitting vote: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception during submitVote: $e');
      return false;
    }
  }

  // Oyları işle ve sonucu döndür
  Future<Map<String, dynamic>?> processVotes(String lobbyCode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/processVotes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'lobbyCode': lobbyCode}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error processing votes: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception during processVotes: $e');
      return null;
    }
  }

  // Oyun ayarlarını güncelle
  Future<bool> updateSettings(String lobbyCode, String hostId, Map<String, dynamic> settings) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/updateSettings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lobbyCode': lobbyCode,
          'hostId': hostId,
          'settings': settings,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error updating settings: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception during updateSettings: $e');
      return false;
    }
  }

  // Rol ayarlarını güncelle (özel fonksiyon)
  Future<bool> updateRoleSettings(String lobbyCode, String hostId, List<Role> roles) async {
    final Map<String, int> roleSettings = {};
    
    // Role listesini map'e çevir
    for (final role in roles) {
      if (role.count > 0) {
        roleSettings[role.name] = role.count;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/updateSettings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lobbyCode': lobbyCode,
          'hostId': hostId,
          'settings': {'roles': roleSettings},
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error updating role settings: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception during updateRoleSettings: $e');
      return false;
    }
  }
}