import 'package:brainy/analysis_chart.dart';
import 'package:brainy/analysis_gauge.dart';
import 'package:brainy/analysis_multi_series_chart.dart';
import 'package:brainy/chart_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _cell(String month, String category, String value) =>
    {'group': month, 'label': month, 'rowKey': month, 'columnKey': category, 'value': value, 'count': 1, 'sources': <Map<String, dynamic>>[], 'sourcesHasMore': false};

ChartPoint _point(double value) => ChartPoint(group: 'g', label: 'g', value: value, count: 1);

void main() {
  test('stacked tops add series in order and count gaps and negatives as zero', () {
    final series = [
      ChartSeries(key: 'a', label: 'A', total: 3, points: [_point(1), null, _point(2)]),
      ChartSeries(key: 'b', label: 'B', total: 5, points: [_point(4), _point(-1), _point(1)]),
    ];
    expect(stackedTops(series, [0, 1, 2]), [
      [1, 0, 2],
      [5, 0, 3],
    ]);
    expect(stackedTops(series, [2]), [
      [2],
      [3],
    ]);
  });

  test('a gauge target accepts a French comma and refuses zero or text', () {
    expect(parseGaugeTarget('1 250,5'), 1250.5);
    expect(parseGaugeTarget('0'), isNull);
    expect(parseGaugeTarget('abc'), isNull);
    final half = gaugeProgress(50, 200);
    expect([half.ratio, half.percent], [0.25, 25]);
    final over = gaugeProgress(300, 200);
    expect([over.ratio, over.percent], [1.0, 150]);
  });

  testWidgets('the stacked view is offered, draws, and its label gives the total', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final multi = splitCrossTab([
      _cell('2026-01', 'Food', '10'), _cell('2026-01', 'Rent', '30'),
      _cell('2026-02', 'Food', '12'), _cell('2026-02', 'Rent', '30'),
      _cell('2026-03', 'Food', '8'), _cell('2026-03', 'Rent', '31'),
    ], 'MONTH', 'CATEGORY')!;
    var view = ChartView.line;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AnalysisMultiSeriesChart(
            multi: multi,
            unit: 'EUR',
            french: false,
            view: view,
            views: const [ChartView.line, ChartView.bar, ChartView.stacked],
            onViewChange: (next) => setState(() => view = next),
            height: 230,
          ),
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Stacked areas'));
    await tester.pumpAndSettle();
    expect(view, ChartView.stacked);
    await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('multi-series-chart-series'))) + const Offset(60, 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('multi-series-total')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('multi-series-total'))).data, contains('40'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a key figure shows progress toward a typed target, in both themes', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: AnalysisChart(
            rows: const [{'group': 'all', 'label': 'All', 'value': '750', 'count': 12}],
            french: true,
            unit: 'EUR',
            view: ChartView.bar,
            views: const [ChartView.bar],
            onViewChange: (_) {},
            height: 200,
          ),
        ),
      ));
      await tester.enterText(find.byKey(const ValueKey('gauge-target')), '1 000');
      await tester.pump();
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('gauge-target')), '500');
      await tester.pump();
      expect(find.text('Objectif atteint'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('gauge-target')), 'x');
      await tester.pump();
      expect(find.text('Entrez un nombre supérieur à zéro.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
