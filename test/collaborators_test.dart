import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collaborators_api.dart';
import 'package:brainy/collaborators_screen.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/workspace_collection_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// T52: collaborators by link and collection sharing.
const _token = 'abcdefghijklmnopqrstuv';

class _Auth extends AuthApi {
  final calls = <(String, Map<String, dynamic>)>[];
  var people = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    calls.add((query, variables));
    final bruno = {'userId': 'u2', 'name': 'Bruno', 'email': 'bruno@example.test', 'since': '2026-11-11T10:00:00Z', 'hasPhoto': false};
    if (query.contains('collaborationInviteToken')) return {'collaborationInviteToken': _token};
    if (query.contains('collaborators{')) return {'collaborators': people};
    if (query.contains('collaborationInvite(')) return {'collaborationInvite': {'inviterName': 'Awa', 'isSelf': false, 'alreadyCollaborator': false}};
    if (query.contains('acceptCollaboration')) { people = [bruno]; return {'acceptCollaboration': bruno}; }
    if (query.contains('addCollectionMember')) return {'addCollectionMember': {'id': 'c1'}};
    if (query.contains('removeCollectionMember')) return {'removeCollectionMember': {'id': 'c1'}};
    if (query.contains('endCollaboration')) { people = []; return {'endCollaboration': true}; }
    throw StateError(query);
  }
}

Future<void> _pump(WidgetTester tester, Widget home, {double width = 390, bool dark = false, String locale = 'fr'}) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: Locale(locale),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: home,
  ));
  await tester.pumpAndSettle();
}

BrainyCollection _collection({List<Map<String, dynamic>> members = const [], Map<String, dynamic>? sharedBy}) => BrainyCollection.fromJson({
      'id': 'c1',
      'name': 'Maison',
      'fields': [],
      'formats': [{'id': 'f1', 'name': 'Dépense', 'color': '#FFF0F4', 'fields': [{'id': 't', 'name': 'Titre', 'kind': 'TITLE'}]}],
      'members': members,
      'sharedBy': sharedBy,
    });

void main() {
  test('a pasted link or a bare token gives the invitation token', () {
    expect(inviteTokenFrom('Collaborons sur Brainy : https://brainy.example/invite/$_token'), _token);
    expect(inviteTokenFrom('  $_token '), _token);
    expect(inviteTokenFrom('https://brainy.example/contribute/abc'), isNull);
    expect(collaborationLink(_token), endsWith('/invite/$_token'));
  });

  test('sharedBy is read from the API', () {
    expect(_collection().sharedBy, isNull);
    expect(_collection(sharedBy: {'userId': 'u1', 'name': 'Awa'}).sharedBy?.name, 'Awa');
  });

  for (final (width, dark) in [(390.0, false), (390.0, true), (1280.0, false), (1280.0, true)]) {
    testWidgets('link, paste, accept and end at $width px (${dark ? 'dark' : 'light'})', (tester) async {
      final auth = _Auth();
      await _pump(tester, CollaboratorsScreen(auth: auth), width: width, dark: dark);
      expect(find.textContaining('/invite/$_token'), findsOneWidget);
      expect(find.text('Aucun collaborateur pour l’instant. Envoyez votre lien à un collègue pour commencer.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Collaborons sur Brainy : http://x.test/invite/$_token');
      await tester.tap(find.text('Vérifier le lien'));
      await tester.pumpAndSettle();
      expect(find.text('Awa vous invite à collaborer.'), findsOneWidget);
      await tester.tap(find.text('Accepter la collaboration'));
      await tester.pumpAndSettle();
      expect(find.text('Bruno'), findsOneWidget);
      expect(auth.calls.any((call) => call.$1.contains('acceptCollaboration') && call.$2['token'] == _token), isTrue);
      await tester.tap(find.byTooltip('Mettre fin à la collaboration avec Bruno'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Mettre fin'));
      await tester.pumpAndSettle();
      expect(find.text('Collaboration avec Bruno terminée.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the owner shares read only, then read and write, then removes access', (tester) async {
    final auth = _Auth()..people = [{'userId': 'u2', 'name': 'Bruno', 'email': 'bruno@example.test', 'since': '2026-11-11T10:00:00Z', 'hasPhoto': false}];
    await _pump(tester, Builder(builder: (context) => Scaffold(body: Center(child: FilledButton(onPressed: () => showCollectionShareSheet(context, auth: auth, collection: _collection()), child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final (label, role) in [('Lecture seule', 'READER'), ('Lecture et écriture', 'EDITOR')]) {
      await tester.tap(find.byType(DropdownButtonFormField<BrainyCollectionRole?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      final call = auth.calls.lastWhere((item) => item.$1.contains('addCollectionMember'));
      expect(call.$2['u'], 'u2');
      expect(call.$2['r'], role);
    }
    await tester.tap(find.byType(DropdownButtonFormField<BrainyCollectionRole?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aucun accès').last);
    await tester.pumpAndSettle();
    expect(auth.calls.last.$1, contains('removeCollectionMember'));
    expect(tester.takeException(), isNull);
  });

  for (final (canWrite, label) in [(false, 'read only'), (true, 'read and write')]) {
    testWidgets('a collection shared $label hides owner actions', (tester) async {
      await _pump(tester, Scaffold(body: ListView(children: [
        WorkspaceCollectionHeader(name: 'Maison', entryCount: 1, partialEntryCount: false, formatCount: 1, onNewEntry: () {}, onInsights: () {}, onRename: () {}, onDelete: () {}, owner: false, canWrite: canWrite),
        SharedCollectionBanner(ownerName: 'Awa', canWrite: canWrite),
      ])), dark: canWrite);
      expect(find.text('Gérer'), findsNothing);
      expect(find.text('Nouvelle entrée'), canWrite ? findsOneWidget : findsNothing);
      expect(find.text('Partagée par Awa'), findsOneWidget);
      expect(find.text(canWrite ? 'Lecture et écriture' : 'Lecture seule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
