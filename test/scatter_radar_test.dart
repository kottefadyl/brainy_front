import 'dart:convert';
import 'dart:math' as math;

import 'package:brainy/analysis_radar_chart.dart';
import 'package:brainy/analysis_scatter_chart.dart';
import 'package:brainy/auth_api.dart';
import 'package:brainy/chart_export.dart';
import 'package:brainy/chart_scatter_radar.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ScatterPoint _p(double x, double y) => ScatterPoint(entryId: '$x', x: x, y: y, label: '');
Map<String, dynamic> _row(String group, String value) => {'group': group, 'label': group, 'value': value, 'count': 1, 'sources': <Map<String, dynamic>>[], 'sourcesHasMore': false};

const _format = BrainyFormat(id: 'f', name: 'Séance', color: '#F4F0FF', fields: [
  BrainyField(id: 't', name: 'Titre', kind: BrainyFieldKind.title),
  BrainyField(id: 'd', name: 'Distance', kind: BrainyFieldKind.number, unit: 'km'),
  BrainyField(id: 'c', name: 'Calories', kind: BrainyFieldKind.number),
]);
const _collection = BrainyCollection(id: 'col', name: 'Sport', fields: [], formats: [_format]);

/// 30 sessions: calories follow distance, so the link is strong and positive. Two pages of entries.
class _Auth extends AuthApi {
  int pages = 0;
  final firsts = <Object?>[];
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    if (!query.contains('collectionEntriesPage')) throw StateError('Unexpected query');
    pages++;
    firsts.add(variables['first']);
    final start = variables['after'] == null ? 0 : 20;
    final end = start == 0 ? 20 : 31;
    return {
      'collectionEntriesPage': {
        'entries': [
          for (var index = start; index < end; index++)
            {
              'id': 'e$index', 'formatId': 'f', 'createdAt': '2026-11-01T10:00:00Z', 'updatedAt': '2026-11-01T10:00:00Z',
              'values': [
                {'fieldId': 't', 'value': 'Séance ${index + 1}'},
                if (index != 30) {'fieldId': 'd', 'value': '${2 + (index % 10) * 1.5}'},
                {'fieldId': 'c', 'value': '${((2 + (index % 10) * 1.5) * 62 + (index % 4) * 25).round()}'},
              ],
            },
        ],
        'nextCursor': start == 0 ? 'p2' : null,
        'hasMore': start == 0,
      },
    };
  }
}

Future<void> _pumpWide(WidgetTester tester, Widget child, {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(12), child: child)))));
  await tester.pumpAndSettle();
}

