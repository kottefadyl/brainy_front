import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/analysis_chart.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Native review of the analysis chart with synthetic data: no account, no API.
/// `flutter build windows --debug --no-pub --target tool/chart_preview.dart
/// --dart-define=VISUAL_OUTPUT=C:/absolute/path`, then run the executable.
void main() => runApp(const _Preview());

Map<String, dynamic> _row(String group, num value, int count) => {
  'group': group,
  'label': group,
  'value': '$value',
  'count': count,
  'sources': <Map<String, dynamic>>[],
  'sourcesHasMore': false,
};

final _months = [for (var i = 1; i <= 12; i++) i.toString().padLeft(2, '0')];
const _current = [12450, 13800, 11200, 15600, 0, 9000, 14200, 16100, 15000, 17300, 12000, 18250];
const _previous = [9000, 12000, 10500, 11800, 12600, 9400, 13100, 12000, 13900, 14500, 11000, 15000];
final _rows = [for (var i = 0; i < 12; i++) _row('2026-${_months[i]}', _current[i], 42 + i)];
final _compared = [for (var i = 0; i < 12; i++) _row('2025-${_months[i]}', _previous[i], 30 + i)];
final _dense = [
  for (var i = 0; i < 500; i++)
    _row(DateTime.utc(2025, 1, 1 + i).toIso8601String().substring(0, 10), i == 250 ? 900 : 100 + (i % 37), 1),
];

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  final _plot = GlobalKey();
  var _dark = false;
  var _width = 320.0;
  var _view = ChartView.line;
  var _rowsShown = _rows;
  var _comparison = _compared;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _settle() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 260));
  }

  Future<void> _save(String name) async {
    await _settle();
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    const requested = String.fromEnvironment('VISUAL_OUTPUT');
    final directory = Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/brainy-chart');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _capture() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    for (final width in Platform.isAndroid ? [320.0, 390.0] : [320.0, 390.0, 1000.0]) {
      for (final dark in [false, true]) {
        final tag = '${width.toInt()}-${dark ? 'dark' : 'light'}';
        setState(() {
          _width = width;
          _dark = dark;
          _view = ChartView.line;
          _rowsShown = _rows;
          _comparison = _compared;
        });
        await _save('$tag-line');
        await _settle();
        final box = _plot.currentContext!.findRenderObject()! as RenderBox;
        final position = box.localToGlobal(Offset(box.size.width * 0.45, box.size.height - 90));
        final binding = GestureBinding.instance;
        binding.handlePointerEvent(PointerAddedEvent(position: position, kind: ui.PointerDeviceKind.mouse));
        binding.handlePointerEvent(PointerHoverEvent(position: position, kind: ui.PointerDeviceKind.mouse));
        await _save('$tag-tooltip');
        binding.handlePointerEvent(PointerRemovedEvent(position: position, kind: ui.PointerDeviceKind.mouse));
        setState(() => _view = ChartView.bar);
        await _save('$tag-bars');
        setState(() {
          _view = ChartView.line;
          _rowsShown = _dense;
          _comparison = const [];
        });
        await _save('$tag-dense');
      }
    }
    debugPrint('CHART_REVIEW_COMPLETE ${Directory.systemTemp.path}');
    if (Platform.isAndroid) return;
    await SystemNavigator.pop();
    exit(0);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BrainyTheme.light,
    darkTheme: BrainyTheme.dark,
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _boundary,
        child: SizedBox(
          width: _width,
          height: 460,
          child: Material(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: KeyedSubtree(
                  key: _plot,
                  child: AnalysisChart(
                    rows: _rowsShown,
                    comparisonRows: _comparison,
                    unit: 'EUR',
                    french: true,
                    view: _view,
                    views: const [ChartView.line, ChartView.bar],
                    onViewChange: (next) => setState(() => _view = next),
                    height: 280,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
