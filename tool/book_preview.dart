import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/auth_api.dart';
import 'package:brainy/book_model.dart';
import 'package:brainy/book_view_screen.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Native review of the T47 book view (no account, no network).
/// `flutter run -d windows -t tool/book_preview.dart --dart-define=VISUAL_OUTPUT=folder`
void main() => runApp(const _Preview());

BrainyFormat _format(String id, String name, String color, List<(String, BrainyFieldKind)> fields) =>
    BrainyFormat(id: id, name: name, color: color, fields: [for (final (fieldId, kind) in fields) BrainyField(id: fieldId, name: fieldId, kind: kind)]);

final _formats = [
  _format('cover', 'Couverture', '#EEF5FF', [('cover-title', BrainyFieldKind.title), ('cover-subtitle', BrainyFieldKind.text), ('cover-author', BrainyFieldKind.text), ('cover-image', BrainyFieldKind.attachment), ('cover-spine', BrainyFieldKind.text), ('cover-back', BrainyFieldKind.longText)]),
  _format('dedication', 'Dédicace', '#FFF0F4', [('dedication-text', BrainyFieldKind.longText)]),
  _format('preface', 'Préface', '#FFF5EB', [('preface-title', BrainyFieldKind.title), ('preface-text', BrainyFieldKind.longText)]),
  _format('part', 'Partie', '#EFEFFD', [('part-title', BrainyFieldKind.title), ('part-order', BrainyFieldKind.number), ('part-text', BrainyFieldKind.longText)]),
  _format('chapter', 'Chapitre', '#EFF8FF', [('chapter-title', BrainyFieldKind.title), ('chapter-order', BrainyFieldKind.number), ('chapter-text', BrainyFieldKind.longText)]),
  _format('section', 'Section', '#F1F8ED', [('section-title', BrainyFieldKind.title), ('section-order', BrainyFieldKind.number), ('section-text', BrainyFieldKind.longText)]),
  _format('subsection', 'Sous-section', '#F7FBEA', [('sub-title', BrainyFieldKind.title), ('sub-order', BrainyFieldKind.number), ('sub-text', BrainyFieldKind.longText)]),
  _format('conclusion', 'Conclusion', '#E9F8F4', [('conclusion-title', BrainyFieldKind.title), ('conclusion-text', BrainyFieldKind.longText)]),
  _format('term', 'Terme', '#FBF1E8', [('term-title', BrainyFieldKind.title), ('term-text', BrainyFieldKind.longText), ('term-glossary', BrainyFieldKind.boolean), ('term-index', BrainyFieldKind.boolean)]),
];
const _roles = {'cover': 'COVER', 'dedication': 'DEDICATION', 'preface': 'PREFACE', 'part': 'PART', 'chapter': 'CHAPTER', 'section': 'SECTION', 'subsection': 'SUBSECTION', 'conclusion': 'CONCLUSION', 'term': 'TERM'};
final _bookView = {...const BookSettings().toInput(), 'roles': [for (final item in _roles.entries) {'formatId': item.key, 'role': item.value}]};
final _collection = BrainyCollection(id: 'book', name: 'Le Jardin des heures', fields: _formats.first.fields, formats: _formats, templateId: 'book', bookView: _bookView);

Map<String, dynamic> _entry(String id, String formatId, Map<String, String> values) => {
      'id': id, 'formatId': formatId, 'createdAt': '2026-11-11T09:00:00Z', 'updatedAt': '2026-11-11T09:00:00Z',
      'values': [for (final item in values.entries) {'fieldId': item.key, 'value': item.value}],
    };

