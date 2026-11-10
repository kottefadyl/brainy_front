import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/app_strings.dart';
import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/classification_screen.dart';
import 'package:brainy/code_picker.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/entry_clipboard.dart';
import 'package:brainy/referentials_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Native review of a large code list (T39/3) on the real local API, with a
/// temporary account seeded beforehand. Build with
/// `flutter build windows --debug --no-pub --target tool/large_codes_preview.dart
/// --dart-define=REVIEW_EMAIL=… --dart-define=REVIEW_PASSWORD=…
/// --dart-define=REVIEW_COLLECTION=… --dart-define=REVIEW_LIST=…
/// --dart-define=VISUAL_OUTPUT=C:/absolute/path`. Logs LARGE_CODES_REVIEW_COMPLETE.
void main() => runApp(const _Preview());

const _email = String.fromEnvironment('REVIEW_EMAIL');
const _password = String.fromEnvironment('REVIEW_PASSWORD');
const _collectionId = String.fromEnvironment('REVIEW_COLLECTION');
const _listId = String.fromEnvironment('REVIEW_LIST');
const _height = 780.0;

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  final _navigator = GlobalKey<NavigatorState>();
  final _auth = AuthApi();
  late final _api = CollectionsApi(_auth);
  BrainyCollection? _collection;
  var _dark = false;
  var _width = 320.0;
  var _page = 'list';
  var _value = 'T11';
  var _generation = 0;
  final _log = StringBuffer();

  Directory get _output {
    const requested = String.fromEnvironment('VISUAL_OUTPUT');
    return Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/brainy-large-codes');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _note(String line) {
    debugPrint(line);
    _log.writeln(line);
  }

  Future<void> _save(String name, Duration wait) async {
    await Future<void>.delayed(wait);
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await _output.create(recursive: true);
    await File('${_output.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  }

  Element? _find(bool Function(Element) test) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (test(element)) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }

    (_boundary.currentContext! as Element).visitChildElements(visit);
    return found;
  }

  Element? _byKey(String key) => _find((element) => element.widget.key == ValueKey(key));

  void _tap(Element element) {
    final box = element.renderObject! as RenderBox;
    final position = box.localToGlobal(box.size.center(Offset.zero));
    GestureBinding.instance
      ..handlePointerEvent(PointerDownEvent(pointer: 91, position: position))
      ..handlePointerEvent(PointerUpEvent(pointer: 91, position: position));
  }

  void _type(String text) {
    final field = _find((element) => element is StatefulElement && element.state is EditableTextState)! as StatefulElement;
    (field.state as EditableTextState).userUpdateTextEditingValue(TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)), SelectionChangedCause.keyboard);
  }

  void _expect(bool condition, String what) => _note('${condition ? 'OK  ' : 'FAIL'} $what');

  Future<void> _run() async {
    try {
      await _auth.login(_email, _password);
      final collection = (await _api.collections()).firstWhere((item) => item.id == _collectionId);
      final list = collection.codeLists.firstWhere((item) => item['id'] == _listId);
      _expect(isLargeCodeList(list) && (list['codes'] as List).isEmpty && list['codeCount'] == 6000, 'the collection carries 6,000 codes as a count only');
      setState(() => _collection = collection);
      final entry = (await _api.entries(_collectionId)).firstWhere((item) => item.values.values.contains('T11'));
      _note('COPY fr:\n${entryClipboardText(collection, entry, AppStrings('fr'))}');
      _note('COPY en:\n${entryClipboardText(collection, entry, AppStrings('en'))}');

      for (final width in Platform.isAndroid ? [320.0, 390.0] : [320.0, 1000.0]) {
        for (final dark in [false, true]) {
          final tag = '${width.toInt()}-${dark ? 'dark' : 'light'}';
          setState(() {
            _width = width;
            _dark = dark;
            _page = 'list';
            _value = 'T11';
            _generation++;
          });
          await _save('$tag-1-list', const Duration(seconds: 3));
          _expect(_byKey('remote-code-row-R1') != null, '$tag list screen shows the regions');

          setState(() {
            _page = 'field';
            _generation++;
          });
          await _save('$tag-2-field', const Duration(seconds: 2));
          _expect(_find((element) => element.widget is Text && (element.widget as Text).data == 'Commune Évry 11 (T11)') != null, '$tag saved code labelled by value');

          _tap(_find((element) => element.widget is CodePickerField)!);
          await _save('$tag-3-roots', const Duration(seconds: 2));
          _tap(_byKey('remote-code-open-R1')!);
          await _save('$tag-4-level', const Duration(seconds: 2));
          _expect(_byKey('remote-code-row-D1') != null, '$tag → opens the departments of Région 1');
          _type('evry 589');
          await _save('$tag-5-search', const Duration(seconds: 2));
          final row = _byKey('remote-code-row-T5890');
          _expect(row != null, '$tag accent-free search finds T5890');
          _tap(row!);
          await _save('$tag-6-chosen', const Duration(seconds: 2));
          _expect(_value == 'T5890', '$tag choosing closes the picker with T5890');
        }
      }
    } catch (error, stack) {
      _note('FAIL $error\n$stack');
    }
    await _output.create(recursive: true);
    await File('${_output.path}/review.log').writeAsString(_log.toString());
    await _auth.signOut();
    debugPrint('LARGE_CODES_REVIEW_COMPLETE ${_output.path}');
    if (!Platform.isAndroid) exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final collection = _collection;
    final source = _api.remoteCodes(_collectionId, _listId, french: true);
    Widget page;
    if (collection == null) {
      page = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_page == 'list') {
      page = ClassificationScreen(key: ValueKey(_generation), api: _api, collection: collection, targets: [collection], french: true, initialListId: _listId);
    } else {
      page = Scaffold(
        appBar: AppBar(title: const Text('Visites')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: CodePickerField(
            key: ValueKey(_generation),
            label: 'Commune',
            codes: const [],
            french: true,
            value: _value,
            remote: source,
            canSelect: (node) => node.active || node.code == _value,
            emptyLabel: 'Aucune valeur',
            onChanged: (next) => setState(() => _value = next),
          ),
        ),
      );
    }
    return MaterialApp(
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: Duration.zero,
      theme: _dark ? BrainyTheme.dark : BrainyTheme.light,
      builder: (context, child) => Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _boundary,
          child: SizedBox(
            width: _width,
            height: _height,
            child: MediaQuery(data: MediaQuery.of(context).copyWith(size: Size(_width, _height)), child: child!),
          ),
        ),
      ),
      home: page,
    );
  }
}
