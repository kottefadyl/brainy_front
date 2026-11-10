import 'package:brainy/platform_capabilities.dart';
import 'package:brainy/workspace_entry_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openMenu(WidgetTester tester, {required bool reminders}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: Scaffold(
        body: WorkspaceEntryRow(
          color: '#EEF5FF',
          title: 'Une note',
          formatName: 'Notes',
          created: '10/11/2026 · 09:15',
          reminders: reminders,
          onDetails: () {},
          onAction: (_) {},
        ),
      ),
    ),
  );
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
}

void main() {
  test('the attachment limit is written for each language', () {
    const vercel = PlatformCapabilities(frozenModules: {'reminders'}, maxEntryAttachmentBytes: 3 * 1024 * 1024);
    expect(vercel.attachmentLimit(true), '3 Mo');
    expect(vercel.attachmentLimit(false), '3 MB');
    expect(const PlatformCapabilities(frozenModules: {}, maxEntryAttachmentBytes: 2621440).attachmentLimit(true), '2,5 Mo');
    expect(vercel.isFrozen('reminders'), isTrue);
    expect(PlatformCapabilities.full.isFrozen('reminders'), isFalse);
  });

  testWidgets('the entry menu offers reminders only when they run', (tester) async {
    await _openMenu(tester, reminders: true);
    expect(find.text('Rappels'), findsOneWidget);
    await _openMenu(tester, reminders: false);
    expect(find.text('Rappels'), findsNothing);
  });
}
