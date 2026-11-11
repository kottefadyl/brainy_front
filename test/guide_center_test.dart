import 'package:brainy/brainy_theme.dart';
import 'package:brainy/guide_center_screen.dart';
import 'package:brainy/guide_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// T51: Guide and training.
Future<void> _pump(WidgetTester tester, Widget home, {double width = 390, bool dark = false, String locale = 'fr'}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: Locale(locale),
    supportedLocales: const [Locale('en'), Locale('fr')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: home,
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('every chapter has English and French texts', () {
    expect(guideChapters.length, 12);
    for (final chapter in guideChapters) {
      for (final text in [chapter.title, chapter.summary, for (final section in chapter.sections) ...[section.title, section.text]]) {
        expect(text.en.trim(), isNotEmpty);
        expect(text.fr.trim(), isNotEmpty);
      }
    }
  });

  test('search keeps chapters containing every word, in the chosen language', () {
    expect(searchGuide('', true).length, guideChapters.length);
    expect(searchGuide('zzzz introuvable', true), isEmpty);
    final stock = searchGuide('stock', true);
    expect(stock, isNotEmpty);
    expect(stock.length, lessThan(guideChapters.length));
  });

  for (final (width, dark) in [(390.0, false), (390.0, true), (1280.0, false), (1280.0, true)]) {
    testWidgets('chapter list and every chapter render at $width px (${dark ? 'dark' : 'light'})', (tester) async {
      await _pump(tester, const GuideCenterScreen(), width: width, dark: dark);
      expect(find.text('Guide et formation'), findsWidgets);
      expect(tester.takeException(), isNull);
      for (var index = 0; index < guideChapters.length; index++) {
        await _pump(tester, GuideChapterScreen(index: index), width: width, dark: dark);
        expect(find.text(guideChapters[index].title.fr), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('search filters chapters and opens a chapter in English', (tester) async {
    await _pump(tester, const GuideCenterScreen(), locale: 'en');
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No chapter matches this search.'), findsOneWidget);
    await tester.tap(find.text('Clear search').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(guideChapters.first.title.en));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1 of ${guideChapters.length}'), findsOneWidget);
  });
}
