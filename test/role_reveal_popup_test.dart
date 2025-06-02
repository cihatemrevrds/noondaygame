import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:noondaygame/widgets/role_reveal_popup.dart';

void main() {
  testWidgets('RoleRevealPopup can be instantiated', (
    WidgetTester tester,
  ) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoleRevealPopup(
            roleName: 'Doctor',
            onComplete: () {
              completed = true;
            },
          ),
        ),
      ),
    );

    expect(find.byType(RoleRevealPopup), findsOneWidget);
    expect(find.text('YOUR ROLE'), findsOneWidget);
  });
}
