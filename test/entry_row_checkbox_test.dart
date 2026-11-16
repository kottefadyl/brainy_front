import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/workspace_entry_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// A yes/no value in the entry list is a checkbox: one tap changes the entry.
Future<void> _pump(WidgetTester tester, Widget row, {required double width, required bool dark}) async {
  tester.view.physicalSize = Size(width, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(12), child: row)),
  ));
  await tester.pumpAndSettle();
}

WorkspaceEntryRow _row({bool checked = false, void Function(String, bool)? onCheck}) => WorkspaceEntryRow(
      color: '#E8F1FF',
      title: 'collaborations/collections',
      formatName: 'Slight modifications corrections',
      created: '16 nov.',
      onDetails: () {},
      onAction: (_) {},
      facts: [(label: 'Set', value: checked ? 'Oui' : 'Non')],
      checkboxes: {'Set': (fieldId: 'set', checked: checked)},
      onCheck: onCheck,
    );

void main() {
  test('only yes/no fields become checkboxes', () {
    const fields = [BrainyField(id: 't', name: 'Title', kind: BrainyFieldKind.title), BrainyField(id: 'set', name: 'Set', kind: BrainyFieldKind.boolean)];
    final entry = BrainyEntry(id: 'e', values: const {'t': 'A', 'set': 'true'}, createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026));
    expect(entryCheckboxes(fields, entry), {'Set': (fieldId: 'set', checked: true)});
  });

  for (final (width, dark) in [(390.0, false), (1280.0, true)]) {
    testWidgets('ticking "Set" sets the entry to yes at $width px', (tester) async {
      final changes = <(String, bool)>[];
      await _pump(tester, _row(onCheck: (field, value) => changes.add((field, value))), width: width, dark: dark);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Non'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      // The row also listens for a double-tap (details): a single tap is settled once that wait is over.
      await tester.pump(kDoubleTapTimeout);
      expect(changes, [('set', true)]);
      await _pump(tester, _row(checked: true, onCheck: (field, value) => changes.add((field, value))), width: width, dark: dark);
      await tester.tap(find.text('Oui'));
      await tester.pump(kDoubleTapTimeout);
      expect(changes.last, ('set', false));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('read only: the box is shown but cannot be changed', (tester) async {
    await _pump(tester, _row(checked: true), width: 390, dark: false);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
