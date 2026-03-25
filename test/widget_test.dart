// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:delay_messenger/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Conversations tab shows chat list', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DTNMessengerApp());

    // Should show the default chat name in the app bar dropdown.
    expect(find.text('Emergency Contact'), findsOneWidget);

    // Switch to the Conversations tab.
    await tester.tap(find.text('Conversations'));
    await tester.pumpAndSettle();

    // Should show at least one conversation item in the list.
    expect(find.text('Field Team Alpha'), findsOneWidget);
  });
}
