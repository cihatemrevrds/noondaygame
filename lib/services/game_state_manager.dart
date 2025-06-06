import 'package:firebase_auth/firebase_auth.dart';
import '../services/lobby_service.dart';
import '../services/game_service.dart';

class GameStateManager {
  final LobbyService _lobbyService = LobbyService();
  final GameService _gameService = GameService();

  Future<void> advancePhase(
    String lobbyCode,
    bool isHost,
    String currentPhase,
    Function() setLoading,
    Function(String) showMessage,
  ) async {
    if (!isHost) return;

    setLoading();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Gündüzse ve oylar verilmişse, sonuçlandır
      if (currentPhase == 'day') {
        await _gameService.processVotes(lobbyCode);
      }

      final result = await _gameService.advancePhase(lobbyCode, user.uid);
      if (result == null) throw Exception('Failed to advance phase');

      final newPhase = result['newPhase'] as String? ?? 'night';

      showMessage('Phase changed to ${newPhase.toUpperCase()}');
    } catch (e) {
      showMessage('Error: ${e.toString()}');
    }
  }

  Future<void> endGame(
    String lobbyCode,
    bool isHost,
    Function(String) showMessage,
  ) async {
    if (!isHost) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _lobbyService.deleteLobby(lobbyCode, user.uid);
    } catch (e) {
      showMessage('Error ending game: $e');
    }
  }

  void performEmergencyGameCleanup(String lobbyCode, bool isHost) {
    // Emergency cleanup when app is terminated during game
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && isHost) {
      // Fire and forget - delete the lobby to end the game
      _lobbyService.deleteLobby(lobbyCode, user.uid);
    }
  }

  Future<void> submitVote(
    String lobbyCode,
    String currentUserId,
    String targetId,
    Function() setLoading,
    Function(String) showMessage,
    Function(String?) setVotedPlayerId,
  ) async {
    if (targetId == currentUserId) return;

    setLoading();
    setVotedPlayerId(targetId); // Hemen UI'ı güncelle

    try {
      final success = await _gameService.submitVote(
        lobbyCode,
        currentUserId,
        targetId,
      );

      if (!success) {
        throw Exception('Failed to submit vote');
      }

      showMessage('Vote submitted');
    } catch (e) {
      showMessage('Error: ${e.toString()}');
      setVotedPlayerId(null); // Hata durumunda seçimi sıfırla
    }
  }

  Future<void> performNightAction(
    String action,
    String targetId,
    String lobbyCode,
    String currentUserId,
    Function() setLoading,
    Function(String?) setNightActionResult,
    Function(String) showMessage,
  ) async {
    setLoading();

    try {
      String? result;

      switch (action) {
        case 'doctorProtect':
          result = await _gameService.doctorProtect(
            lobbyCode,
            currentUserId,
            targetId,
          );
          break;

        case 'gunmanKill':
          result = await _gameService.gunmanKill(
            lobbyCode,
            currentUserId,
            targetId,
          );
          break;

        case 'sheriffInvestigate':
          result = await _gameService.sheriffInvestigate(
            lobbyCode,
            currentUserId,
            targetId,
          );
          break;

        case 'prostituteBlock':
          result = await _gameService.prostituteBlock(
            lobbyCode,
            currentUserId,
            targetId,
          );
          break;

        case 'peeperSpy':
          result = await _gameService.peeperSpy(
            lobbyCode,
            currentUserId,
            targetId,
          );
          break;

        case 'chieftainOrder':
          result = await _gameService.chieftainOrder(
            lobbyCode,
            currentUserId,
            targetId,
          );
          break;
      }

      if (result != null) {
        setNightActionResult(result);
        showMessage(result);
      }
    } catch (e) {
      showMessage('Error: ${e.toString()}');
    }
  }
}
