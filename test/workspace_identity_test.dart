import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/workspace_entry_row.dart';
import 'package:brainy/workspace_format_cards.dart';
import 'package:brainy/workspace_hover_surface.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('French cards at 320 px with enlarged text, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final collection = BrainyCollection.fromJson({
        'id': 'collection',
        'name': 'Mes activités',
        'fields': [],
        'formats': [
          {
            'id': 'format',
            'name': 'Mes observations personnelles',
            'color': '#EEF5FF',
            'fields': [
              for (var i = 0; i < 5; i++)
                {'id': '$i', 'name': 'Champ $i', 'kind': 'TEXT'},
            ],
          },
        ],
      });
      var additions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? BrainyTheme.dark : BrainyTheme.light,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1600),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      WorkspaceEntryRow(
                        color: '#EEF5FF',
                        title: 'Une observation particulièrement longue',
                        formatName: 'Mes observations personnelles',
                        created: '06/11/2026 · 09:15',
                        edited: '06/11/2026 · 10:30',
                        preview: 'Un aperçu lisible',
                        onDetails: () {},
                        onAction: (_) {},
                      ),
                      WorkspaceFormatCards(
                        collection: collection,
                        entryCounts: const {'format': 1},
                        partialCounts: false,
                        onAdd: () {},
                        onAddEntry: (_) => additions++,
                        onEdit: (_) {},
                        onColor: (_) {},
                        onCopy: (_) {},
                        onLink: (_) {},
                        onReview: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Champ 4'), findsNothing);
      await tester.ensureVisible(find.text('2 autres champs'));
      await tester.tap(find.text('2 autres champs'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Champ 4'), findsOneWidget);
      await tester.ensureVisible(find.text('Ajouter une entrée'));
      await tester.tap(find.text('Ajouter une entrée'));
      expect(additions, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Pointer hover lifts the card unless motion is reduced', (
    tester,
  ) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Scaffold(
              body: Center(
                child: WorkspaceHoverSurface(
                  color: Colors.white,
                  marker: Colors.blue,
                  child: Text('Card'),
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Card')));
      await tester.pumpAndSettle();
      final surface = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(WorkspaceHoverSurface),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(surface.transform!.storage[13], reduced ? 0 : -2);
      await mouse.removePointer();
      await tester.pumpAndSettle();
    }
  });
}
