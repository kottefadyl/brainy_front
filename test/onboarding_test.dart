import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// T50: welcome guide.
class _Auth extends AuthApi {
  final queries = <String>[];
  final variables = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    queries.add(query);
    this.variables.add(variables);
    if (query.contains('createCollection')) {
      final input = variables['input'] as Map<String, dynamic>;
      final format = (input['formats'] as List<dynamic>).first as Map<String, dynamic>;
      final fields = [for (final (index, field) in (format['fields'] as List<dynamic>).indexed) {...(field as Map<String, dynamic>), 'id': 'f$index'}];
      return {'createCollection': {'id': 'c1', 'name': input['name'], 'fields': fields, 'formats': [{'id': 'fmt', 'name': format['name'], 'color': format['color'], 'fields': fields}]}};
    }
    if (query.contains('createEntry')) return {'createEntry': {'id': 'e1', 'formatId': 'fmt', 'createdAt': '2026-11-11T10:00:00Z', 'updatedAt': '2026-11-11T10:00:00Z', 'values': []}};
    if (query.contains('setOnboardingCompleted')) return {'setOnboardingCompleted': {'id': 'u', 'name': 'Awa Diallo', 'email': 'a@example.test', 'profileCompleted': true, 'onboardingCompleted': variables['done']}};
    throw StateError(query);
  }
}

const _user = AppUser(id: 'u', name: 'Awa Diallo', email: 'a@example.test', profileCompleted: true);

Future<(_Auth, List<Map<String, Object?>>)> _pump(WidgetTester tester, double width, bool dark) async {
  tester.view.physicalSize = Size(width, width < 500 ? 900 : 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth();
  final finished = <Map<String, Object?>>[];
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: OnboardingScreen(user: _user, api: auth, onFinished: (user, {created = false, openTemplates = false}) => finished.add({'done': user.onboardingCompleted, 'created': created, 'templates': openTemplates})),
  ));
  await tester.pumpAndSettle();
  return (auth, finished);
}

void main() {
  for (final (width, dark) in [(390.0, false), (390.0, true), (1280.0, false), (1280.0, true)]) {
    testWidgets('five pages read without overflow at $width px (${dark ? 'dark' : 'light'})', (tester) async {
      await _pump(tester, width, dark);
      expect(find.text('Bonjour Awa, voici Brainy'), findsOneWidget);
      for (final title in ['Trois mots suffisent', 'Brainy vous aide chaque jour', 'Privées, toujours à votre main', 'Créons votre première collection']) {
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Suivant'), findsNothing);
      expect(find.textContaining('vision à long terme', findRichText: true), findsNothing);
    });
  }

  testWidgets('the last page creates a collection, a data format and a first entry', (tester) async {
    final (auth, finished) = await _pump(tester, 1280, false);
    await tester.tap(find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Page 5'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Maison'));
    await tester.tap(find.widgetWithText(ActionChip, 'Maison'));
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Dépense'));
    await tester.tap(find.widgetWithText(ActionChip, 'Dépense'));
    await tester.enterText(find.widgetWithText(TextField, 'Titre de la première entrée'), 'Pain, 500 FCFA');
    await tester.pumpAndSettle();
    expect(find.text('Maison'), findsWidgets, reason: 'the preview follows the typing');
    await tester.ensureVisible(find.text('Créer et commencer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer et commencer'));
    await tester.pumpAndSettle();
    final input = auth.variables[auth.queries.indexWhere((query) => query.contains('createCollection'))]['input'] as Map<String, dynamic>;
    expect(input['name'], 'Maison');
    final format = (input['formats'] as List<dynamic>).single as Map<String, dynamic>;
    expect(format['name'], 'Dépense');
    expect((format['fields'] as List<dynamic>).map((field) => (field as Map)['kind']), ['TITLE', 'DATE']);
    final entry = auth.variables[auth.queries.indexWhere((query) => query.contains('createEntry'))]['input'] as Map<String, dynamic>;
    expect((entry['values'] as List<dynamic>).first, containsPair('value', 'Pain, 500 FCFA'));
    expect(finished.single, {'done': true, 'created': true, 'templates': false});
  });

  testWidgets('skipping or choosing a template marks the guide as seen', (tester) async {
    final (_, finished) = await _pump(tester, 390, false);
    await tester.tap(find.text('Passer le guide'));
    await tester.pumpAndSettle();
    expect(finished.single, {'done': true, 'created': false, 'templates': false});
  });
}
