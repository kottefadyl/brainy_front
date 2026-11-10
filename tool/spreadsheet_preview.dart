import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/spreadsheet_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Native review of the T46 spreadsheet mode with synthetic data, light and dark, 320 and 1000 px.
/// `flutter run -d windows -t tool/spreadsheet_preview.dart --dart-define=VISUAL_OUTPUT=folder`
void main() => runApp(const _Preview());

/// VISUAL_OUTPUT on a computer; on Android the app's temporary folder, read with `adb exec-out run-as`.
Future<String> _outputDir(String name) async {
  const requested = String.fromEnvironment('VISUAL_OUTPUT');
  final directory = Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/$name');
  await directory.create(recursive: true);
  return directory.path;
}

class _Auth extends AuthApi {
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async => throw StateError('No network in the preview');
}

const _format = BrainyFormat(id: 'f', name: 'Dépense', color: '#EDF9F3', fields: [
  BrainyField(id: 't', name: 'Libellé', kind: BrainyFieldKind.title),
  BrainyField(id: 'a', name: 'Montant', kind: BrainyFieldKind.number, unit: 'FCFA'),
  BrainyField(id: 'd', name: 'Date', kind: BrainyFieldKind.date),
  BrainyField(id: 'p', name: 'Payé', kind: BrainyFieldKind.boolean),
  BrainyField(id: 'c', name: 'Catégorie', kind: BrainyFieldKind.select, options: ['Repas', 'Transport', 'Loisirs']),
]);
final _entries = [
  for (final (id, title, amount, date, paid, category) in [('1', 'Déjeuner', '4500', '2026-11-03', 'true', 'Repas'), ('2', 'Taxi', '2500.5', '2026-11-04', 'false', 'Transport'), ('3', 'Cinéma', '6000', '2026-11-08', 'true', 'Loisirs')])
    BrainyEntry(id: id, formatId: 'f', values: {'t': title, 'a': amount, 'd': date, 'p': paid, 'c': category}, createdAt: DateTime.utc(2026, 11, 3), updatedAt: DateTime.utc(2026, 11, 3)),
];

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
    final output = await _outputDir('brainy-spreadsheet');
    await Future<void>.delayed(const Duration(seconds: 1));
    // Turn the spreadsheet mode on once; the choice is remembered for this view.
    final switchFinder = _boundary.currentContext!;
    void visit(Element element) { if (element.widget is SwitchListTile) { (element.widget as SwitchListTile).onChanged!(true); } else { element.visitChildren(visit); } }
    (switchFinder as Element).visitChildren(visit);
    for (final width in Platform.isAndroid ? [320.0, 390.0] : [320.0, 1000.0]) {
      for (final dark in [false, true]) {
        setState(() { _width = width; _dark = dark; });
        await Future<void>.delayed(const Duration(seconds: 2));
        final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/sheet-native-${width.toInt()}-${dark ? 'dark' : 'light'}.png').writeAsBytes(bytes!.buffer.asUint8List());
      }
    }
    debugPrint('PREVIEW_COMPLETE $output');
    if (!Platform.isAndroid) exit(0);
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
              child: SavedViewTable(
                api: _api,
                collection: const BrainyCollection(id: 'c', name: 'Feuille', fields: [], formats: [_format]),
                view: const {'id': 'preview', 'layout': 'TABLE', 'formatIds': ['f'], 'columnFieldIds': ['t', 'a']},
                entries: _entries,
                onOpenEntry: (_) {},
                onEntrySaved: (_) {},
                onCollectionChanged: (_) {},
                onEditFormat: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
