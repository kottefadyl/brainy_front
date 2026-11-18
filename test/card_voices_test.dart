import 'package:brainy/card_voices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

// T57: voices of this device for the language read aloud; clear message when none; chosen voice and speed used.
class _Tts extends FlutterTts {
  _Tts(this.voices);
  final List<Map<String, String>> voices;
  final calls = <String>[];
  @override
  Future<dynamic> get getVoices async => voices;
  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => calls.add('voice ${voice['name']}');
  @override
  Future<dynamic> setSpeechRate(double rate) async => calls.add('rate $rate');
  @override
  Future<dynamic> setLanguage(String language) async => calls.add('language $language');
  @override
  Future<dynamic> stop() async => 1;
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async => calls.add('speak $text');
}

Future<void> _pump(WidgetTester tester, _Tts tts, String language) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: CardVoiceSettings(tts: tts, memory: CardVoiceMemory.inMemory(), language: language, languageName: 'Espagnol', french: true)))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no voice for the language: a clear message with the way to install one', (tester) async {
    await _pump(tester, _Tts([{'name': 'Amélie', 'locale': 'fr-FR'}]), 'es-ES');
    expect(find.text('Aucune voix « Espagnol » sur cet appareil.'), findsOneWidget);
    expect(find.textContaining('Synthèse vocale', findRichText: true).evaluate().isNotEmpty || find.textContaining('Paramètres').evaluate().isNotEmpty || find.textContaining('réglages').evaluate().isNotEmpty, isTrue);
  });

  testWidgets('the chosen voice and speed are used to read aloud', (tester) async {
    final tts = _Tts([{'name': 'Amélie', 'locale': 'fr-FR'}, {'name': 'Mónica', 'locale': 'es-ES'}, {'name': 'Paulina', 'locale': 'es-MX'}]);
    await _pump(tester, tts, 'es-ES');
    expect(find.text('Voix (sur cet appareil)'), findsOneWidget);
    await tester.tap(find.text('Automatique'));
    await tester.pumpAndSettle();
    expect(find.text('Amélie · fr-FR'), findsNothing, reason: 'only voices of the language');
    await tester.tap(find.text('Paulina · es-MX').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Normale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('× 1,5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Essayer'));
    await tester.pumpAndSettle();
    expect(tts.calls, containsAllInOrder(['language es-ES', 'voice Paulina', 'rate 0.75', 'speak ¡Hola! Así sonarán tus tarjetas.']));
  });

  test('voices of the language, the exact region first', () async {
    final voices = await cardVoicesFor(_Tts([{'name': 'Paulina', 'locale': 'es-MX'}, {'name': 'Mónica', 'locale': 'es_ES'}, {'name': 'Amélie', 'locale': 'fr-FR'}]), 'es-ES');
    expect(voices!.map((voice) => voice.name), ['Mónica', 'Paulina']);
  });
}
