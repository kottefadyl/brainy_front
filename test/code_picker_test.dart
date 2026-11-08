import 'package:brainy/code_picker.dart';
import 'package:brainy/code_tree.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _code(String code, String labelFr, [String? parent, bool active = true]) => {
  'code': code,
  'labelFr': labelFr,
  'labelEn': '$labelFr EN',
  'parentCode': parent,
  'active': active,
};

final _sample = [
  _code('G', 'Commerce'),
  _code('47', 'Vente de détail', 'G'),
  _code('47.1', 'Magasins non spécialisés', '47'),
  _code('47.11', 'À prédominance alimentaire', '47.1'),
  _code('47.11B', "Commerce d'alimentation générale", '47.11'),
  _code('47.2', 'Épicerie fine', '47'),
  _code('OLD', 'Ancien code', '47', false),
  _code('A', 'Agriculture'),
  _code('01', 'Alimentation animale', 'A'),
];

bool _active(CodeNode node) => node.active;

Future<String?> _pick(WidgetTester tester, {String value = '', double width = 320, bool french = true}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  String? chosen;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: CodePickerField(
            label: 'Activité',
            codes: _sample,
            french: french,
            value: value,
            canSelect: (node) => node.active || node.code == value,
            emptyLabel: 'Aucune valeur',
            onChanged: (code) => chosen = code,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(CodePickerField));
  await tester.pumpAndSettle();
  return chosen;
}

Finder _row(String code) => find.byKey(ValueKey('code-row-$code'));
Finder get _search => find.byKey(const ValueKey('code-search'));

