import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// T52: "Mine | Shared" tabs in the navigation, so shared collections are one tap away.
BrainyCollection _collection(String id, String name, {String? owner}) => BrainyCollection.fromJson({
      'id': id,
      'name': name,
      'fields': [],
      'formats': [{'id': 'f-$id', 'name': 'Note', 'color': '#EEF5FF', 'fields': [{'id': 't', 'name': 'Titre', 'kind': 'TITLE'}]}],
      'members': [],
      'sharedBy': owner == null ? null : {'userId': 'u-$owner', 'name': owner},
    });

final _collections = [
  for (var index = 0; index < 28; index++) _collection('m$index', 'Collection $index'),
  _collection('s1', 'Courses de la famille', owner: 'Awa Diallo'),
  _collection('s2', 'Voyage à Kribi', owner: 'Bruno Kamga'),
];

Future<void> _pump(WidgetTester tester, {String? selectedId, bool dark = false, double width = 320}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: Scaffold(
      body: SizedBox(
        width: width < 400 ? width : 280,
        child: WorkspaceNavigation(
          collections: _collections,
          selectedId: selectedId,
          userName: 'Kevin',
          userEmail: 'kevin@example.test',
          onSelect: (_) {},
          onCreate: () {},
          onManual: () {},
          onTransfer: () {},
          onTools: () {},
          onSignOut: () {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 1280.0]) {
      testWidgets('shared collections are one tap away at $width px (${dark ? 'dark' : 'light'})', (tester) async {
        await _pump(tester, dark: dark, width: width);
        expect(find.text('À moi'), findsOneWidget);
        expect(find.text('Partagées'), findsOneWidget);
        expect(find.text('Voyage à Kribi'), findsNothing);
        await tester.tap(find.text('Partagées'));
        await tester.pumpAndSettle();
        expect(find.text('Courses de la famille'), findsOneWidget);
        expect(find.text('Voyage à Kribi'), findsOneWidget);
        expect(find.text('Collection 0'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('an open shared collection shows the shared tab first', (tester) async {
    await _pump(tester, selectedId: 's2');
    expect(find.text('Voyage à Kribi'), findsOneWidget);
    expect(find.text('Collection 0'), findsNothing);
  });

  testWidgets('without shared collections there are no tabs', (tester) async {
    _collections.removeWhere((item) => item.sharedBy != null);
    await _pump(tester);
    expect(find.text('Partagées'), findsNothing);
    expect(find.text('Collection 0'), findsOneWidget);
  });
}
