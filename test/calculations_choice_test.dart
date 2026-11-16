import 'package:brainy/brainy_theme.dart';
import 'package:brainy/calculations_choice.dart';
import 'package:brainy/collection_tools_hub.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/workspace_collection_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// Calculations and statistics: a simple collection shows no maths anywhere; the owner switches it in "Manage".
const _format = BrainyFormat(id: 'f', name: 'Note', color: '#EEF5FF', fields: [BrainyField(id: 't', name: 'Titre', kind: BrainyFieldKind.title)]);
BrainyCollection _collection(bool? calculations) => BrainyCollection(id: 'c', name: 'Notes', ownerId: 'me', fields: const [], formats: const [_format], calculations: calculations);

Future<void> _pump(WidgetTester tester, Widget child, {double width = 1280, bool dark = false}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pumpAndSettle();
}

Widget _hub(BrainyCollection collection) => CollectionToolsHub(
      collection: collection, userId: 'me', isFrench: true, isDark: false,
      onStock: () {}, onLedger: () {}, onInsights: () {}, onUnits: () {}, onObjects: () {}, onClassifications: () {}, onSensitivity: () {}, onWorkflow: () {}, onContributions: () {}, onMap: () {},
    );

void main() {
  test('collections saved before the choice existed keep their calculations', () {
    expect(_collection(null).hasCalculations, isTrue);
    expect(_collection(false).hasCalculations, isFalse);
  });

  for (final (width, dark) in [(390.0, false), (1280.0, true)]) {
    testWidgets('tools: no calculations, stock or measures in a simple collection at $width px', (tester) async {
      await _pump(tester, _hub(_collection(false)), width: width, dark: dark);
      await tester.tap(find.text('Outils & options avancées'));
      await tester.pumpAndSettle();
      expect(find.text('Calculs et graphiques'), findsNothing);
      expect(find.text('Stock'), findsNothing);
      expect(find.text('Unités et mesures'), findsNothing);
      expect(find.text('Carte'), findsOneWidget);
      expect(find.text('Cartes, nomenclatures, flux et registre'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tools: everything is there when calculations are on', (tester) async {
    await _pump(tester, _hub(_collection(true)));
    await tester.tap(find.text('Outils & options avancées'));
    await tester.pumpAndSettle();
    expect(find.text('Calculs et graphiques'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Unités et mesures'), findsOneWidget);
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('header: no "Calculs" button when off, and the owner turns it on in Manage at $width px', (tester) async {
      bool? asked;
      await _pump(tester, WorkspaceCollectionHeader(name: 'Notes', entryCount: 2, partialEntryCount: false, formatCount: 1, onNewEntry: () {}, onInsights: () {}, onRename: () {}, onDelete: () {}, calculations: false, onCalculations: (value) => asked = value), width: width);
      expect(find.text('Calculs'), findsNothing);
      await tester.tap(find.text('Gérer'));
      await tester.pumpAndSettle();
      expect(find.text('Non'), findsOneWidget);
      await tester.tap(find.text('Calculs'));
      await tester.pumpAndSettle();
      expect(asked, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('header: "Calculs" is shown when on; a collaborator never gets the switch', (tester) async {
    await _pump(tester, WorkspaceCollectionHeader(name: 'Dépenses', entryCount: 2, partialEntryCount: false, formatCount: 1, onNewEntry: () {}, onInsights: () {}, onRename: () {}, onDelete: () {}, owner: false, calculations: true, onCalculations: (_) {}));
    expect(find.text('Calculs'), findsOneWidget);
    expect(find.text('Gérer'), findsNothing);
  });

  testWidgets('the choice made at creation explains what it means', (tester) async {
    var value = false;
    await _pump(tester, StatefulBuilder(builder: (context, setState) => CalculationsChoice(value: value, french: true, onChanged: (next) => setState(() => value = next))));
    expect(find.textContaining('Collection simple'), findsOneWidget);
    await tester.tap(find.text('Calculs et statistiques'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(find.textContaining('Totaux, formules, graphiques'), findsOneWidget);
  });
}
