import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/entry_links_dialog.dart';
import 'package:brainy/analysis_chart.dart';
import 'package:brainy/insights_dialog.dart';
import 'package:brainy/starter_dialog.dart';
import 'package:brainy/unit_dialog.dart';
import 'package:brainy/workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlowAuthApi extends AuthApi {
  final templates = [
    'Start from scratch',
    'Notes and writing',
    'Saved links',
    'Task list',
    'Calendar',
    'Expenses',
    'Book',
  ];
  final collections = <Map<String, dynamic>>[];
  final entries = <Map<String, dynamic>>[];
  Map<String, dynamic>? lastAnalysisInput;
  List<Map<String, dynamic>>? analysisRows;
  String? analysisUnit;

  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables,
    {Duration timeout = const Duration(seconds: 12)}
  ) async {
    if (query.contains('collectionsList')) {
      return {'collectionsList': collections};
    }
    if (query.contains('collectionAvailableUnits')) {
      return {
        'collectionAvailableUnits': [
          {
            'id': 'm',
            'name': 'Metres',
            'symbol': 'm',
            'dimension': 'DISTANCE',
            'factor': '1',
            'version': 1,
          },
          {
            'id': 'km',
            'name': 'Kilometres',
            'symbol': 'km',
            'dimension': 'DISTANCE',
            'factor': '1000',
            'version': 1,
          },
        ],
      };
    }
    if (query.contains('collectionEntriesPage')) {
      final search = (variables['search'] as String? ?? '').toLowerCase();
      return {
        'collectionEntriesPage': {
          'entries': entries
              .where(
                (item) =>
                    item['collectionId'] == variables['id'] &&
                    (search.isEmpty ||
                        (item['values'] as List<dynamic>).any(
                          (value) => (value as Map<String, dynamic>)['value']
                              .toString()
                              .toLowerCase()
                              .contains(search),
                        )),
              )
              .toList(),
          'hasMore': false,
          'nextCursor': null,
        },
      };
    }
    if (query.contains('createEntry')) {
      final entry = {
        'id': 'entry-${entries.length}',
        'collectionId': variables['id'],
        'formatId': (variables['input'] as Map<String, dynamic>)['formatId'],
        'values': (variables['input'] as Map<String, dynamic>)['values'],
        'createdAt': '2026-10-25T10:00:00Z',
        'updatedAt': '2026-10-25T10:00:00Z',
      };
      entries.add(entry);
      return {'createEntry': entry};
    }
    if (query.contains('starterTemplates')) {
      return {
        'starterTemplates': [
          for (var index = 0; index < templates.length; index++)
            {
              'id': 'template-$index',
              'name': templates[index],
              'description': 'Editable collection',
            },
        ],
      };
    }
    if (query.contains('createCollectionFromTemplate')) {
      final collection = <String, dynamic>{
        'id': variables['templateId'],
        'name': variables['name'],
        'fields': [
          {'id': 'title', 'name': 'Title', 'kind': 'TITLE'},
        ],
        'formats': [
          {
            'id': 'format',
            'name': 'Note',
            'color': '#EEF5FF',
            'fields': [
              {'id': 'title', 'name': 'Title', 'kind': 'TITLE'},
            ],
          },
        ],
      };
      collections.add(collection);
      return {'createCollectionFromTemplate': collection};
    }
    if (query.contains('analyseCollection')) {
      lastAnalysisInput = variables['input'] as Map<String, dynamic>;
      return {
        'analyseCollection': {
          'operation': 'COUNT',
          'groupBy': 'DAY',
          'unit': analysisUnit,
          'dimension': null,
          'refreshedAt': '2026-10-25T10:00:00Z',
          'rows':
              analysisRows ??
              [
                {
                  'group': '2026-10-23',
                  'label': '2026-10-23',
                  'value': '8',
                  'count': 8,
                  'sourcesHasMore': false,
                  'sources': [],
                },
                {
                  'group': '2026-10-24',
                  'label': '2026-10-24',
                  'value': '6',
                  'count': 6,
                  'sourcesHasMore': false,
                  'sources': [],
                },
              ],
          'comparisonRows': null,
        },
      };
    }
    if (query.contains('collectionEntries')) {
      return {
        'collectionEntries': [
          _entry('first', 'First chapter'),
          _entry('scene', 'A quiet scene'),
        ],
      };
    }
    if (query.contains('collectionEntryLinks')) {
      return {
        'collectionEntryLinks': [
          {
            'id': 'link',
            'collectionId': 'book',
            'fromEntryId': 'first',
            'toEntryId': 'scene',
            'label': 'continues',
            'createdAt': '2026-10-25T10:00:00Z',
            'deletedAt': null,
          },
        ],
      };
    }
    throw StateError('Unexpected query: $query');
  }
}

