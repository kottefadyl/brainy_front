import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/entry_authors.dart';
import 'package:brainy/workspace_entry_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// T53: creator and last editor in shared collections only.
BrainyCollection _collection({bool shared = true}) => BrainyCollection.fromJson({
      'id': 'c1',
      'ownerId': 'u1',
      'name': 'Maison',
      'fields': [],
      'formats': [{'id': 'f1', 'name': 'Dépense', 'color': '#FFF0F4', 'fields': [{'id': 't', 'name': 'Titre', 'kind': 'TITLE'}]}],
      'members': shared ? [{'userId': 'u2', 'email': 'b@example.test', 'name': 'Bruno Martin', 'role': 'EDITOR', 'addedAt': '2026-11-11T10:00:00Z'}] : [],
    });

BrainyEntry _entry({String? editor}) => BrainyEntry.fromJson({
      'id': 'e1',
      'formatId': 'f1',
      'createdAt': '2026-11-11T10:00:00Z',
      'updatedAt': '2026-11-11T11:00:00Z',
      'values': [{'fieldId': 't', 'value': 'Courses'}],
      'createdBy': {'userId': 'u2', 'name': 'Bruno Martin', 'hasPhoto': false},
      'updatedBy': {'userId': editor ?? 'u2', 'name': editor == null ? 'Bruno Martin' : 'Awa Diallo', 'hasPhoto': false},
    });

Future<void> _pump(WidgetTester tester, Widget child, {double width = 1280, bool dark = false}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [child])),
  ));
  await tester.pumpAndSettle();
}

Widget _row(BrainyCollection collection, BrainyEntry entry) => WorkspaceEntryRow(
      color: '#FFF0F4', title: 'Courses', formatName: 'Dépense', created: '11 nov.', onDetails: () {}, onAction: (_) {},
      authors: EntryAuthors(entry: entry, collection: collection),
    );

void main() {
  test('creator and editor are read from the API', () {
    final entry = _entry(editor: 'u1');
    expect(entry.createdBy?.name, 'Bruno Martin');
    expect(entry.updatedBy?.userId, 'u1');
    expect(isSharedCollection(_collection()), isTrue);
    expect(isSharedCollection(_collection(shared: false)), isFalse);
  });

  for (final (width, dark) in [(390.0, true), (1280.0, false)]) {
    testWidgets('a shared entry shows creator and last editor at $width px', (tester) async {
      await _pump(tester, _row(_collection(), _entry(editor: 'u1')), width: width, dark: dark);
      expect(find.byTooltip('Créée par Bruno Martin · modifiée par Awa Diallo'), findsOneWidget);
      expect(find.text('Bruno Martin'), width >= 560 ? findsOneWidget : findsNothing, reason: 'phone: photos only');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('one person only when nobody else changed the entry', (tester) async {
    await _pump(tester, _row(_collection(), _entry()));
    expect(find.byTooltip('Créée par Bruno Martin'), findsOneWidget);
    expect(find.textContaining('modifié par'), findsNothing);
  });

  testWidgets('an entry kept offline shows its author before syncing (T53/1)', (tester) async {
    const me = (userId: 'u1', name: 'Awa Diallo', hasPhoto: true);
    final offline = BrainyEntry(id: 'offline:k1', formatId: 'f1', values: const {'t': 'Courses'}, createdAt: DateTime(2026, 11, 12), updatedAt: DateTime(2026, 11, 12), offlinePending: true, createdBy: me, updatedBy: me);
    await _pump(tester, _row(_collection(), offline));
    expect(find.byTooltip('Créée par Awa Diallo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing in a private collection', (tester) async {
    await _pump(tester, _row(_collection(shared: false), _entry(editor: 'u1')));
    expect(find.text('Bruno Martin'), findsNothing);
    expect(find.byTooltip('Créée par Bruno Martin · modifiée par Awa Diallo'), findsNothing);
  });

  testWidgets('a data format card shows its owner', (tester) async {
    await _pump(tester, FormatAuthors(collection: _collection()));
    expect(find.byTooltip('Créé et modifié par Vous'), findsOneWidget);
  });
}
