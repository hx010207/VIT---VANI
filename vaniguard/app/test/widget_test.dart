// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaniguard/main.dart';

void main() {
  testWidgets('VaniGuardApp initial frame test', (WidgetTester tester) async {
    // Build our app and trigger the initial frame.
    await tester.pumpWidget(const VaniGuardApp());

    // Advance tester through the initial fade-in animation
    await tester.pump(const Duration(milliseconds: 500));

    // Verify MaterialApp widget is mounted.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify VaniGuard branding logo asset is rendered on launch.
    expect(
      find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName ==
              'assets/branding/vaniguard_logo.png'),
      findsOneWidget,
    );
  });
}