Map<String, dynamic> _entry(String id, String title) => {
  'id': id,
  'formatId': 'format',
  'values': [
    {'fieldId': 'title', 'value': title},
  ],
  'createdAt': '2026-10-25T10:00:00Z',
  'updatedAt': '2026-10-25T10:00:00Z',
};

final _collection = BrainyCollection.fromJson({
  'id': 'book',
  'name': 'Book',
  'fields': [
    {'id': 'title', 'name': 'Title', 'kind': 'TITLE'},
    {'id': 'amount', 'name': 'Amount', 'kind': 'NUMBER'},
    {'id': 'date', 'name': 'Date', 'kind': 'DATE'},
  ],
  'formats': [
    {
      'id': 'format',
      'name': 'Chapter',
      'color': '#EEF5FF',
      'fields': [
        {'id': 'title', 'name': 'Title', 'kind': 'TITLE'},
        {'id': 'amount', 'name': 'Amount', 'kind': 'NUMBER'},
        {'id': 'date', 'name': 'Date', 'kind': 'DATE'},
      ],
    },
  ],
});

Future<void> _mount(
  WidgetTester tester,
  Size size,
  Widget Function(BuildContext) child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Builder(builder: child)),
    ),
  );
}

Finder _dropdown(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label,
);

Future<void> _choose(WidgetTester tester, String label, String option) async {
  final dropdown = _dropdown(label);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(option).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unit conversion stays visible before unit editing at 320 px', (
    tester,
  ) async {
    final fake = _FlowAuthApi();
    await _mount(
      tester,
      const Size(320, 820),
      (context) => TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) =>
              UnitDialog(collection: _collection, api: CollectionsApi(fake)),
        ),
        child: const Text('Open units'),
      ),
    );
    await tester.tap(find.text('Open units'));
    await tester.pumpAndSettle();
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Unit name'), findsNothing);
    await tester.tap(find.text('Units in this collection'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Unit name'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'quick chart selects a dated measure and draws a line at 320 px',
    (tester) async {
      final fake = _FlowAuthApi();
      await _mount(
        tester,
        const Size(320, 820),
        (context) => TextButton(
          onPressed: () => showInsightsDialog(
            context,
            CollectionsApi(fake),
            _collection,
            onOpenEntry: (_) async {},
          ),
          child: const Text('Open insights'),
        ),
      );
      await tester.tap(find.text('Open insights'));
      await tester.pumpAndSettle();
      expect(find.text('Saved formulas'), findsOneWidget);
      expect(find.text('Formula'), findsNothing);
      await tester.ensureVisible(find.text('Quick chart'));
      await tester.tap(find.text('Quick chart'));
      await tester.pumpAndSettle();
      expect(fake.lastAnalysisInput?['groupBy'], 'DAY');
      expect(fake.lastAnalysisInput?['operation'], 'AVERAGE');
      expect(fake.lastAnalysisInput?['measureKind'], 'SNAPSHOT');
      expect(fake.lastAnalysisInput?['fieldId'], 'amount');
      expect(fake.lastAnalysisInput?['dateFieldId'], 'date');
      expect(find.byType(CustomPaint), findsWidgets);
      final resultsTop = tester.getTopLeft(find.textContaining('Results ·')).dy;
      expect(resultsTop, inInclusiveRange(0, 820));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 1000.0]) {
    testWidgets(
      'T23 chart and source table are readable at ${width.toInt()} px',
      (tester) async {
        final fake = _FlowAuthApi();
        await _mount(
          tester,
          Size(width, 820),
          (context) => TextButton(
            onPressed: () => showInsightsDialog(
              context,
              CollectionsApi(fake),
              _collection,
              onOpenEntry: (_) async {},
            ),
            child: const Text('Open insights'),
          ),
        );
        await tester.tap(find.text('Open insights'));
        await tester.pumpAndSettle();
        await _choose(tester, 'Calculation', 'Count');
        await tester.ensureVisible(find.text('Calculate'));
        await tester.tap(find.text('Calculate'));
        await tester.pumpAndSettle();
        expect(fake.lastAnalysisInput?['operation'], 'COUNT');
        expect(find.textContaining('2026-10-23 · 8'), findsOneWidget);
        expect(find.textContaining('2026-10-24 · 6'), findsOneWidget);
        await _choose(tester, 'Display', 'Bars');
        expect(find.byType(AnalysisChart), findsOneWidget);
        await _choose(tester, 'Display', 'Line');
        expect(find.byType(AnalysisChart), findsOneWidget);
        expect(find.byKey(const ValueKey('analysis-chart-series')), findsOneWidget);
        // The chart buttons and the display selector stay in step.
        await tester.ensureVisible(find.byTooltip('Bars'));
        await tester.tap(find.byTooltip('Bars'));
        await tester.pumpAndSettle();
        expect(find.text('Bars'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('T21 advanced formula is labelled and cannot reach the simple editor', (
    tester,
  ) async {
    final collection = BrainyCollection.fromJson({
      'id': 'book',
      'name': 'Book',
      'fields': [
        {'id': 'amount', 'name': 'Amount', 'kind': 'NUMBER'},
      ],
      'formats': [
        {
          'id': 'format',
          'name': 'Chapter',
          'color': '#EEF5FF',
          'fields': [
            {'id': 'amount', 'name': 'Amount', 'kind': 'NUMBER'},
          ],
        },
      ],
      'formulas': [
        {
          'id': 'simple',
          'name': 'Doubled',
          'formatId': 'format',
          'version': 1,
          'expression': '{"kind":"operation","operator":"MULTIPLY","args":[{"kind":"field","fieldId":"amount"},{"kind":"number","value":"2"}]}',
        },
        {
          'id': 'conditional',
          'name': 'Conditional bonus',
          'formatId': 'format',
          'version': 1,
          'expression': '{"kind":"if","condition":{"kind":"comparison","operator":"GT","left":{"kind":"field","fieldId":"amount"},"right":{"kind":"number","value":"10"}},"then":{"kind":"number","value":"1"},"else":{"kind":"number","value":"0"}}',
        },
        {
          'id': 'nested',
          'name': 'Nested operation',
          'formatId': 'format',
          'version': 1,
          'expression': '{"kind":"operation","operator":"ADD","args":[{"kind":"operation","operator":"MULTIPLY","args":[{"kind":"field","fieldId":"amount"},{"kind":"number","value":"2"}]},{"kind":"number","value":"1"}]}',
        },
      ],
    });
    await _mount(
      tester,
      const Size(320, 820),
      (context) => TextButton(
        onPressed: () => showInsightsDialog(
          context,
          CollectionsApi(_FlowAuthApi()),
          collection,
          onOpenEntry: (_) async {},
        ),
        child: const Text('Open insights'),
      ),
    );
    await tester.tap(find.text('Open insights'));
    await tester.pumpAndSettle();
    final formulas = find.byType(ExpansionTile).first;
    await tester.ensureVisible(formulas);
    await tester.tap(formulas);
    await tester.pumpAndSettle();
    expect(find.text('Advanced formula (read-only)'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNWidgets(2));
    expect(find.byTooltip('Delete'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  for (final (label, id) in const [
    ('Median', 'MEDIAN'),
    ('Standard deviation', 'STDDEV'),
    ('Standard deviation (sample)', 'STDDEV_SAMPLE'),
    ('25th percentile (P25)', 'PERCENTILE_25'),
    ('75th percentile (P75)', 'PERCENTILE_75'),
    ('95th percentile (P95)', 'PERCENTILE_95'),
    ('Mode (most frequent value)', 'MODE'),
  ]) {
    testWidgets('T22 $label is sent to the API as $id', (tester) async {
      final fake = _FlowAuthApi();
      await _mount(
        tester,
        const Size(390, 820),
        (context) => TextButton(
          onPressed: () => showInsightsDialog(
            context,
            CollectionsApi(fake),
            _collection,
            onOpenEntry: (_) async {},
          ),
          child: const Text('Open insights'),
        ),
      );
      await tester.tap(find.text('Open insights'));
      await tester.pumpAndSettle();
      await _choose(tester, 'Calculation', label);
      await tester.ensureVisible(find.text('Calculate'));
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(fake.lastAnalysisInput?['operation'], id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('T23 object chart shows the object name and kilograms', (
    tester,
  ) async {
    final fake = _FlowAuthApi()
      ..analysisUnit = 'kg'
      ..analysisRows = [
        {
          'group': 'object-id',
          'label': 'Water',
          'value': '3.5',
          'count': 2,
          'sourcesHasMore': false,
          'sources': [],
        },
      ];
    await _mount(
      tester,
      const Size(320, 820),
      (context) => TextButton(
        onPressed: () => showInsightsDialog(
          context,
          CollectionsApi(fake),
          _collection,
          onOpenEntry: (_) async {},
        ),
        child: const Text('Open insights'),
      ),
    );
    await tester.tap(find.text('Open insights'));
    await tester.pumpAndSettle();
    await _choose(tester, 'Calculation', 'Count');
    await tester.ensureVisible(find.text('Calculate'));
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();
    expect(find.text('Water · 3.5 kg'), findsOneWidget);
    await _choose(tester, 'Display', 'Bars');
    expect(find.text('Key figure'), findsOneWidget);
    expect(find.text('3.5 kg'), findsOneWidget);
    expect(find.text('Water · 2 entries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'T24 all starter choices create an editable collection at 320 px',
    (tester) async {
      final fake = _FlowAuthApi();
      final created = <String>[];
      await _mount(
        tester,
        const Size(320, 820),
        (context) => TextButton(
          onPressed: () async {
            final collection = await showStarterDialog(
              context,
              CollectionsApi(fake),
            );
            if (collection != null) created.add(collection.name);
          },
          child: const Text('Open templates'),
        ),
      );
      for (final name in fake.templates) {
        await tester.tap(find.text('Open templates'));
        await tester.pumpAndSettle();
        final choice = find.text(name).last;
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create collection').last);
        await tester.pumpAndSettle();
      }
      expect(created, fake.templates);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T24 a first entry remains visible after a starter choice at 320 px',
    (tester) async {
      final fake = _FlowAuthApi();
      tester.view.physicalSize = const Size(320, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            user: const AppUser(
              id: 'user',
              name: 'Ada',
              email: 'ada@example.test',
            ),
            api: fake,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create collection').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New entry'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'My first note',
      );
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('My first note'), findsOneWidget);
      expect(fake.entries.single['collectionId'], 'template-0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('T25 linked scene can be searched and opened at 320 px', (
    tester,
  ) async {
    final fake = _FlowAuthApi();
    BrainyEntry? opened;
    await _mount(
      tester,
      const Size(320, 820),
      (context) => TextButton(
        onPressed: () async {
          opened = await showEntryLinksDialog(
            context,
            CollectionsApi(fake),
            _collection,
            BrainyEntry.fromJson(_entry('first', 'First chapter')),
          );
        },
        child: const Text('Open links'),
      ),
    );
    await tester.tap(find.text('Open links'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'quiet');
    await tester.pumpAndSettle();
    expect(find.text('A quiet scene'), findsWidgets);
    await tester.ensureVisible(find.text('A quiet scene').first);
    await tester.tap(find.text('A quiet scene').first);
    await tester.pumpAndSettle();
    expect(opened?.id, 'scene');
    expect(tester.takeException(), isNull);
  });

  testWidgets('T25 a saved URL is found through entry search at 320 px', (
    tester,
  ) async {
    String? openedUrl;
    String? copiedUrl;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    messenger.setMockMethodCallHandler(launcher, (call) async {
      if (call.method == 'launch') {
        openedUrl = (call.arguments as Map<dynamic, dynamic>)['url'] as String;
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedUrl = (call.arguments as Map<dynamic, dynamic>)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(launcher, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final fake = _FlowAuthApi();
    fake.collections.add({
      'id': 'links',
      'name': 'Saved links',
      'fields': [
        {'id': 'title', 'name': 'Title', 'kind': 'TITLE'},
        {'id': 'url', 'name': 'URL', 'kind': 'LINK'},
      ],
      'formats': [
        {
          'id': 'format',
          'name': 'Link',
          'color': '#EDF9F3',
          'fields': [
            {'id': 'title', 'name': 'Title', 'kind': 'TITLE'},
            {'id': 'url', 'name': 'URL', 'kind': 'LINK'},
          ],
        },
      ],
    });
    fake.entries.addAll([
      {
        ..._entry('link-1', 'Brainy reference'),
        'collectionId': 'links',
        'values': [
          {'fieldId': 'title', 'value': 'Brainy reference'},
          {'fieldId': 'url', 'value': 'https://example.com/brainy'},
        ],
      },
      {..._entry('link-2', 'Another page'), 'collectionId': 'links'},
    ]);
    tester.view.physicalSize = const Size(320, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          user: const AppUser(
            id: 'user',
            name: 'Ada',
            email: 'ada@example.test',
          ),
          api: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('https://example.com/brainy'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search entries'),
      'reference',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Brainy reference'), findsOneWidget);
    expect(find.text('Another page'), findsNothing);
    // Link actions live in the entry details since the compact entry rows.
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('View details')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open link'));
    await tester.pumpAndSettle();
    expect(openedUrl, 'https://example.com/brainy');
    await tester.tap(find.byTooltip('Copy link'));
    await tester.pumpAndSettle();
    expect(copiedUrl, 'https://example.com/brainy');
    expect(tester.takeException(), isNull);
  });
}
