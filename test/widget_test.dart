import 'package:brainy/auth_api.dart';
import 'package:brainy/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login validates email and switches to registration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(api: AuthApi(), onAuthenticated: (_) {}),
      ),
    );

    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Make room for ideas.'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('registration fits a desktop viewport', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(api: AuthApi(), onAuthenticated: (_) {}),
      ),
    );
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Make room for ideas.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
