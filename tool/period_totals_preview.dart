import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/period_totals_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Temporary native review of the KT personal panel with synthetic totals.
void main() => runApp(const _Preview());

class _Auth extends AuthApi {
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    final from = (variables['input'] as Map<String, dynamic>)['from'] as String;
    final value = from.endsWith('-01-01') ? '2485500' : from.endsWith('-01') ? '215000.5' : '48500';
    return {'analyseCollection': {'rows': [{'group': 'all', 'label': 'all', 'value': value, 'count': 1}]}};
  }
}

const _format = BrainyFormat(id: 'f', name: 'Bilan du jour', color: '#EAF8FA', fields: [
  BrainyField(id: 'd', name: 'Date', kind: BrainyFieldKind.date),
  BrainyField(id: 'a', name: 'Montant', kind: BrainyFieldKind.number, unit: 'FCFA'),
]);

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

  Future<void> _run() async {
    const output = String.fromEnvironment('VISUAL_OUTPUT');
    for (final width in [320.0, 1000.0]) {
      for (final dark in [false, true]) {
        setState(() { _width = width; _dark = dark; });
        await Future<void>.delayed(const Duration(seconds: 2));
        final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/kt-native-${width.toInt()}-${dark ? 'dark' : 'light'}.png').writeAsBytes(bytes!.buffer.asUint8List());
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
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _boundary,
        child: SizedBox(
          width: _width,
          child: Material(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: PeriodTotalsPanel(api: _api, collection: const BrainyCollection(id: 'c', name: 'KT personal', fields: [], formats: [_format], periodTotals: BrainyPeriodTotals(formatId: 'f', dateFieldId: 'd', amountFieldId: 'a')), entries: const [], french: true, onSaved: () {}),
            ),
          ),
        ),
      ),
    ),
  );
}
