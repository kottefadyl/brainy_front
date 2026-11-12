import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/spreadsheet_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthApi {
  final requests = <Map<String, dynamic>>[];
  final queries = <String>[];

  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    queries.add(query);
    requests.add(variables);
    if (query.contains('updateEntry') || query.contains('createEntry')) {
      final input = variables['input'] as Map<String, dynamic>;
      return {
        query.contains('updateEntry') ? 'updateEntry' : 'createEntry': {
          'id': query.contains('updateEntry') ? variables['id'] : 'new',
          'formatId': 'f',
          'values': input['values'],
          'createdAt': '2026-11-09T10:00:00Z',
          'updatedAt': '2026-11-10T10:00:00Z',
        },
      };
    }
    throw StateError('Unexpected query: $query');
  }
}

const _format = BrainyFormat(id: 'f', name: 'Dépense', color: '#EDF9F3', fields: [
  BrainyField(id: 't', name: 'Libellé', kind: BrainyFieldKind.title),
  BrainyField(id: 'a', name: 'Montant', kind: BrainyFieldKind.number, unit: 'FCFA'),
  BrainyField(id: 'p', name: 'Payé', kind: BrainyFieldKind.boolean),
]);
const _collection = BrainyCollection(id: 'c', name: 'Feuille', fields: [], formats: [_format]);

BrainyEntry _entry(String id, Map<String, String> values) => BrainyEntry(id: id, formatId: 'f', values: values, createdAt: DateTime.utc(2026, 11, 3), updatedAt: DateTime.utc(2026, 11, 3));

Future<({_Auth auth, List<BrainyEntry> saved})> _pump(WidgetTester tester, {Locale locale = const Locale('en'), String viewId = 'v', Size size = const Size(1280, 900), bool turnOn = true}) async {
  final auth = _Auth();
  final saved = <BrainyEntry>[];
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: SingleChildScrollView(child: SavedViewTable(
      api: CollectionsApi(auth),
      collection: _collection,
      view: {'id': viewId, 'layout': 'TABLE', 'formatIds': const ['f'], 'columnFieldIds': const ['t', 'a']},
      entries: [_entry('e1', {'t': 'Déjeuner', 'a': '4500', 'p': 'false'}), _entry('e2', {'t': 'Taxi', 'a': '2500'})],
      onOpenEntry: (_) {},
      onEntrySaved: saved.add,
      onCollectionChanged: (_) {},
      onEditFormat: (_) {},
    ))),
  ));
  await tester.pumpAndSettle();
  // The on/off choice is remembered per view, so turn it on only when needed.
  if (turnOn && find.byKey(const Key('spreadsheet-add-row')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('spreadsheet-switch')));
    await tester.pumpAndSettle();
  }
  return (auth: auth, saved: saved);
}

