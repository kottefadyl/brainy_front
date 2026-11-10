import 'dart:convert';

import 'package:brainy/code_picker.dart';
import 'package:brainy/referential_import.dart';
import 'package:brainy/referentials_api.dart';
import 'package:brainy/remote_code_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 10 regions, 100 departments, 5,890 towns, as the API smoke test imports.
final _codes = [
  for (var r = 1; r <= 10; r++) (code: 'R$r', fr: 'Région $r', parent: null as String?),
  for (var d = 1; d <= 100; d++) (code: 'D$d', fr: 'Département $d', parent: 'R${(d - 1) % 10 + 1}' as String?),
  for (var t = 1; t <= 5890; t++) (code: 'T$t', fr: 'Commune Évry $t', parent: 'D${(t - 1) % 100 + 1}' as String?),
];
final _byCode = {for (final item in _codes) item.code: item};
String _fold(String text) => text.toLowerCase().replaceAll('é', 'e').replaceAll('É', 'e');

class _FakeSource {
  final searches = <(String, String?)>[];
  bool fail = false;

  List<String> _path(String? parent) {
    final out = <String>[];
    for (var item = _byCode[parent]; item != null; item = _byCode[item.parent]) {
      out.insert(0, item.fr);
    }
    return out;
  }

  late final source = RemoteCodeSource(
    search: (query, parentCode) async {
      searches.add((query, parentCode));
      if (fail) throw Exception('offline');
      final q = _fold(query);
      final found = _codes.where((item) => q.isNotEmpty ? _fold('${item.code} ${item.fr}').contains(q) : item.parent == parentCode).take(50);
      return [
        for (final item in found)
          FoundCode(code: item.code, label: item.fr, path: _path(item.parent), level: _path(item.parent).length + 1, hasChildren: !item.code.startsWith('T')),
      ];
    },
    byValue: (codes) async => [
      for (final code in codes)
        if (_byCode[code] case final item?) {'code': item.code, 'labelFr': item.fr, 'labelEn': item.fr, 'parentCode': item.parent, 'active': true},
    ],
  );
}

Future<void> _sized(WidgetTester tester, Widget child, {double width = 320}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(12), child: child))));
  await tester.pumpAndSettle();
}

Finder _row(String code) => find.byKey(ValueKey('remote-code-row-$code'));