void main() {
  group('logic, as on the web', () {
    test('a perfect line gives r = 1 and its slope', () {
      final line = [_p(1, 3), _p(2, 5), _p(3, 7), _p(4, 9)];
      expect(pearson(line), 1);
      expect(linearFit(line), (slope: 2.0, intercept: 1.0));
      expect(pearson([for (final point in line) _p(point.x, -point.y)]), -1);
    });
    test('r of a known sample, and no r without variation', () {
      final noisy = [_p(1, 2), _p(2, 1), _p(3, 4), _p(4, 3), _p(5, 6)];
      expect(pearson(noisy), closeTo(10 / math.sqrt(148), 1e-9));
      expect(pearson([_p(1, 2), _p(2, 2), _p(3, 2)]), isNull);
      expect(pearson([_p(1, 2), _p(2, 3)]), isNull, reason: 'fewer than 3 points');
      expect(linearFit([_p(2, 1), _p(2, 5)]), isNull);
    });
    test('the link is told in plain words in both languages', () {
      expect(correlationWords(0.85, french: true), 'Lien fort : quand l’un augmente, l’autre augmente aussi.');
      expect(correlationWords(-0.5, french: false), 'Moderate link: when one rises, the other tends to fall.');
      expect(correlationWords(0.1, french: true), contains('faible ou absent'));
    });
    test('radar axes and the conditions to offer it', () {
      final top = radarPoint(0, 4, 1, 100, 100, 50);
      expect(top.x, closeTo(100, 1e-9));
      expect(top.y, closeTo(50, 1e-9));
      final right = radarPoint(1, 4, 0.5, 100, 100, 50);
      expect(right.x, closeTo(125, 1e-9));
      expect(canRadar([1, 2, 3], 'CATEGORY'), isTrue);
      expect(canRadar([1, 2], 'CATEGORY'), isFalse);
      expect(canRadar(List.filled(13, 1), 'OBJECT'), isFalse);
      expect(canRadar([1, -2, 3], 'CATEGORY'), isFalse);
      expect(canRadar([1, 2, 3], 'MONTH'), isFalse);
    });
    test('points skip missing values and the CSV cannot run a formula', () {
      BrainyEntry entry(String id, String x, String y) => BrainyEntry(id: id, values: {'x': x, 'y': y, 't': '=cmd()'}, createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026));
      final data = scatterPoints([entry('1', '1.5', '-2'), entry('2', '', '3'), entry('3', 'abc', '3')], 'x', 'y', labelFieldId: 't');
      expect(data.points.length, 1);
      expect(data.skipped, 2);
      expect(scatterCsv(data.points, 'Distance', 'Calories', french: true).split('\r\n'), ['"Entrée","Distance","Calories"', '"\'=cmd()",1.5,-2']);
    });
    test('axes hug the data instead of starting at zero', () {
      final scale = tightScale([79.2, 81.7]);
      expect(scale.low, greaterThan(70));
      expect(scale.high, greaterThanOrEqualTo(81.7));
    });
  });

  testWidgets('the scatter plot reads pages of 100, draws every point and describes the link', (tester) async {
    final auth = _Auth();
    final opened = <String>[];
    await _pumpWide(tester, AnalysisScatterChart(api: CollectionsApi(auth), collection: _collection, format: _format, french: false, onOpenEntry: (id) async => opened.add(id)));
    await tester.tap(find.byKey(const Key('scatter-draw')));
    await tester.pumpAndSettle();
    expect(auth.pages, 2, reason: 'all pages are read');
    expect(auth.firsts, [100, 100]);
    expect(find.text('30 points · 1 entries without both values, not plotted'), findsOneWidget);
    expect(find.textContaining('Strong link: when one rises, the other tends to rise.'), findsOneWidget);
    expect(find.textContaining('Trend (dashed): Calories ≈'), findsOneWidget);

    // Keyboard: End selects the furthest session, Enter opens it.
    await tester.tap(find.byKey(const Key('scatter-plot')), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(find.textContaining('Distance: 15.5 km'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, hasLength(1));
  });

  testWidgets('the points can be saved as CSV', (tester) async {
    final saved = <String, String>{};
    final previous = saveChartExport;
    saveChartExport = (name, bytes) async { saved[name] = utf8.decode(bytes.sublist(3)); return true; };
    addTearDown(() => saveChartExport = previous);
    await _pumpWide(tester, AnalysisScatterChart(api: CollectionsApi(_Auth()), collection: _collection, format: _format, french: true, onOpenEntry: (_) async {}));
    await tester.tap(find.byKey(const Key('scatter-draw')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Télécharger les points (CSV)'));
    await tester.pumpAndSettle();
    expect(saved.values.single.split('\r\n').first, '"Entrée","Distance","Calories"');
    expect(saved.values.single.split('\r\n'), hasLength(31));
    expect(find.text('Fichier enregistré'), findsOneWidget);
  });

  testWidgets('a format with one number field explains why there is no scatter plot', (tester) async {
    const single = BrainyFormat(id: 'g', name: 'G', color: '#FFF', fields: [BrainyField(id: 'n', name: 'N', kind: BrainyFieldKind.number)]);
    await _pumpWide(tester, AnalysisScatterChart(api: CollectionsApi(_Auth()), collection: _collection, format: single, french: true, onOpenEntry: (_) async {}));
    expect(find.textContaining('deux champs nombre'), findsOneWidget);
  });

  for (final width in [320.0, 1000.0]) {
    testWidgets('the radar draws at $width px, a tap and the arrow keys select a category', (tester) async {
      await _pumpWide(tester, AnalysisRadarChart(
        rows: [_row('Course', '2314'), _row('Marche', '4038'), _row('Natation', '3530'), _row('Vélo', '2922'), _row('Yoga', '4546')],
        comparisonRows: [_row('Course', '2000'), _row('Yoga', '4100')],
        unit: 'kcal',
        french: true,
      ), width: width);
      expect(find.byKey(const Key('radar-plot')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final plot = tester.getRect(find.byKey(const Key('radar-plot')));
      await tester.tapAt(Offset(plot.center.dx, plot.top + 30)); // near the top axis: Course
      await tester.pumpAndSettle();
      expect(find.textContaining('Course · 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.textContaining('Marche · 4'), findsOneWidget);
      expect(find.textContaining('Comparée : aucune donnée'), findsOneWidget, reason: 'a category missing from the compared period is not a zero');
      await tester.tap(find.byKey(const Key('radar-comparison-toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