const _text = 'Le matin, la maison dormait encore. **Élise** ouvrit la fenêtre et laissa entrer *l’odeur des tilleuls*, comme chaque été depuis vingt ans.\n\nElle descendit au jardin. Les allées étaient humides, les roses penchées sous la rosée ; rien n’avait changé, et pourtant tout semblait plus petit.\n\n> Il faut cultiver notre jardin.\n\n***\n\nPlus tard, dans la cuisine, elle retrouva le carnet de sa grand-mère.';
final _entries = [
  _entry('cover-1', 'cover', {'cover-title': 'Le Jardin des heures', 'cover-subtitle': 'Roman', 'cover-author': 'Claire Martin', 'cover-back': 'Un été, une maison, un carnet oublié.'}),
  _entry('dedication-1', 'dedication', {'dedication-text': 'À ma grand-mère, *qui savait le nom de chaque fleur*.'}),
  _entry('preface-1', 'preface', {'preface-title': 'Préface', 'preface-text': 'Ce livre est né d’un carnet retrouvé.\n\nIl raconte un été, mais il parle de tous les autres.'}),
  _entry('part-1', 'part', {'part-title': 'L’été', 'part-order': '1'}),
  _entry('chapter-1', 'chapter', {'chapter-title': 'Le retour', 'chapter-order': '1', 'chapter-text': _text}),
  _entry('chapter-2', 'chapter', {'chapter-title': 'Le carnet', 'chapter-order': '2', 'chapter-text': 'Les pages étaient jaunies, l’écriture serrée.'}),
  _entry('section-1', 'section', {'section-title': 'La maison', 'section-order': '1', 'section-text': 'Les volets bleus avaient pâli.'}),
  _entry('sub-1', 'subsection', {'sub-title': 'L’horloge', 'sub-order': '1', 'sub-text': 'Personne ne l’avait remontée.'}),
  _entry('section-orphan', 'section', {'section-title': 'Une section à placer', 'section-order': '9'}),
  _entry('conclusion-1', 'conclusion', {'conclusion-title': 'Conclusion', 'conclusion-text': 'Le jardin, lui, continue.'}),
  _entry('term-1', 'term', {'term-title': 'Carnet', 'term-text': 'Petit cahier de notes.', 'term-glossary': 'true', 'term-index': 'true'}),
];
final _relations = [
  {'id': 'r1', 'fromEntryId': 'chapter-1', 'toEntryId': 'part-1', 'kind': 'PARENT'},
  {'id': 'r2', 'fromEntryId': 'chapter-2', 'toEntryId': 'part-1', 'kind': 'PARENT'},
  {'id': 'r3', 'fromEntryId': 'section-1', 'toEntryId': 'chapter-1', 'kind': 'PARENT'},
  {'id': 'r4', 'fromEntryId': 'sub-1', 'toEntryId': 'section-1', 'kind': 'PARENT'},
];

class _Auth extends AuthApi {
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    if (query.contains('collectionEntries')) return {'collectionEntries': _entries};
    if (query.contains('collectionParentRelations')) return {'collectionParentRelations': _relations};
    if (query.contains('setBookView')) return {'setBookView': {'bookView': _bookView}};
    return {};
  }
}

Future<String> _outputDir() async {
  const requested = String.fromEnvironment('VISUAL_OUTPUT');
  final directory = Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/brainy-book');
  await directory.create(recursive: true);
  return directory.path;
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  final _navigator = GlobalKey<NavigatorState>();
  double _width = 390;
  bool _dark = false;
  int _run = 0;
  String _mode = 'book';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _shot(String output, String name) async {
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  }

  Element? _find(bool Function(Widget widget) test) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (test(element.widget)) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }
    (_boundary.currentContext! as Element).visitChildren(visit);
    return found;
  }

  Future<void> _capture() async {
    final output = await _outputDir();
    for (final width in [390.0, 1280.0]) {
      for (final dark in [false, true]) {
        setState(() { _width = width; _dark = dark; _mode = 'book'; _run++; });
        await Future<void>.delayed(const Duration(milliseconds: 900));
        final name = 'book-${width.toInt()}-${dark ? 'dark' : 'light'}';
        await _shot(output, name);
        final chapter = _find((widget) => widget is Text && widget.data == 'CHAPITRE 1');
        if (chapter != null) {
          await Scrollable.ensureVisible(chapter);
          await Future<void>.delayed(const Duration(milliseconds: 400));
          await _shot(output, '$name-chapter');
        }
        final layout = _find((widget) => widget is IconButton && widget.tooltip == 'Mise en page');
        (layout?.widget as IconButton?)?.onPressed?.call();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _shot(output, '$name-settings');
        _navigator.currentState?.pop();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (width < 1000) {
          final outline = _find((widget) => widget is IconButton && widget.tooltip == 'Plan du livre');
          (outline?.widget as IconButton?)?.onPressed?.call();
          await Future<void>.delayed(const Duration(milliseconds: 700));
          await _shot(output, '$name-outline');
          _navigator.currentState?.pop();
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }
    for (final dark in [false, true]) {
      setState(() { _width = 390; _dark = dark; _mode = 'cards'; });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _shot(output, 'cards-${dark ? 'dark' : 'light'}');
    }
    debugPrint('PREVIEW_COMPLETE $output');
    exit(0);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: _navigator,
        debugShowCheckedModeBanner: false,
        theme: BrainyTheme.light,
        darkTheme: BrainyTheme.dark,
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final size = Size(_width, media.size.height);
          return Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: _boundary, child: SizedBox.fromSize(size: size, child: MediaQuery(data: media.copyWith(size: size), child: child!))));
        },
        home: _mode == 'cards'
            ? Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [
                BookViewLauncher(api: CollectionsApi(_Auth()), collection: _collection, french: true, onOpenEntry: (_) async {}, onChanged: () async {}),
                const SizedBox(height: 16),
                Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Livre', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  const Text('Couverture, pages liminaires, parties, chapitres, sections et pages finales, avec une vue livre à mettre en page.'),
                  BookTemplateArt(french: true, dark: _dark),
                ]))),
              ]))
            : BookViewScreen(key: ValueKey(_run), api: CollectionsApi(_Auth()), collection: _collection, initial: BookSettings.fromJson(_bookView), french: true, onOpenEntry: (_) async {}),
      );
}
