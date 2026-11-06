import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthApi extends AuthApi {
  final List<Map<String, dynamic>> collections = [];
  final List<Map<String, dynamic>> entries = [];

  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (query.contains('collectionsList')) {
      return {'collectionsList': collections};
    }
    if (query.contains('collectionEntriesPage')) {
      final first = variables['first'] as int? ?? 30;
      final after = int.tryParse(variables['after'] as String? ?? '') ?? 0;
      final formatId = variables['formatId'] as String?;
      final search = (variables['search'] as String? ?? '').toLowerCase();
      final matching = entries
          .where(
            (entry) =>
                (formatId == null || entry['formatId'] == formatId) &&
                (search.isEmpty ||
                    (entry['values'] as List<dynamic>).any(
                      (value) => (value as Map<String, dynamic>)['value']
                          .toString()
                          .toLowerCase()
                          .contains(search),
                    )),
          )
          .toList();
      final page = matching.skip(after).take(first).toList();
      final next = after + page.length;
      return {
        'collectionEntriesPage': {
          'entries': page,
          'hasMore': next < matching.length,
          'nextCursor': next < matching.length ? '$next' : null,
        },
      };
    }
    if (query.contains('collectionEntries')) {
      return {'collectionEntries': entries};
    }
    if (query.contains('createCollection')) {
      final input = variables['input'] as Map<String, dynamic>;
      final requestedFormats = input['formats'] as List<dynamic>;
      final formats = <Map<String, dynamic>>[];
      for (
        var formatIndex = 0;
        formatIndex < requestedFormats.length;
        formatIndex++
      ) {
        final requested = requestedFormats[formatIndex] as Map<String, dynamic>;
        final fields = requested['fields'] as List<dynamic>;
        formats.add({
          'id': 'format-$formatIndex',
          'name': requested['name'],
          'color': requested['color'],
          'version': 1,
          'fields': [
            for (var i = 0; i < fields.length; i++)
              {
                'id': 'field-$formatIndex-$i',
                'name': (fields[i] as Map<String, dynamic>)['name'],
                'kind': fields[i]['kind'],
                'unit': fields[i]['unit'],
                'options': fields[i]['options'],
              },
          ],
        });
      }
      final collection = {
        'id': 'collection-1',
        'name': input['name'],
        'fields': formats.first['fields'],
        'formats': formats,
      };
      collections.add(collection);
      return {'createCollection': collection};
    }
    if (query.contains('addCollectionFormat')) {
      final input = variables['input'] as Map<String, dynamic>;
      final collection = collections.singleWhere(
        (item) => item['id'] == variables['id'],
      );
      final formats = collection['formats'] as List<dynamic>;
      final fields = input['fields'] as List<dynamic>;
      formats.add({
        'id': 'format-${formats.length}',
        'name': input['name'],
        'color': input['color'],
        'version': 1,
        'fields': [
          for (var i = 0; i < fields.length; i++)
            {
              'id': 'field-${formats.length}-$i',
              'name': (fields[i] as Map<String, dynamic>)['name'],
              'kind': fields[i]['kind'],
              'unit': fields[i]['unit'],
              'options': fields[i]['options'],
            },
        ],
      });
      return {'addCollectionFormat': collection};
    }
    if (query.contains('setCollectionFormatColor')) {
      final collection = collections.singleWhere(
        (item) => item['id'] == variables['collectionId'],
      );
      final format = (collection['formats'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere((item) => item['id'] == variables['formatId']);
      format['color'] = variables['color'];
      return {'setCollectionFormatColor': collection};
    }
    if (query.contains('collectionFormatImpact')) {
      final formatId = variables['formatId'];
      final matching = entries
          .where((entry) => entry['formatId'] == formatId)
          .toList();
      return {
        'collectionFormatImpact': {
          'entryCount': matching.length,
          'populatedFieldIds': [
            for (final entry in matching)
              for (final value in entry['values'] as List<dynamic>)
                value['fieldId'],
          ],
        },
      };
    }
    if (query.contains('updateCollectionFormat')) {
      final collection = collections.singleWhere(
        (item) => item['id'] == variables['collectionId'],
      );
      final format = (collection['formats'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere((item) => item['id'] == variables['formatId']);
      final input = variables['input'] as Map<String, dynamic>;
      format['name'] = input['name'];
      format['version'] = (format['version'] as int) + 1;
      format['fields'] = [
        for (var i = 0; i < (input['fields'] as List<dynamic>).length; i++)
          {
            ...((input['fields'] as List<dynamic>)[i] as Map<String, dynamic>),
            'id':
                ((input['fields'] as List<dynamic>)[i]
                    as Map<String, dynamic>)['id'] ??
                'new-$i',
          },
      ];
      return {'updateCollectionFormat': collection};
    }
    if (query.contains('createEntry')) {
      final values = (variables['input'] as Map<String, dynamic>)['values'];
      final entry = {
        'id': 'entry-1',
        'formatId': (variables['input'] as Map<String, dynamic>)['formatId'],
        'values': values,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      entries.add(entry);
      return {'createEntry': entry};
    }
    throw StateError('Unexpected query: $query');
  }
}

ScrollableState dialogScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );

Future<void> chooseFormatColor(
  WidgetTester tester,
  int index, {
  String label = 'Color',
}) async {
  final swatch = find.byTooltip('$label $index');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (swatch.evaluate().isEmpty) {
    dialogScroll(tester).position.jumpTo(180);
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(swatch), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: swatch, matching: find.byType(InkWell)));
  await tester.pumpAndSettle();
  if (tester.view.physicalSize.width < 500) {
    final scroll = dialogScroll(tester).position;
    scroll.jumpTo(scroll.maxScrollExtent < 220 ? scroll.maxScrollExtent : 220);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('entry pages replace the displayed entries', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _FakeAuthApi();
    api.collections.add({
      'id': 'journal',
      'name': 'Journal',
      'fields': [
        {'id': 'title', 'name': 'Title', 'kind': 'TITLE', 'unit': null},
      ],
    });
    api.entries.addAll(List.generate(31, (index) => {
      'id': 'entry-$index',
      'values': [{'fieldId': 'title', 'value': 'Entry $index'}],
      'createdAt': '2026-10-20T12:23:00.000Z',
      'updatedAt': '2026-10-20T12:23:00.000Z',
    }));
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(
      user: const AppUser(id: 'user-1', name: 'Ada', email: 'ada@example.test'),
      api: api,
      onSignOut: () async {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Entry 0'), findsOneWidget);
    expect(find.text('Entry 30'), findsNothing);
    tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Next page')).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Entry 0'), findsNothing);
    expect(find.text('Entry 30'), findsOneWidget);
    tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Previous page')).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Entry 0'), findsOneWidget);
    expect(find.text('Entry 30'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry shows its creation date and copies every field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String;
          }
          return null;
        });

    final api = _FakeAuthApi();
    api.collections.add({
      'id': 'journal',
      'name': 'Journal',
      'fields': [
        {'id': 'title', 'name': 'Title', 'kind': 'TITLE', 'unit': null},
        {'id': 'distance', 'name': 'Distance', 'kind': 'NUMBER', 'unit': 'km'},
        {'id': 'notes', 'name': 'Notes', 'kind': 'TEXT', 'unit': null},
      ],
    });
    api.entries.add({
      'id': 'entry-1',
      'values': [
        {'fieldId': 'title', 'value': 'Morning walk'},
        {'fieldId': 'distance', 'value': '12.5'},
        {'fieldId': 'notes', 'value': 'Fresh air\nBlue sky'},
      ],
      'createdAt': '2026-10-20T12:23:00.000Z',
      'updatedAt': '2026-10-21T12:23:00.000Z',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          user: const AppUser(
            id: 'user-1',
            name: 'Ada',
            email: 'ada@example.test',
          ),
          api: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Created'), findsOneWidget);
    expect(find.textContaining('10/20/2026'), findsOneWidget);
    expect(find.textContaining('10/21/2026'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('View details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('October 20, 2026'), findsOneWidget);
    expect(find.textContaining('October 21, 2026'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('12.5 km')), findsOneWidget);
    expect(find.text('Fresh air\nBlue sky'), findsOneWidget);
    await tester.tap(find.text('Copy entry'));
    await tester.pumpAndSettle();
    expect(
      copiedText,
      'Morning walk\nDistance: 12.5 km\nNotes: Fresh air\nBlue sky',
    );
    expect(find.text('Copied to clipboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets('creates a single-field collection and entry at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakeAuthApi();
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            user: const AppUser(
              id: 'user-1',
              name: 'Ada',
              email: 'ada@example.test',
            ),
            api: api,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create manually'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Collection name'),
        'Journal',
      );
      await chooseFormatColor(tester, 1);
      await tester.tap(find.text('Create collection').last);
      await tester.pumpAndSettle();

      expect(api.collections.single['name'], 'Journal');
      expect((api.collections.single['formats'] as List<dynamic>).length, 1);
      expect((api.collections.single['fields'] as List<dynamic>).length, 1);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('New entry'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'My first thought',
      );
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('My first thought'), findsOneWidget);
      expect(api.entries.length, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('French mobile flow saves a number with kilometres', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _FakeAuthApi();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WorkspaceScreen(
          user: const AppUser(
            id: 'user-1',
            name: 'Ada',
            email: 'ada@example.test',
          ),
          api: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer manuellement'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nom de la collection'),
      'Voyages',
    );
    await chooseFormatColor(tester, 1, label: 'Couleur');
    await tester.enterText(
      find.widgetWithText(TextField, 'Champ 1'),
      'Distance',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await Scrollable.ensureVisible(
      tester.element(
        find.byType(DropdownButtonFormField<BrainyFieldKind>).first,
      ),
      alignment: 0.4,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<BrainyFieldKind>).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nombre').last);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Sans unité')),
      alignment: 0.3,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sans unité'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Kilomètres').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer la collection').last);
    await tester.pumpAndSettle();

    final fields = api.collections.single['fields'] as List<dynamic>;
    expect((fields.first as Map<String, dynamic>)['unit'], 'km');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Nouvelle entrée'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Distance'), '12,5');
    await tester.tap(find.text('Enregistrer l’entrée'));
    await tester.pumpAndSettle();
    expect(
      (api.entries.single['values'] as List<dynamic>).single['value'],
      '12.5',
    );
    expect(find.text('12,5 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop collection accepts a custom number unit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _FakeAuthApi();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          user: const AppUser(
            id: 'user-1',
            name: 'Ada',
            email: 'ada@example.test',
          ),
          api: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create manually'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Collection name'),
      'Measurements',
    );
    await chooseFormatColor(tester, 1);
    await tester.enterText(find.widgetWithText(TextField, 'Field 1'), 'Speed');
    await tester.tap(
      find.byType(DropdownButtonFormField<BrainyFieldKind>).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Number').last);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(find.text('No unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No unit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom unit').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Custom unit'),
      'm/s²',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    dialogScroll(tester).position
        .jumpTo(dialogScroll(tester).position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add field'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Field 2'), 'Notes');
    await tester.tap(find.text('Create collection').last);
    await tester.pumpAndSettle();
    final fields = api.collections.single['fields'] as List<dynamic>;
    expect(fields.length, 2);
    expect(fields.first['unit'], 'm/s²');
    expect(fields.last['kind'], 'TEXT');
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets('adds a second format and saves an entry in it at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakeAuthApi();
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            user: const AppUser(
              id: 'user-1',
              name: 'Ada',
              email: 'ada@example.test',
            ),
            api: api,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create manually'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Collection name'),
        'Thoughts',
      );
      await chooseFormatColor(tester, 1);
      await tester.tap(find.text('Create collection').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add data format'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add data format'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Field 1'),
        'Quote',
      );
      await chooseFormatColor(tester, 2);
      await tester.tap(find.text('Add data format').last);
      await tester.pumpAndSettle();

      final formats = api.collections.single['formats'] as List<dynamic>;
      expect(formats.length, 2);
      expect(formats[0]['color'], isNot(formats[1]['color']));
      await tester.ensureVisible(find.text('New entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Data format 2').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextField, 'Quote'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Quote'),
        'A second shape of thought',
      );
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(api.entries.single['formatId'], 'format-1');
      expect(find.text('A second shape of thought'), findsOneWidget);
      final recolor = find.byTooltip('Data format actions').last;
      await tester.ensureVisible(recolor);
      await tester.pumpAndSettle();
      await tester.tap(recolor);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change color').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Color 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(
        (api.collections.single['formats'] as List<dynamic>)[1]['color'],
        '#FFF5EB',
      );
      expect(api.entries.single['formatId'], 'format-1');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('edits a used data format without losing its entry at 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = _FakeAuthApi();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          user: const AppUser(
            id: 'user-1',
            name: 'Ada',
            email: 'ada@example.test',
          ),
          api: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create manually'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Collection name'),
      'Journal',
    );
    await chooseFormatColor(tester, 1);
    await tester.tap(find.text('Create collection').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New entry'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'First note',
    );
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    final editButton = find.byTooltip('Data format actions').first;
    await tester.ensureVisible(editButton);
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit data format').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Entries using this data format: 1'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Data format name'),
      'Journal notes',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Field 1'),
      'Heading',
    );
    dialogScroll(tester).position
        .jumpTo(dialogScroll(tester).position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add field'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Field 2'),
      'Details',
    );
    dialogScroll(tester).position
        .jumpTo(dialogScroll(tester).position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final format =
        ((api.collections.single['formats'] as List<dynamic>).first
            as Map<String, dynamic>);
    expect(format['name'], 'Journal notes');
    expect((format['fields'] as List<dynamic>).length, 2);
    expect((format['fields'] as List<dynamic>).first['id'], 'field-0-0');
    expect(find.text('First note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