void main() {
  group('code tree matches the web client', () {
    final tree = CodeTree.build(_sample, true);
    bool all(CodeNode _) => true;

    test('paths, levels and roots', () {
      expect(tree.nodes['47.11B']!.path, ['Commerce', 'Vente de détail', 'Magasins non spécialisés', 'À prédominance alimentaire']);
      expect(tree.nodes['47.11B']!.level, 5);
      expect(tree.roots, ['G', 'A']);
      expect(tree.deepestLevel, 5);
    });

    test('folding ignores case and accents', () {
      expect(foldText('Épicerie Œuvre'), 'epicerie oeuvre');
      expect(foldText('Épicerie'), 'epicerie', reason: 'combining accents too');
    });

    test('search ranks and finds fragments', () {
      expect(tree.search('epice', all).results.map((node) => node.code), ['47.2']);
      expect(tree.search('ÉPICE', all).results.map((node) => node.code), ['47.2']);
      expect(tree.search('alim', all).results.map((node) => node.code), ['01', '47.11', '47.11B']);
      expect(tree.search('47', all).results.first.code, '47');
      expect(tree.search('   ', all).total, 0);
    });

    test('search reports the total beyond its limit', () {
      final big = CodeTree.build([for (var i = 0; i < 200; i++) _code('c$i', 'Même nom')], true);
      final found = big.search('meme', all, limit: 60);
      expect(found.results, hasLength(60));
      expect(found.total, 200);
    });

    test('descendants and reachable ancestors', () {
      expect(tree.descendantsOf('47'), {'47.1', '47.11', '47.11B', '47.2', 'OLD'});
      expect(tree.reachable((node) => node.code == '47.11B'), {'G', '47', '47.1', '47.11', '47.11B'});
    });

    test('a draft with a cycle does not hang', () {
      final cyclic = CodeTree.build([_code('a', 'A', 'b'), _code('b', 'B', 'a')], true);
      expect(cyclic.nodes, hasLength(2));
      expect(cyclic.nodes['a']!.path, ['B']);
    });
  });

  group('CodePickerField', () {
    testWidgets('branches unfold level by level at 320 px', (tester) async {
      await _pick(tester);
      expect(_row('G'), findsOneWidget);
      expect(_row('47'), findsNothing);
      await tester.tap(find.byTooltip('Déplier Commerce'));
      await tester.pump();
      expect(_row('47'), findsOneWidget);
      await tester.tap(find.byTooltip('Déplier Vente de détail'));
      await tester.pump();
      await tester.tap(find.byTooltip('Déplier Magasins non spécialisés'));
      await tester.pump();
      await tester.tap(find.byTooltip('Déplier À prédominance alimentaire'));
      await tester.pump();
      expect(_row('47.11B'), findsOneWidget);
      await tester.tap(find.byTooltip('Replier Commerce'));
      await tester.pump();
      expect(_row('47.11B'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search shows the path that tells homonyms apart, and picks', (tester) async {
      String? chosen;
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodePickerField(label: 'Activité', codes: _sample, french: true, value: '', canSelect: _active, onChanged: (code) => chosen = code),
          ),
        ),
      );
      await tester.tap(find.byType(CodePickerField));
      await tester.pumpAndSettle();
      await tester.enterText(_search, 'ALIM');
      await tester.pump();
      expect(_row('01'), findsOneWidget);
      expect(find.text('Agriculture'), findsOneWidget, reason: 'the parent shows as a path');
      expect(find.text('Commerce › Vente de détail › Magasins non spécialisés › À prédominance alimentaire'), findsOneWidget);
      await tester.tap(_row('47.11B'));
      await tester.pumpAndSettle();
      expect(chosen, '47.11B');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an obsolete code cannot be chosen', (tester) async {
      await _pick(tester);
      await tester.enterText(_search, 'Ancien');
      await tester.pump();
      expect(_row('OLD'), findsNothing);
      expect(find.text('Aucun code ne correspond.'), findsOneWidget);
    });

    testWidgets('an obsolete code already chosen stays readable', (tester) async {
      await _pick(tester, value: 'OLD');
      expect(find.textContaining('obsolète'), findsWidgets);
      expect(_row('OLD'), findsOneWidget, reason: 'the tree opens on the chosen code');
    });

    testWidgets('the chosen code shows its path on the field and can be cleared', (tester) async {
      String? chosen = 'unset';
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodePickerField(label: 'Activité', codes: _sample, french: true, value: '47.2', emptyLabel: 'Aucune valeur', onChanged: (code) => chosen = code),
          ),
        ),
      );
      expect(find.text('Commerce › Vente de détail'), findsOneWidget);
      expect(find.text('Épicerie fine (47.2)'), findsOneWidget);
      await tester.tap(find.byType(CodePickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aucune valeur'));
      await tester.pumpAndSettle();
      expect(chosen, '');
    });

    testWidgets('a parent cannot be one of its own descendants', (tester) async {
      final tree = CodeTree.build(_sample, true);
      final excluded = {'47', ...tree.descendantsOf('47')};
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodePickerField(label: 'Parent', codes: _sample, french: true, value: 'G', canSelect: (node) => !excluded.contains(node.code), onChanged: (_) {}),
          ),
        ),
      );
      await tester.tap(find.byType(CodePickerField));
      await tester.pumpAndSettle();
      await tester.enterText(_search, '47.1');
      await tester.pump();
      expect(find.text('Aucun code ne correspond.'), findsOneWidget);
    });

    testWidgets('the code column leaves its width to the label', (tester) async {
      await _pick(tester, value: '47.11B');
      final label = tester.getSize(find.text("Commerce d'alimentation générale").last);
      final code = tester.getSize(find.text('47.11B').last);
      expect(code.width, lessThanOrEqualTo(88));
      expect(label.width, greaterThan(code.width));
    });

    Future<List<String>> keyboardHarness(WidgetTester tester) async {
      final chosen = <String>[];
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodePickerField(label: 'Activité', codes: _sample, french: true, value: '', canSelect: _active, onChanged: chosen.add),
          ),
        ),
      );
      await tester.tap(find.byType(CodePickerField));
      await tester.pumpAndSettle();
      return chosen;
    }

    testWidgets('on desktop the search box takes the focus and the arrows walk the tree', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final chosen = await keyboardHarness(tester);
      final focused = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>();
      expect(focused, isNotNull, reason: 'typing can start at once');
      expect(_row('47'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_row('47'), findsOneWidget, reason: 'right opens the branch');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_row('47.1'), findsOneWidget, reason: 'right moves in, then opens');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_row('47.1'), findsNothing, reason: 'left closes the branch');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['G'], reason: 'left went back to the parent, Enter chose it');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('arrows and Enter choose a search result; Escape closes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final chosen = await keyboardHarness(tester);
      await tester.enterText(_search, 'alim');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['47.11'], reason: 'second result');
      await tester.tap(find.byType(CodePickerField));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(chosen, hasLength(1));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('on mobile the keyboard does not cover the tree on opening', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _pick(tester, width: 700);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNull);
      expect(_row('G'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a wide screen uses a dialog', (tester) async {
      await _pick(tester, width: 1000);
      expect(find.byType(Dialog), findsOneWidget);
      expect(_row('G'), findsOneWidget);
    });

    testWidgets('long paths and enlarged text do not overflow at 320 px', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 800), textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: CodePickerField(label: 'Activité', codes: _sample, french: true, value: '47.11B', onChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CodePickerField));
      await tester.pumpAndSettle();
      await tester.enterText(_search, 'alim');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
