import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noondaygame/widgets/discussion_phase_widget.dart';
import 'package:noondaygame/widgets/voting_phase_widget.dart';
import 'package:noondaygame/widgets/bullet_timer_widget.dart';
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
      const int totalTime = 120; // 2:00 total

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscussionPhaseWidget(
              players: testPlayers,
              remainingTime: remainingTime,
              currentUserId: 'player1',
              myRole: 'villager',
              totalTime: totalTime,
            ),
          ),
        ),
      );

      // Find the timer text
      expect(find.text('1:30'), findsOneWidget);

      // Verify the BulletTimerWidget exists and has correct values
      final bulletTimer = tester.widget<BulletTimerWidget>(
        find.byType(BulletTimerWidget),
      );

      expect(bulletTimer.remainingTime, equals(remainingTime));
      expect(bulletTimer.totalTime, equals(totalTime));
    });
    testWidgets('Voting widget displays correct remaining time', (
      WidgetTester tester,
    ) async {
      const int remainingTime = 45; // 0:45
      const int totalTime = 60; // 1:00 total

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VotingPhaseWidget(
              players: testPlayers,
              remainingTime: remainingTime,
              currentUserId: 'player1',
              myRole: 'villager',
              totalTime: totalTime,
            ),
          ),
        ),
      );

      // Find the timer text
      expect(find.text('0:45'), findsOneWidget);

      // Verify the BulletTimerWidget exists and has correct values
      final bulletTimer = tester.widget<BulletTimerWidget>(
        find.byType(BulletTimerWidget),
      );

      expect(bulletTimer.remainingTime, equals(remainingTime));
      expect(bulletTimer.totalTime, equals(totalTime));
    });
    testWidgets('Discussion widget updates timer when remainingTime changes', (
      WidgetTester tester,
    ) async {
      int remainingTime = 120; // 2:00
      const int totalTime = 120; // 2:00 total

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
                      totalTime: totalTime,
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
      const int totalTime = 90; // 1:30 total

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
                      totalTime: totalTime,
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
      const int totalTime = 120; // 2:00 total

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscussionPhaseWidget(
              players: testPlayers,
              remainingTime: 0,
              currentUserId: 'player1',
              myRole: 'villager',
              totalTime: totalTime,
            ),
          ),
        ),
      );

      expect(find.text('0:00'), findsOneWidget);

      // Verify the BulletTimerWidget exists and has correct values
      final bulletTimer = tester.widget<BulletTimerWidget>(
        find.byType(BulletTimerWidget),
      );

      expect(bulletTimer.remainingTime, equals(0));
      expect(bulletTimer.totalTime, equals(totalTime));
    });
    testWidgets('Timer color changes when time is low', (
      WidgetTester tester,
    ) async {
      // Test with low time (red color threshold)
      const int totalTime = 120; // 2:00 total

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscussionPhaseWidget(
              players: testPlayers,
              remainingTime: 15, // Less than 30 seconds
              currentUserId: 'player1',
              myRole: 'villager',
              totalTime: totalTime,
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
