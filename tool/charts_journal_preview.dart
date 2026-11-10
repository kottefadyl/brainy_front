import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/analysis_chart.dart';
import 'package:brainy/analysis_gauge.dart';
import 'package:brainy/analysis_multi_series_chart.dart';
import 'package:brainy/audit_log_screen.dart';
import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/chart_math.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Native review of the 10 November additions with synthetic data (no account, no network):
/// chart with its export button, stacked areas, key figure gauge and the audit journal.
/// `flutter run -d windows -t tool/charts_journal_preview.dart --dart-define=VISUAL_OUTPUT=folder`
void main() => runApp(const _Preview());

final _now = DateTime.now().toUtc();

class _Auth extends AuthApi {
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    if (!query.contains('collectionAuditLogs')) throw StateError('No network in the preview');
    Map<String, dynamic> log(String action, String? details, int minutesAgo, {String user = 'owner'}) =>
        {'id': '$action$minutesAgo', 'collectionId': 'c', 'userId': user, 'action': action, 'details': details, 'occurredAt': _now.subtract(Duration(minutes: minutesAgo)).toIso8601String()};
    return {
      'collectionAuditLogs': [
        log('SENSITIVE_AGGREGATE_ALERT', 'BURST: the same sensitive question was asked repeatedly within an hour; data format f1; query 0123456789abcdef', 4, user: 'u1'),
        log('READ_SENSITIVE_AGGREGATE', 'Data format f1; operation AVERAGE; query 0123456789abcdef; observations 57', 6, user: 'u1'),
        log('SET_FIELD_SENSITIVITY', 'Revenu mensuel: SENSITIVE', 50),
        log('SET_MINIMUM_AGGREGATE_SIZE', 'minimum 5', 52),
        log('UPDATE_ENTRY', null, 120, user: 'u1'),
        log('CREATE_ENTRY', null, 600),
      ],
    };
  }
}

Map<String, dynamic> _row(String group, num value) => {'group': group, 'label': group, 'value': '$value', 'count': 1, 'sources': <Map<String, dynamic>>[], 'sourcesHasMore': false};
Map<String, dynamic> _cell(String month, String category, num value) =>
    {'group': month, 'label': month, 'rowKey': month, 'columnKey': category, 'value': '$value', 'count': 1, 'sources': <Map<String, dynamic>>[], 'sourcesHasMore': false};

const _months = ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11'];
final _income = [for (final (i, month) in _months.indexed) _row(month, [420000, 455000, 398000, 510000, 486000, 530000][i])];
final _lastYear = [for (final (i, month) in _months.indexed) _row(month.replaceFirst('2026', '2025'), [380000, 401000, 372000, 455000, 430000, 470000][i])];
final _spending = splitCrossTab([
  for (final (i, month) in _months.indexed) ...[
    _cell(month, 'Logement', 120000),
    _cell(month, 'Alimentation', [95000, 102000, 88000, 110000, 99000, 105000][i]),
    _cell(month, 'Transport', [42000, 39000, 45000, 41000, 47000, 44000][i]),
    _cell(month, 'Loisirs', [30000, 52000, 61000, 28000, 35000, 40000][i]),
  ],
], 'MONTH', 'CATEGORY')!;

final _collection = BrainyCollection.fromJson({
  'id': 'c', 'name': 'Calculs · Enquête (données sensibles)', 'ownerId': 'owner', 'formats': [], 'fields': [],
  'members': [{'userId': 'u1', 'email': 'awa@example.test', 'name': 'Awa Koné', 'role': 'EDITOR', 'addedAt': '2026-11-01T00:00:00Z'}],
});

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  final _api = CollectionsApi(_Auth());
  double _width = 320;
  bool _dark = false;
  bool _journal = false;
  ChartView _view = ChartView.line;
  ChartView _stackedView = ChartView.stacked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    const output = String.fromEnvironment('VISUAL_OUTPUT');
    for (final journal in [false, true]) {
      for (final width in [320.0, 1000.0]) {
        for (final dark in [false, true]) {
          setState(() { _journal = journal; _width = width; _dark = dark; });
          // Type a target in the gauge, as a person would, so the dial is drawn.
          if (!journal) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            void visit(Element element) {
              final widget = element.widget;
              if (widget is TextField && widget.key == const ValueKey('gauge-target') && widget.controller!.text.isEmpty) {
                widget.controller!.text = '600 000';
                widget.onChanged!('600 000');
              }
              element.visitChildren(visit);
            }
            (_boundary.currentContext! as Element).visitChildren(visit);
          }
          await Future<void>.delayed(const Duration(milliseconds: 2500));
          final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/${journal ? 'journal' : 'charts'}-${width.toInt()}-${dark ? 'dark' : 'light'}.png').writeAsBytes(bytes!.buffer.asUint8List());
        }
      }
    }
    exit(0);
  }

  Widget _charts(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Revenus par mois', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      AnalysisChart(rows: _income, comparisonRows: _lastYear, unit: 'FCFA', title: 'Revenus par mois', french: true, view: _view, views: const [ChartView.line, ChartView.bar], onViewChange: (next) => setState(() => _view = next), height: 260),
      const SizedBox(height: 24),
      Text('Dépenses par catégorie (aires empilées)', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      AnalysisMultiSeriesChart(multi: _spending, unit: 'FCFA', french: true, view: _stackedView, views: const [ChartView.line, ChartView.bar, ChartView.stacked], onViewChange: (next) => setState(() => _stackedView = next), height: 260),
      const SizedBox(height: 24),
      Text('Chiffre clé avec objectif', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const KeyFigureGauge(value: 530000, unit: 'FCFA', french: true),
    ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BrainyTheme.light,
    darkTheme: BrainyTheme.dark,
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: Builder(
      builder: (context) => Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: _boundary,
              child: SizedBox(
                width: _width,
                height: _journal ? 760 : null,
                child: Material(
                  child: _journal
                      ? AuditLogScreen(key: ValueKey('journal-$_dark-$_width'), api: _api, collection: _collection, french: true)
                      : Padding(padding: const EdgeInsets.all(12), child: _charts(context)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
