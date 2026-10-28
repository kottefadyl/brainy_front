import 'package:brainy/auth_api.dart';
import 'package:brainy/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets('French sign-in and registration fit at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AuthScreen(api: AuthApi(), onAuthenticated: (_) {}),
        ),
      );
      expect(find.text('Heureux de vous revoir.'), findsOneWidget);
      await tester.ensureVisible(find.text('Créer un compte'));
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();
      expect(find.text('Faites place aux idées.'), findsOneWidget);
    });
  }
}
