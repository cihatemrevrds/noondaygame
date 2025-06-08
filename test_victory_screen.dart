import 'package:flutter/material.dart';
import 'lib/widgets/victory_screen_widget.dart';
import 'lib/models/player.dart';

void main() {  // Test import
  const widget = VictoryScreenWidget(
    winCondition: {},
    finalPlayers: <Player>[],
    currentUserId: 'test',
    isHost: true,
    lobbyCode: 'TEST123',
  );
  print('Import test successful');
}
