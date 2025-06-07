import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noondaygame/widgets/discussion_phase_widget.dart';
import 'package:noondaygame/widgets/voting_phase_widget.dart';
import 'package:noondaygame/models/player.dart';

void main() {
  group('Timer Synchronization Tests', () {
    final List<Player> testPlayers = [
      Player(
        id: 'player1',
        name: 'Alice',
        isLeader: true,
        isAlive: true,
        role: 'villager',
      ),
      Player(
        id: 'player2',
        name: 'Bob',
        isLeader: false,
        isAlive: true,
        role: 'werewolf',
      ),
    ];

    testWidgets('Discussion widget displays correct remaining time', (
      WidgetTester tester,
    ) async {
      const int remainingTime = 90; // 1:30

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscussionPhaseWidget(
              players: testPlayers,
              remainingTime: remainingTime,
              currentUserId: 'player1',
              myRole: 'villager',
            ),
          ),
        ),
      );

      // Find the timer text
      expect(find.text('1:30'), findsOneWidget);

      // Verify the circular progress indicator value is correctly calculated
      final circularProgress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

      // Progress should be remainingTime / 120.0 (2 minutes max)
      expect(circularProgress.value, equals(90.0 / 120.0));
    });

    testWidgets('Voting widget displays correct remaining time', (
      WidgetTester tester,
    ) async {
      const int remainingTime = 45; // 0:45

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VotingPhaseWidget(
              players: testPlayers,
              remainingTime: remainingTime,
              currentUserId: 'player1',
              myRole: 'villager',
            ),
          ),
        ),
      );

      // Find the timer text
      expect(find.text('0:45'), findsOneWidget);

      // Verify the circular progress indicator value is correctly calculated
      final circularProgress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

      // Progress should be remainingTime / 120.0 (2 minutes max)
      expect(circularProgress.value, equals(45.0 / 120.0));
    });

    testWidgets('Discussion widget updates timer when remainingTime changes', (
      WidgetTester tester,
    ) async {
      int remainingTime = 120; // 2:00

      // Create a StatefulWidget to control remainingTime updates
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    DiscussionPhaseWidget(
                      players: testPlayers,
                      remainingTime: remainingTime,
                      currentUserId: 'player1',
                      myRole: 'villager',
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          remainingTime = 60; // Update to 1:00
                        });
                      },
                      child: const Text('Update Timer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initially should show 2:00
      expect(find.text('2:00'), findsOneWidget);

      // Tap button to update timer
      await tester.tap(find.text('Update Timer'));
      await tester.pump();

      // Should now show 1:00
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('2:00'), findsNothing);
    });

    testWidgets('Voting widget updates timer when remainingTime changes', (
      WidgetTester tester,
    ) async {
      int remainingTime = 90; // 1:30

      // Create a StatefulWidget to control remainingTime updates
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    VotingPhaseWidget(
                      players: testPlayers,
                      remainingTime: remainingTime,
                      currentUserId: 'player1',
                      myRole: 'villager',
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          remainingTime = 30; // Update to 0:30
                        });
                      },
                      child: const Text('Update Timer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initially should show 1:30
      expect(find.text('1:30'), findsOneWidget);

      // Tap button to update timer
      await tester.tap(find.text('Update Timer'));
      await tester.pump();

      // Should now show 0:30
      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('1:30'), findsNothing);
    });

    testWidgets('Timer widgets handle edge cases correctly', (
      WidgetTester tester,
    ) async {
      // Test with 0 seconds remaining
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscussionPhaseWidget(
              players: testPlayers,
              remainingTime: 0,
              currentUserId: 'player1',
              myRole: 'villager',
            ),
          ),
        ),
      );

      expect(find.text('0:00'), findsOneWidget);

      // Verify progress indicator shows 0
      final circularProgress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(circularProgress.value, equals(0.0));
    });

    testWidgets('Timer color changes when time is low', (
      WidgetTester tester,
    ) async {
      // Test with low time (red color threshold)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscussionPhaseWidget(
              players: testPlayers,
              remainingTime: 15, // Less than 30 seconds
              currentUserId: 'player1',
              myRole: 'villager',
            ),
          ),
        ),
      );

      // Find the timer text widget
      final timerText = tester.widget<Text>(find.text('0:15'));

      // Should be red when time is low
      expect(timerText.style?.color, equals(Colors.red));
    });
  });
}
