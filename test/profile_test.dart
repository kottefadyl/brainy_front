import 'package:brainy/auth_api.dart';
import 'package:brainy/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProfileApi extends AuthApi {
  Map<String, dynamic>? submitted;

  @override
  Future<AppUser> updateProfile({
    required String name,
    required String profession,
    required String job,
    required String fieldOfStudy,
    required List<String> interests,
    required List<String> hobbies,
  }) async {
    submitted = {
      'name': name,
      'profession': profession,
      'job': job,
      'fieldOfStudy': fieldOfStudy,
      'interests': interests,
      'hobbies': hobbies,
    };
    return AppUser(
      id: 'user-1',
      name: name,
      email: 'ada@example.test',
      profession: profession,
      job: job,
      fieldOfStudy: fieldOfStudy,
      interests: interests,
      hobbies: hobbies,
      profileCompleted: true,
    );
  }
}

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('profile setup collects matching details at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = FakeProfileApi();
      AppUser? saved;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ProfileScreen(
            user: const AppUser(
              id: 'user-1',
              name: 'Ada',
              email: 'ada@example.test',
            ),
            api: api,
            onSaved: (user) => saved = user,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Profession · Facultatif'),
        'Designer',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Emploi ou poste actuel · Facultatif'),
        'Product designer',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Domaine d’études · Facultatif'),
        'Art',
      );
      final interestField = find.widgetWithText(TextField, 'Centres d’intérêt');
      await Scrollable.ensureVisible(
        tester.element(interestField),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.enterText(interestField, 'Design, Books');
      final hobbyField = find.widgetWithText(TextField, 'Loisirs');
      await Scrollable.ensureVisible(
        tester.element(hobbyField),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.enterText(hobbyField, 'Drawing');
      final submit = find.text('Continuer vers l’espace');
      await Scrollable.ensureVisible(tester.element(submit), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.submitted?['interests'], ['Design', 'Books']);
      expect(api.submitted?['hobbies'], ['Drawing']);
      expect(saved?.profileCompleted, true);
      expect(tester.takeException(), isNull);
    });
  }
}