void main() {
  testWidgets('browses level by level and searches on the server, never the whole list', (tester) async {
    final fake = _FakeSource();
    String? chosen;
    await _sized(tester, SizedBox(height: 600, child: RemoteCodeBrowser(source: fake.source, french: true, onSelect: (code) => chosen = code)));
    expect(find.text('Région 1'), findsOneWidget);
    expect(fake.searches.single, ('', null));

    await tester.tap(find.byKey(const ValueKey('remote-code-open-R1')));
    await tester.pumpAndSettle();
    expect(fake.searches.last, ('', 'R1'));
    expect(_row('D1'), findsOneWidget);
    expect(find.text('Niveau précédent'), findsOneWidget);
    expect(find.text('Région 1'), findsOneWidget, reason: 'the trail names the open level');

    await tester.tap(find.text('Niveau précédent'));
    await tester.pumpAndSettle();
    expect(_row('R10'), findsOneWidget);

    // Typing a word sends one request after the pause, ignoring accents.
    final before = fake.searches.length;
    await tester.enterText(find.byKey(const ValueKey('remote-code-search')), 'e');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const ValueKey('remote-code-search')), 'evry 5890');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(fake.searches.length, before + 1);
    expect(fake.searches.last.$1, 'evry 5890');
    expect(find.text('Région 10 › Département 90'), findsOneWidget);

    await tester.tap(_row('T5890'));
    expect(chosen, 'T5890');
  });

  testWidgets('keys: → opens a level, ← goes back, Enter chooses', (tester) async {
    final fake = _FakeSource();
    String? chosen;
    await _sized(tester, SizedBox(height: 600, child: RemoteCodeBrowser(source: fake.source, french: false, autofocus: true, onSelect: (code) => chosen = code)), width: 1280);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(fake.searches.last, ('', 'R1'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(fake.searches.last, ('', null));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(chosen, 'R2');
  });

  testWidgets('a failed search offers to retry', (tester) async {
    final fake = _FakeSource()..fail = true;
    await _sized(tester, SizedBox(height: 400, child: RemoteCodeBrowser(source: fake.source, french: true)));
    expect(find.text('Recherche impossible.'), findsOneWidget);
    fake.fail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(_row('R1'), findsOneWidget);
  });

  testWidgets('the picker field labels a saved code fetched by value and opens the remote browser', (tester) async {
    final fake = _FakeSource();
    var value = 'T11';
    await _sized(tester, StatefulBuilder(builder: (context, setState) => CodePickerField(label: 'Commune', codes: const [], french: true, value: value, remote: fake.source, onChanged: (next) => setState(() => value = next))));
    expect(find.text('Commune Évry 11 (T11)'), findsOneWidget);
    await tester.tap(find.byType(CodePickerField));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteCodeBrowser), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remote-code-open-R1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-code-open-D1')));
    await tester.pumpAndSettle();
    await tester.tap(_row('T101'));
    await tester.pumpAndSettle();
    expect(value, 'T101');
    expect(find.text('Commune Évry 101 (T101)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('referential import', () {
    ReferentialPreview previewOf(String content) {
      final lines = const LineSplitter().convert(content.trim());
      final seen = <String>{};
      final errors = <Map<String, dynamic>>[];
      for (var index = 1; index < lines.length; index++) {
        final code = lines[index].split(RegExp('[;,]')).first;
        if (!seen.add(code)) errors.add({'row': index + 1, 'message': 'Repeated code $code'});
      }
      return ReferentialPreview.fromJson({
        'codeCount': lines.length - 1,
        'levels': 2,
        'large': lines.length - 1 > 5000,
        'errors': errors,
        'sample': [for (final line in lines.skip(1).take(3)) {'code': line.split(';').first, 'labelFr': line.split(';').last, 'labelEn': line.split(';').last}],
      });
    }

    Future<List<(String, String, String)>> pump(WidgetTester tester, String content, {String fileName = 'communes.csv'}) async {
      final saved = <(String, String, String)>[];
      await _sized(
        tester,
        SingleChildScrollView(
          child: ReferentialImport(
            french: true,
            readFile: () async => (name: fileName, bytes: utf8.encode(content)),
            preview: (format, text) async => format == 'JSON' ? ReferentialPreview.fromJson({'codeCount': 1, 'levels': 1, 'large': false, 'errors': [], 'sample': [{'code': 'A', 'labelFr': 'Alpha', 'labelEn': 'Alpha'}]}) : previewOf(text),
            save: (name, format, text) async {
              saved.add((name, format, text));
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('referential-file')));
      await tester.pumpAndSettle();
      return saved;
    }

    bool saveEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const ValueKey('referential-save'))).onPressed != null;

    testWidgets('a repeated code is reported by row and blocks the import', (tester) async {
      final content = ['code;label', for (var i = 0; i < 6000; i++) 'C$i;Code $i', 'C5;Encore'].join('\n');
      await pump(tester, content);
      expect(find.text('6 001 codes sur 2 niveaux'), findsOneWidget);
      expect(find.textContaining('Grande liste'), findsOneWidget);
      expect(find.text('Ligne 6002 : Repeated code C5'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('referential-name'))).controller!.text, 'communes', reason: 'the file name proposes the list name');
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a valid file is previewed, then imported with its format', (tester) async {
      final saved = await pump(tester, '[{"code":"A","label":"Alpha"}]', fileName: 'alpha.json');
      expect(find.text('1 code sur 1 niveau'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
      await tester.tap(find.byKey(const ValueKey('referential-save')));
      await tester.pumpAndSettle();
      expect(saved.single.$1, 'alpha');
      expect(saved.single.$2, 'JSON');
      expect(find.text('1 code importé.'), findsOneWidget);
    });
  });

  test('format detection and large lists', () {
    expect(referentialFormatOf('x.csv', 'code;label'), 'CSV');
    expect(referentialFormatOf('x.txt', '  {"codes":[]}'), 'JSON');
    expect(isLargeCodeList({'external': true}), isTrue);
    expect(isLargeCodeList({'codes': []}), isFalse);
    expect(isLargeCodeList(null), isFalse);
  });
}
