import 'package:brainy/analysis_chart.dart';
import 'package:brainy/analysis_multi_series_chart.dart';
import 'package:brainy/chart_math.dart';
import 'package:brainy/chart_zoom.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(String group, num value) => {
  'group': group,
  'label': group,
  'value': '$value',
  'count': 2,
  'sources': <Map<String, dynamic>>[],
  'sourcesHasMore': false,
};

final _months = [for (var month = 1; month <= 12; month++) _row('2026-${'$month'.padLeft(2, '0')}', 1000 + month * 100)];

Future<void> _mount(WidgetTester tester, Widget chart, {double width = 390}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(12), child: chart)),
      ),
    ),
  );
  await tester.pump();
}

Widget _single({List<Map<String, dynamic>>? rows}) => StatefulBuilder(
  builder: (context, setState) => AnalysisChart(
    rows: rows ?? _months,
    unit: 'EUR',
    french: true,
    view: ChartView.line,
    views: const [ChartView.line, ChartView.bar],
    onViewChange: (_) {},
    height: 220,
  ),
);

Finder get _scrubber => find.byKey(const ValueKey('chart-scrubber'));
Finder get _plot => find.byKey(const ValueKey('analysis-chart-series'));

void main() {
  group('zoom windows', () {
    test('zoom keeps its anchor, a minimum width and the data bounds', () {
      expect(zoomWindow(const ChartWindow.full(12), 12, 0.5), const ChartWindow(3, 9));
      expect(zoomWindow(const ChartWindow.full(12), 12, 0.5, 0), const ChartWindow(0, 6));
      expect(zoomWindow(const ChartWindow.full(12), 12, 0.1), const ChartWindow(4, 9));
      expect(zoomWindow(const ChartWindow.full(3), 3, 0.5), const ChartWindow(0, 3));
      expect(zoomWindow(const ChartWindow(8, 12), 12, 4), const ChartWindow.full(12));
      expect(shiftWindow(const ChartWindow(3, 9), 12, 10), const ChartWindow(6, 12));
      expect(shiftWindow(const ChartWindow(3, 9), 12, -10), const ChartWindow(0, 6));
      expect(clampWindow(0, 12, 7), const ChartWindow(0, 7));
    });
  });

  testWidgets('buttons zoom in and out, the scroll bar pans by keyboard and 0 resets', (tester) async {
    await _mount(tester, _single());
    expect(_scrubber, findsNothing);
    await tester.tap(find.byTooltip('Zoom avant'));
    await tester.pump();
    expect(find.text('Zoom : 6 points sur 12.'), findsOneWidget);
    expect(_scrubber, findsOneWidget);
    expect(tester.getSize(_scrubber).height, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(_scrubber).value, contains('avril 2026 – septembre 2026'));

    await tester.tap(_scrubber);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(tester.getSemantics(_scrubber).value, contains('juillet 2026 – décembre 2026'));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(tester.getSemantics(_scrubber).value, contains('janvier 2026 – juin 2026'));

    // A point of the chart: 0 shows everything again, + zooms around it.
    await tester.tapAt(tester.getCenter(_plot));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0, character: '0');
    await tester.pump();
    expect(_scrubber, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal, character: '+');
    await tester.pump();
    expect(_scrubber, findsOneWidget);
    await tester.tap(find.byTooltip('Tout afficher'));
    await tester.pump();
    expect(_scrubber, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl + wheel zooms, a plain wheel does not', (tester) async {
    await _mount(tester, _single(), width: 1000);
    final center = tester.getCenter(_plot);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pump();
    expect(_scrubber, findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -300)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_scrubber, findsOneWidget);
  });

  testWidgets('two fingers pinch to zoom', (tester) async {
    await _mount(tester, _single());
    final center = tester.getCenter(_plot);
    final first = await tester.createGesture(pointer: 1, kind: PointerDeviceKind.touch);
    final second = await tester.createGesture(pointer: 2, kind: PointerDeviceKind.touch);
    await first.down(center - const Offset(30, 0));
    await second.down(center + const Offset(30, 0));
    await tester.pump();
    await first.moveTo(center - const Offset(120, 0));
    await second.moveTo(center + const Offset(120, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_scrubber, findsOneWidget);
  });

  testWidgets('several series zoom the same way', (tester) async {
    final rows = [
      for (var month = 1; month <= 12; month++)
        for (final key in ['a', 'b'])
          {
            ..._row('2026-${'$month'.padLeft(2, '0')} × $key', month),
            'rowKey': '2026-${'$month'.padLeft(2, '0')}',
            'columnKey': key,
          },
    ];
    await _mount(
      tester,
      AnalysisMultiSeriesChart(multi: splitCrossTab(rows, 'MONTH', 'CATEGORY')!, french: false, view: ChartView.line, onViewChange: (_) {}, height: 220),
    );
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(find.text('Zoomed: 6 of 12 periods.'), findsOneWidget);
    expect(_scrubber, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
