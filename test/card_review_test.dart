import 'package:brainy/flip_card.dart';
import 'package:brainy/link_media.dart';
import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/card_review_screen.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// T56: two-sided cards — front first, turn, answer, a forgotten card comes back once, summary.
const _format = BrainyFormat(id: 'card', name: 'Carte', color: '#F4F0FF', fields: [
  BrainyField(id: 'word', name: 'Mot ou expression', kind: BrainyFieldKind.title, face: 'FRONT'),
  BrainyField(id: 'formality', name: 'Registre', kind: BrainyFieldKind.select, options: ['Courant', 'Soutenu'], face: 'FRONT'),
  BrainyField(id: 'definition', name: 'Définition', kind: BrainyFieldKind.longText, face: 'BACK'),
  BrainyField(id: 'example', name: 'Exemple', kind: BrainyFieldKind.text),
]);
const _collection = BrainyCollection(id: 'c', name: 'Espagnol', ownerId: 'me', fields: [], formats: [_format], templateId: 'cards');

Map<String, dynamic> _card(String id, String word, String definition) => {
      'entry': {'id': id, 'formatId': 'card', 'createdAt': '2026-11-16T08:00:00Z', 'updatedAt': '2026-11-16T08:00:00Z', 'values': [{'fieldId': 'word', 'value': word}, {'fieldId': 'formality', 'value': 'Courant'}, {'fieldId': 'definition', 'value': definition}]},
      'preview': {'again': 10, 'hard': 1440, 'good': 1440, 'easy': 5760},
    };

Map<String, dynamic> _stats({int? goal, int? newLimit, int newCards = 0}) => {
      'total': 2, 'fresh': 1, 'learning': 1, 'mature': 0, 'reviewed7': 3, 'reviewed30': 3, 'successRate30': 2 / 3,
      'days': [for (var i = 29; i >= 0; i--) {'day': DateTime.utc(2026, 11, 18).subtract(Duration(days: i)).toIso8601String().substring(0, 10), 'answers': i == 0 ? 3 : 0, 'remembered': i == 0 ? 2 : 0}],
      'forecast': [0, 1, 0, 0, 0, 0, 0],
      'hardest': [{'entryId': 'e2', 'title': 'gracias', 'forgotten': 1}],
      'today': {'reviewed': 2, 'newCards': newCards, 'goal': goal, 'newLimit': newLimit, 'streak': 4},
    };

class _Auth extends AuthApi {
  _Auth({this.stats});
  final Map<String, dynamic>? stats;
  final grades = <(String, String)>[];
  final goals = <(Object?, Object?)>[];
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    if (query.contains('cardDecks')) return {'cardDecks': [{'formatId': 'card', 'total': 2, 'due': 0, 'fresh': 2}]};
    if (query.contains('cardReviewSession')) return {'cardReviewSession': [_card('e1', 'hola', 'bonjour'), _card('e2', 'gracias', 'merci')]};
    if (query.contains('cardStats')) return {'cardStats': stats ?? _stats()};
    if (query.contains('setCardGoal')) { goals.add((variables['r'], variables['n'])); return {'setCardGoal': {'reviewsPerDay': variables['r']}}; }
    if (query.contains('gradeCard')) { grades.add((variables['e'] as String, variables['g'] as String)); return {'gradeCard': {'entryId': variables['e']}}; }
    throw StateError(query);
  }
}