List<Map<String, dynamic>> _sentValues(_Auth auth) => ((auth.requests.last['input'] as Map<String, dynamic>)['values'] as List<dynamic>).cast<Map<String, dynamic>>();

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'brainy.spreadsheet.restarted': 'on'}));

  testWidgets('the mode chosen before a restart is restored, and a change is saved on the device', (tester) async {
    await _pump(tester, viewId: 'restarted', turnOn: false);
    expect(find.byKey(const Key('spreadsheet-add-row')), findsOneWidget, reason: 'the stored "on" opens the sheet directly');
    await tester.tap(find.byKey(const Key('spreadsheet-switch')));
    await tester.pumpAndSettle();
    expect(await const FlutterSecureStorage().read(key: 'brainy.spreadsheet.restarted'), 'off');
  });

  testWidgets('row numbers stay in place while the cells scroll sideways', (tester) async {
    await _pump(tester, viewId: 'narrow', size: const Size(320, 800));
    final numbers = find.byKey(const Key('spreadsheet-row-numbers'));
    final before = tester.getTopLeft(numbers);
    final firstCell = tester.getTopLeft(find.byKey(const Key('sheet-cell-0-0')));
    await tester.drag(find.byKey(const Key('sheet-cell-0-1')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(numbers), before, reason: 'the number column does not move');
    expect(tester.getTopLeft(find.byKey(const Key('sheet-cell-0-0'))).dx, lessThan(firstCell.dx), reason: 'the cells did scroll');
    expect(find.text('1'), findsOneWidget, reason: 'row 1 is still numbered on screen');
  });

  group('cell rules', () {
    const number = BrainyField(id: 'n', name: 'N', kind: BrainyFieldKind.number);
    test('a French decimal is stored with a point and refused when not a number', () {
      expect(sheetStored(number, '1 500,5').value, '1500.5');
      expect(sheetStored(number, 'abc', french: true).error, contains('nombre'));
      expect(sheetEditable(number, '1500.5', true), '1500,5');
    });
    test('durations, links, characters and choices follow the entry form', () {
      expect(sheetStored(const BrainyField(id: 'd', name: 'D', kind: BrainyFieldKind.duration), '1:30').error, isNull);
      expect(sheetStored(const BrainyField(id: 'd', name: 'D', kind: BrainyFieldKind.duration), '90').error, isNotNull);
      expect(sheetStored(const BrainyField(id: 'l', name: 'L', kind: BrainyFieldKind.link), 'ftp://x').error, isNotNull);
      expect(sheetStored(const BrainyField(id: 'c', name: 'C', kind: BrainyFieldKind.character), 'ab').error, isNotNull);
      expect(sheetStored(const BrainyField(id: 's', name: 'S', kind: BrainyFieldKind.select, options: ['A', 'B']), 'C').error, isNotNull);
      expect(sheetStored(number, '').value, '', reason: 'an empty cell clears the value');
    });
    test('a workflow state and complex kinds open the full form', () {
      const workflow = BrainyFormat(id: 'w', name: 'W', color: '#FFF', fields: [BrainyField(id: 's', name: 'State', kind: BrainyFieldKind.select)], workflow: {'stateFieldId': 's'});
      expect(sheetEditorFor(workflow.fields.first, workflow), SheetEditor.none);
      expect(sheetEditorFor(const BrainyField(id: 'x', name: 'X', kind: BrainyFieldKind.attachment), _format), SheetEditor.none);
    });
    test('a new number column needs an explicit unit and keeps the existing fields', () {
      expect(sheetColumnProblem(_format, name: 'Quantité', kind: BrainyFieldKind.number, unitChoice: null, french: false), contains('unit'));
      expect(sheetColumnProblem(_format, name: 'montant', kind: BrainyFieldKind.text, unitChoice: null, french: false), contains('already'));
      expect(sheetColumnProblem(_format, name: 'Quantité', kind: BrainyFieldKind.number, unitChoice: 'none', french: false), isNull);
      final fields = sheetFieldsWithColumn(_format, name: 'Quantité', kind: BrainyFieldKind.number, unit: 'kg');
      expect(fields.length, 4);
      expect(fields[1], {'id': 'a', 'name': 'Montant', 'kind': 'NUMBER', 'unit': 'FCFA'});
      expect(fields.last, {'name': 'Quantité', 'kind': 'NUMBER', 'unit': 'kg'});
    });
  });

  testWidgets('the switch shows the sheet with every field of the data format', (tester) async {
    await _pump(tester);
    expect(find.text('Payé'), findsOneWidget, reason: 'all fields are columns, not only the view columns');
    expect(find.byKey(const Key('spreadsheet-add-row')), findsOneWidget);
  });

  testWidgets('typing in a selected cell edits it and keeps the other values', (tester) async {
    final result = await _pump(tester, locale: const Locale('fr'));
    await tester.tap(find.byKey(const Key('sheet-cell-0-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sheet-cell-0-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spreadsheet-editor')), '1500,5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result.auth.queries.last, contains('updateEntry'));
    final values = _sentValues(result.auth);
    expect(values.firstWhere((item) => item['fieldId'] == 'a')['value'], '1500.5');
    expect(values.firstWhere((item) => item['fieldId'] == 't')['value'], 'Déjeuner', reason: 'the other values are sent back unchanged');
    expect(result.saved.single.values['a'], '1500.5');
  });

  testWidgets('an invalid number is refused and Escape cancels', (tester) async {
    final result = await _pump(tester, locale: const Locale('fr'));
    await tester.tap(find.byKey(const Key('sheet-cell-1-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sheet-cell-1-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spreadsheet-editor')), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('nombre valide'), findsOneWidget);
    expect(result.auth.requests, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('spreadsheet-editor')), findsNothing);
  });

  testWidgets('a yes/no cell toggles with one tap', (tester) async {
    final result = await _pump(tester);
    await tester.tap(find.byKey(const Key('sheet-cell-0-2')));
    await tester.pumpAndSettle();
    expect(_sentValues(result.auth).firstWhere((item) => item['fieldId'] == 'p')['value'], 'true');
  });

  testWidgets('a new row creates an entry of the sheet data format', (tester) async {
    final result = await _pump(tester);
    await tester.tap(find.byKey(const Key('spreadsheet-add-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spreadsheet-editor')), 'Pharmacie');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result.auth.queries.last, contains('createEntry'));
    expect((result.auth.requests.last['input'] as Map<String, dynamic>)['formatId'], 'f');
    expect(result.saved.single.values['t'], 'Pharmacie');
  });

  testWidgets('adding a number column asks for the unit first', (tester) async {
    final result = await _pump(tester);
    await tester.tap(find.byKey(const Key('spreadsheet-add-column')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('column-name')), 'Quantité');
    await tester.tap(find.byKey(const Key('column-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Number').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('column-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('column-error')), findsOneWidget);
    expect(result.auth.requests, isEmpty, reason: 'nothing is saved without a unit choice');
  });

  // T46/1: sort, paste of a range with a new row, fill down.
  testWidgets('a column title sorts the rows, then reverses, then restores the order', (tester) async {
    await _pump(tester, viewId: 'sorted');
    String firstTitle() => tester.widget<Text>(find.descendant(of: find.byKey(const Key('sheet-cell-0-0')), matching: find.byType(Text))).data ?? '';
    expect(firstTitle(), 'Déjeuner');
    await tester.tap(find.byKey(const Key('sheet-sort-a')));
    await tester.pumpAndSettle();
    expect(firstTitle(), 'Taxi', reason: '2500 before 4500');
    await tester.tap(find.byKey(const Key('sheet-sort-a')));
    await tester.pumpAndSettle();
    expect(firstTitle(), 'Déjeuner');
  });

  testWidgets('pasted text fills cells from the selection and adds rows below', (tester) async {
    final result = await _pump(tester, viewId: 'paste');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => call.method == 'Clipboard.getData' ? {'text': '1200\n800\n300'} : null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(const Key('sheet-cell-0-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spreadsheet-paste')));
    await tester.pumpAndSettle();
    expect(result.saved.map((entry) => entry.values['a']), ['1200', '800', '300']);
    expect(result.saved.first.values['t'], 'Déjeuner', reason: 'other values are kept');
    expect(result.auth.queries.where((query) => query.contains('createEntry')).length, 1, reason: 'the third line becomes a new row');
  });

  testWidgets('fill down copies the first selected row into the rows below', (tester) async {
    final result = await _pump(tester, viewId: 'fill');
    await tester.tap(find.byKey(const Key('sheet-cell-0-1')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('sheet-cell-1-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spreadsheet-fill-down')));
    await tester.pumpAndSettle();
    expect(result.saved.single.values['a'], '4500');
    expect(result.saved.single.values['t'], 'Taxi');
  });
}
