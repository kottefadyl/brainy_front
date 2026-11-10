import 'dart:typed_data';

import 'package:brainy/analysis_chart.dart';
import 'package:brainy/chart_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Map<String, dynamic> _row(String group, String value, [int count = 1]) => {'group': group, 'label': group, 'value': value, 'count': count};

void main() {
  group('chartCsv matches the web export', () {
    test('quotes every text, keeps the raw value and adds the series column when compared', () {
      final csv = chartCsv([_row('2026-01', '12.5', 3), _row('=danger', '1')], [_row('2025-01', '9', 2)], 'km', true);
      final lines = csv.split('\r\n');
      expect(lines.first, '﻿"Groupe","Libellé","Valeur","Unité","Nombre","Série"');
      expect(lines[1], '"2026-01","2026-01","12.5","km",3,"Période principale"');
      expect(lines[2], '"\'=danger","\'=danger","1","km",1,"Période principale"');
      expect(lines[3], '"2025-01","2025-01","9","km",2,"Période comparée"');
    });

    test('has no series column without a comparison, in English', () {
      final csv = chartCsv([_row('a', '1')], const [], null, false);
      expect(csv, '﻿"Group","Label","Value","Unit","Count"\r\n"a","a","1","",1');
      expect(csvBytes(csv).sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    });
  });

  testWidgets('the report image is twice the size, light, with title and legend', (tester) async {
    // Image encoding is real asynchronous work, outside the fake clock.
    final bytes = (await tester.runAsync(() => chartReportPng(
      title: 'Résultats · km',
      plot: const Size(400, 120),
      legend: const [ChartReportLegendItem('Main', Color(0xFF2463CE)), ChartReportLegendItem('Compared', Color(0xFF0F8F72), dashed: true)],
      paintPlot: (canvas, size) => canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFFF0000)),
    )))!;
    final decoded = img.decodePng(bytes)!;
    expect([decoded.width, decoded.height], [800, (40 + 120 + 34) * 2]);
    final corner = decoded.getPixel(2, 2);
    expect([corner.r, corner.g, corner.b], [255, 255, 255], reason: 'white background whatever the theme');
    final plot = decoded.getPixel(400, 80 + 100);
    expect([plot.r, plot.g, plot.b], [255, 0, 0], reason: 'the plot sits under the 40 px header');
  });

  testWidgets('the chart menu exports CSV through the saver and reports it', (tester) async {
    String? savedName;
    Uint8List? savedBytes;
    final previous = saveChartExport;
    saveChartExport = (name, bytes) async {
      savedName = name;
      savedBytes = bytes;
      return true;
    };
    addTearDown(() => saveChartExport = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnalysisChart(
            rows: [_row('2026-01', '1'), _row('2026-02', '2')],
            french: false,
            view: ChartView.line,
            views: const [ChartView.line, ChartView.bar],
            onViewChange: (_) {},
            height: 200,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('chart-export-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chart-export-csv')));
    await tester.pumpAndSettle();
    expect(savedName, matches(RegExp(r'^brainy-chart-\d{4}-\d{2}-\d{2}\.csv$')));
    expect(String.fromCharCodes(savedBytes!), contains('"2026-02","2026-02","2","",1'));
    expect(find.text('File saved'), findsOneWidget);
  });

  testWidgets('a failed export says so in red and a cancelled one stays quiet', (tester) async {
    final previous = saveChartExport;
    var calls = 0;
    saveChartExport = (name, bytes) async => ++calls == 1 ? throw StateError('no disk') : false;
    addTearDown(() => saveChartExport = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnalysisChart(rows: [_row('a', '1'), _row('b', '2')], french: true, view: ChartView.bar, views: const [ChartView.bar], onViewChange: (_) {}, height: 200),
        ),
      ),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byKey(const ValueKey('chart-export-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chart-export-csv')));
      await tester.pumpAndSettle();
    }
    expect(calls, 2);
    expect(find.text('Export impossible. Réessayez.'), findsNothing, reason: 'the second, cancelled export clears the note');
    expect(find.byKey(const ValueKey('chart-export-note')), findsNothing);
  });
}