Future<void> _pump(WidgetTester tester, Widget child, {required double width, required bool dark}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: child,
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('faces, links and interval hints', () {
    expect(cardFaceOf(BrainyFieldKind.title, null), 'FRONT');
    expect(cardFaceOf(BrainyFieldKind.text, null), 'BACK');
    expect(cardFaceOf(BrainyFieldKind.text, 'FRONT'), 'FRONT');
    expect(linkMediaKind('https://example.com/cat.JPG'), LinkMediaKind.image);
    expect(linkMediaKind('https://encrypted-tbn0.gstatic.com/images?q=tbn:abc&s=10'), LinkMediaKind.image);
    expect(linkMediaKind('https://example.com/hola.mp3?x=1'), LinkMediaKind.audio);
    expect(linkMediaKind('https://example.com/clip.mp4'), LinkMediaKind.video);
    expect(linkMediaKind('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), LinkMediaKind.youtube);
    expect(youtubeId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    expect(linkMediaKind('https://example.com/page'), isNull);
    expect([intervalLabel(10, false), intervalLabel(1440, true), intervalLabel(5760, false), intervalLabel(43200, true)], ['10 min', '1 j', '4 d', '1 mois']);
    expect(isFlashCards(_collection), isTrue);
  });

  for (final (width, dark) in [(390.0, false), (1280.0, true)]) {
    testWidgets('a review at $width px: front, turn, answers, the forgotten card again, summary', (tester) async {
      final auth = _Auth();
      await _pump(tester, CardReviewScreen(api: CollectionsApi(auth), collection: _collection, owner: true), width: width, dark: dark);
      expect(find.text('0 à revoir aujourd’hui · 2 nouvelle(s) · 2 au total'), findsOneWidget);
      await tester.tap(find.text('Commencer (2)'));
      await tester.pumpAndSettle();
      expect(find.text('hola'), findsOneWidget);
      expect(find.text('Courant'), findsOneWidget);
      expect(find.text('bonjour'), findsNothing, reason: 'the back stays hidden until the card is turned');
      await tester.tap(find.text('Retourner la carte'));
      await tester.pumpAndSettle();
      expect(find.text('bonjour'), findsOneWidget);
      bool backShown() => tester.widget<Visibility>(find.ancestor(of: find.text('bonjour'), matching: find.byType(Visibility)).first).visible;
      expect(backShown(), isTrue, reason: 'the card has turned over to its back');
      await tester.tap(find.byType(FlipCard));
      await tester.pumpAndSettle();
      expect(backShown(), isFalse, reason: 'a tap turns the card back to its front');
      await tester.tap(find.byType(FlipCard));
      await tester.pumpAndSettle();
      expect(backShown(), isTrue);
      expect(find.text('10 min'), findsOneWidget);
      await tester.tap(find.text('À revoir'));
      await tester.pumpAndSettle();
      expect(find.text('Carte 2 sur 3'), findsOneWidget, reason: 'a forgotten card comes back at the end');
      await tester.tap(find.text('Retourner la carte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bien'));
      await tester.pumpAndSettle();
      expect(find.text('hola'), findsOneWidget);
      await tester.tap(find.text('Retourner la carte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facile'));
      await tester.pumpAndSettle();
      expect(find.text('Révision terminée'), findsOneWidget);
      expect(find.text('2 bien su(s) · 0 difficile(s) · 1 à revoir'), findsOneWidget);
      expect(auth.grades, [('e1', 'AGAIN'), ('e2', 'GOOD'), ('e1', 'EASY')]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the banner shows what is due and opens the review', (tester) async {
    var started = false;
    await _pump(tester, Scaffold(body: CardReviewBanner(api: CollectionsApi(_Auth()), collection: _collection, onStart: () => started = true)), width: 390, dark: false);
    expect(find.text('0 à revoir aujourd’hui · 2 nouvelle(s) · 2 au total'), findsOneWidget);
    await tester.tap(find.text('Réviser'));
    expect(started, isTrue);
  });

  testWidgets('T57: progress, goal and the daily limit of new cards', (tester) async {
    // Goal 5 a day, at most 1 new card a day, already used today: only the due cards are left (none).
    final auth = _Auth(stats: _stats(goal: 5, newLimit: 1, newCards: 1));
    await _pump(tester, CardReviewScreen(api: CollectionsApi(auth), collection: _collection, owner: true), width: 390, dark: true);
    expect(find.text('Rien à revoir pour l’instant'), findsOneWidget, reason: 'the new-card limit of today is reached');
    await tester.scrollUntilVisible(find.text('Mes progrès'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('2 / 5 aujourd’hui'), findsOneWidget);
    expect(find.text('4 jours de suite'), findsOneWidget);
    expect(find.text('67 %'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Enregistrer l’objectif'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('gracias'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('card-goal-reviews')), '20');
    await tester.enterText(find.byKey(const ValueKey('card-goal-new')), '');
    await tester.tap(find.text('Enregistrer l’objectif'));
    await tester.pumpAndSettle();
    expect(auth.goals, [(20, null)]);
    expect(find.text('Objectif enregistré.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T57: the banner shows today’s goal and the streak', (tester) async {
    await _pump(tester, Scaffold(body: CardReviewBanner(api: CollectionsApi(_Auth(stats: _stats(goal: 5))), collection: _collection, onStart: () {})), width: 390, dark: false);
    expect(find.text('2 / 5 aujourd’hui'), findsOneWidget);
    expect(find.text('4 jours de suite'), findsOneWidget);
  });
}
