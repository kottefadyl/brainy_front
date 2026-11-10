import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/analysis_radar_chart.dart';
import 'package:brainy/analysis_scatter_chart.dart';
import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Native review of the T23/1 radar and scatter plot with synthetic data (no account, no network).
/// `flutter run -d windows -t tool/scatter_radar_preview.dart --dart-define=VISUAL_OUTPUT=folder`
void main() => runApp(const _Preview());

class _Auth extends AuthApi {
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async => {
    'collectionEntriesPage': {
      'entries': [
        for (var index = 0; index < 30; index++)
          {
            'id': 'e$index', 'formatId': 'f', 'createdAt': '2026-11-01T10:00:00Z', 'updatedAt': '2026-11-01T10:00:00Z',
            'values': [
              {'fieldId': 't', 'value': 'Séance ${index + 1}'},
              {'fieldId': 'd', 'value': '${2 + (index % 10) * 1.5}'},
              {'fieldId': 'c', 'value': '${((2 + (index % 10) * 1.5) * 62 + (index % 4) * 25).round()}'},
            ],
          },
      ],
      'nextCursor': null,
      'hasMore': false,
    },
  };
}

const _format = BrainyFormat(id: 'f', name: 'Séance', color: '#F4F0FF', fields: [
  BrainyField(id: 't', name: 'Titre', kind: BrainyFieldKind.title),
  BrainyField(id: 'd', name: 'Distance', kind: BrainyFieldKind.number, unit: 'km'),
  BrainyField(id: 'c', name: 'Calories', kind: BrainyFieldKind.number),
]);
Map<String, dynamic> _row(String group, String value) => {'group': group, 'label': group, 'value': value, 'count': 6, 'sources': <Map<String, dynamic>>[], 'sourcesHasMore': false};

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _press(Key key) {
    void visit(Element element) {
      final widget = element.widget;
      if (widget is FilledButton && widget.key == key) {
        widget.onPressed?.call();
      } else {
        element.visitChildren(visit);
      }
    }
    (_boundary.currentContext! as Element).visitChildren(visit);
  }

  Future<void> _run() async {
    const output = String.fromEnvironment('VISUAL_OUTPUT');
    for (final width in [320.0, 1000.0]) {
      for (final dark in [false, true]) {
        setState(() { _width = width; _dark = dark; });
        await Future<void>.delayed(const Duration(milliseconds: 600));
        _press(const Key('scatter-draw'));
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/scatter-radar-${width.toInt()}-${dark ? 'dark' : 'light'}.png').writeAsBytes(bytes!.buffer.asUint8List());
      }
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BrainyTheme.light,
    darkTheme: BrainyTheme.dark,
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: Scaffold(
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundary,
            child: SizedBox(
              width: _width,
              child: Material(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Calories par activité (radar)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    AnalysisRadarChart(
                      key: ValueKey('radar-$_width-$_dark'),
                      rows: [_row('Course', '2314'), _row('Marche', '4038'), _row('Natation', '3530'), _row('Vélo', '2922'), _row('Yoga', '4546')],
                      comparisonRows: [_row('Course', '2000'), _row('Marche', '3600'), _row('Natation', '3800'), _row('Vélo', '2500'), _row('Yoga', '4100')],
                      unit: 'kcal',
                      title: 'Somme',
                      french: true,
                    ),
                    const SizedBox(height: 24),
                    Text('Relation entre deux champs', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    AnalysisScatterChart(
                      key: ValueKey('scatter-$_width-$_dark'),
                      api: _api,
                      collection: const BrainyCollection(id: 'c', name: 'Sport', fields: [], formats: [_format]),
                      format: _format,
                      french: true,
                      onOpenEntry: (_) async {},
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
