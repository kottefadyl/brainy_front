import 'package:brainy/app_strings.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/entry_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Entry details show who created the entry and, once it was changed, who changed it last.
const _format = BrainyFormat(id: 'f', name: 'Voyage', color: '#EDF9F3', fields: [BrainyField(id: 't', name: 'Titre', kind: BrainyFieldKind.title)]);
const _collection = BrainyCollection(id: 'c', name: 'Liens', fields: [], formats: [_format]);

BrainyEntry _entry({bool edited = false}) => BrainyEntry(
      id: 'e',
      formatId: 'f',
      values: const {'t': 'Test'},
      createdAt: DateTime.utc(2026, 11, 16, 12),
      updatedAt: DateTime.utc(2026, 11, 16, edited ? 14 : 12),
      createdBy: (userId: 'u2', name: 'Bruno', hasPhoto: false),
      updatedBy: (userId: edited ? 'u1' : 'u2', name: edited ? 'Awa' : 'Bruno', hasPhoto: false),
    );

Future<void> _open(WidgetTester tester, BrainyEntry entry, {required double width, required bool dark, String? edited}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: dark ? BrainyTheme.dark : BrainyTheme.light, home: Scaffold(body: Builder(builder: (context) => TextButton(
    onPressed: () => showEntryDetailsDialog(context, collection: _collection, entry: entry, formatName: 'Voyage', created: '16 nov. 2026 12:00', edited: edited, copy: AppStrings('fr'), onCopy: () {}, onReference: (_) {}, onAttachment: (_) {}, onLink: (_) {}),
    child: const Text('open'),
  )))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final (width, dark) in [(390.0, false), (1280.0, true)]) {
    testWidgets('creator only for an entry never changed at $width px', (tester) async {
      await _open(tester, _entry(), width: width, dark: dark);
      expect(find.text('Créée par'), findsOneWidget);
      expect(find.textContaining('Bruno'), findsOneWidget);
      expect(find.text('Dernière modification par'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('creator and last editor for a changed entry at $width px', (tester) async {
      await _open(tester, _entry(edited: true), width: width, dark: dark, edited: '16 nov. 2026 14:00');
      expect(find.text('Créée par'), findsOneWidget);
      expect(find.text('Dernière modification par'), findsOneWidget);
      expect(find.textContaining('Bruno'), findsOneWidget);
      expect(find.textContaining('Awa'), findsOneWidget);
      expect(find.textContaining('14:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
