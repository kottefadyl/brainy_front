// T57: read-aloud voices of two-sided cards (same meaning as the web's card-voices.ts). Only the voices installed on
// this device are used; the chosen voice and speed are remembered on this device, per language.
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';

typedef CardVoice = ({String name, String locale});
typedef VoiceChoice = ({String? voice, double rate});

const cardSpeechRates = [0.6, 0.8, 1.0, 1.25, 1.5];
const _key = 'brainy_card_voices';

/// The language read aloud: the data format's choice, otherwise the device's.
String speechLanguageOf(String? language) => language ?? PlatformDispatcher.instance.locale.toLanguageTag();

bool _sameLanguage(String locale, String language) => locale.replaceAll('_', '-').toLowerCase().split('-').first == language.toLowerCase().split('-').first;

/// Voices of this device for [language], the exact region first; empty when it has none, null when it cannot tell.
Future<List<CardVoice>?> cardVoicesFor(FlutterTts tts, String language) async {
  try {
    final raw = await tts.getVoices.timeout(const Duration(seconds: 3));
    final voices = <CardVoice>[
      for (final item in (raw as List<dynamic>? ?? const []))
        if (item is Map && item['name'] != null && item['locale'] != null && _sameLanguage('${item['locale']}', language)) (name: '${item['name']}', locale: '${item['locale']}'),
    ];
    final exact = language.toLowerCase();
    voices.sort((a, b) {
      final rank = (b.locale.replaceAll('_', '-').toLowerCase() == exact ? 1 : 0) - (a.locale.replaceAll('_', '-').toLowerCase() == exact ? 1 : 0);
      return rank != 0 ? rank : a.name.compareTo(b.name);
    });
    return voices;
  } catch (_) {
    return null;
  }
}

/// The voice and speed chosen on this device, per language.
class CardVoiceMemory {
  CardVoiceMemory({this.storage = const FlutterSecureStorage()});
  /// Kept only while the app is open (tests, devices without secure storage).
  CardVoiceMemory.inMemory() : storage = const FlutterSecureStorage(), _all = {}, _volatile = true;
  bool _volatile = false;
  final FlutterSecureStorage storage;
  Map<String, dynamic>? _all;

  Future<Map<String, dynamic>> _load() async {
    if (_all != null) return _all!;
    try {
      final raw = await storage.read(key: _key).timeout(const Duration(seconds: 1));
      _all = raw == null ? {} : (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      _all = {};
    }
    return _all!;
  }

  Future<VoiceChoice> read(String language) async {
    final item = (await _load())[language];
    if (item is! Map) return (voice: null, rate: 1.0);
    return (voice: item['voice'] as String?, rate: (item['rate'] as num?)?.toDouble() ?? 1.0);
  }

  Future<void> save(String language, VoiceChoice choice) async {
    final all = await _load();
    all[language] = {'voice': choice.voice, 'rate': choice.rate};
    if (_volatile) return;
    try {
      await storage.write(key: _key, value: jsonEncode(all)).timeout(const Duration(seconds: 1));
    } catch (_) {
      // Storage unavailable: the choice lasts while the app is open.
    }
  }
}

/// Speaks [text] with this device's voice for [language] (the chosen one if any) and the chosen speed.
Future<void> speakCard(FlutterTts tts, CardVoiceMemory memory, String text, String? language) async {
  final lang = speechLanguageOf(language);
  final choice = await memory.read(lang);
  await tts.stop();
  await tts.setLanguage(lang);
  final voices = await cardVoicesFor(tts, lang);
  final voice = voices?.where((item) => item.name == choice.voice).firstOrNull ?? voices?.firstOrNull;
  if (voice != null) await tts.setVoice({'name': voice.name, 'locale': voice.locale});
  // flutter_tts: 0.5 is the normal speed on every platform.
  await tts.setSpeechRate((0.5 * choice.rate).clamp(0.0, 1.0));
  await tts.speak(text);
}

/// Where to install a voice, for the device in use.
String installVoiceHelp(bool fr) {
  final os = kIsWeb ? '' : Platform.operatingSystem;
  switch (os) {
    case 'android':
      return fr ? 'Sur Android : Paramètres › Système › Langues › Synthèse vocale, puis installez les données vocales de la langue (Services vocaux de Google).' : 'On Android: Settings › System › Languages › Text-to-speech output, then install the voice data for the language (Speech Services by Google).';
    case 'ios':
      return fr ? 'Sur iPhone ou iPad : Réglages › Accessibilité › Contenu énoncé › Voix, puis téléchargez une voix de la langue.' : 'On iPhone or iPad: Settings › Accessibility › Spoken Content › Voices, then download a voice for the language.';
    case 'macos':
      return fr ? 'Sur Mac : Réglages Système › Accessibilité › Contenu énoncé › Voix du système › Gérer les voix.' : 'On Mac: System Settings › Accessibility › Spoken Content › System voice › Manage Voices.';
    case 'windows':
      return fr ? 'Sur Windows : Paramètres › Heure et langue › Voix › Ajouter des voix, puis rouvrez Brainy.' : 'On Windows: Settings › Time & language › Speech › Add voices, then reopen Brainy.';
    default:
      return fr ? 'Installez une voix de cette langue dans les réglages de synthèse vocale de votre appareil.' : "Install a voice for this language in your device's text-to-speech settings.";
  }
}

const _samples = {'en': 'Hello! This is how your cards will sound.', 'fr': 'Bonjour ! Voici la voix de vos cartes.', 'es': '¡Hola! Así sonarán tus tarjetas.', 'de': 'Hallo! So klingen deine Karten.', 'it': 'Ciao! Ecco la voce delle tue carte.', 'pt': 'Olá! Assim soarão os seus cartões.', 'nl': 'Hallo! Zo klinken je kaarten.', 'ar': 'مرحبا! هكذا ستبدو بطاقاتك.', 'zh': '你好！这是你的卡片的声音。', 'ja': 'こんにちは！カードの声です。', 'ko': '안녕하세요! 카드의 목소리입니다.', 'ru': 'Привет! Так будут звучать ваши карточки.'};

/// Voice and speed for the language read aloud; a clear message when this device has no voice for it.
class CardVoiceSettings extends StatefulWidget {
  const CardVoiceSettings({super.key, required this.tts, required this.memory, required this.language, required this.languageName, required this.french});
  final FlutterTts tts;
  final CardVoiceMemory memory;
  final String? language;
  final String? languageName;
  final bool french;

  @override
  State<CardVoiceSettings> createState() => _CardVoiceSettingsState();
}

class _CardVoiceSettingsState extends State<CardVoiceSettings> {
  List<CardVoice>? _voices;
  VoiceChoice _choice = (voice: null, rate: 1.0);

  String get _lang => speechLanguageOf(widget.language);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CardVoiceSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) _load();
  }

  Future<void> _load() async {
    final lang = _lang;
    final voices = await cardVoicesFor(widget.tts, lang);
    final choice = await widget.memory.read(lang);
    // A device that cannot list its voices shows nothing here (reading aloud still tries).
    if (mounted && lang == _lang) setState(() { _voices = voices; _choice = choice; });
  }

  void _update(VoiceChoice choice) {
    setState(() => _choice = choice);
    widget.memory.save(_lang, choice);
  }

  @override
  Widget build(BuildContext context) {
    final fr = widget.french;
    final scheme = Theme.of(context).colorScheme;
    final voices = _voices;
    if (voices == null) return const SizedBox.shrink();
    if (voices.isEmpty) {
      final name = widget.languageName ?? _lang;
      return Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD97706).withValues(alpha: .5)), color: const Color(0xFFF59E0B).withValues(alpha: .1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fr ? 'Aucune voix « $name » sur cet appareil.' : 'No “$name” voice on this device.', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('${fr ? 'La lecture utiliserait une autre langue ou resterait muette. ' : 'Reading would use another language or stay silent. '}${installVoiceHelp(fr)}', style: TextStyle(color: scheme.onSurfaceVariant)),
          ]),
        ),
      );
    }
    final voiceField = DropdownButtonFormField<String>(
      key: ValueKey('voice-$_lang-${_choice.voice}'),
      initialValue: voices.any((item) => item.name == _choice.voice) ? _choice.voice : '',
      isExpanded: true,
      decoration: InputDecoration(labelText: fr ? 'Voix (sur cet appareil)' : 'Voice (on this device)', border: const OutlineInputBorder()),
      items: [
        DropdownMenuItem(value: '', child: Text(fr ? 'Automatique' : 'Automatic')),
        for (final voice in voices) DropdownMenuItem(value: voice.name, child: Text('${voice.name} · ${voice.locale}', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (value) => _update((voice: value == null || value.isEmpty ? null : value, rate: _choice.rate)),
    );
    final rateField = DropdownButtonFormField<double>(
      key: ValueKey('rate-$_lang-${_choice.rate}'),
      initialValue: cardSpeechRates.contains(_choice.rate) ? _choice.rate : 1.0,
      isExpanded: true,
      decoration: InputDecoration(labelText: fr ? 'Vitesse' : 'Speed', border: const OutlineInputBorder()),
      items: [for (final rate in cardSpeechRates) DropdownMenuItem(value: rate, child: Text(rate == 1.0 ? (fr ? 'Normale' : 'Normal') : '× ${fr ? '$rate'.replaceAll('.', ',') : '$rate'}'))],
      onChanged: (value) => _update((voice: _choice.voice, rate: value ?? 1.0)),
    );
    final tryButton = OutlinedButton.icon(
      onPressed: () => speakCard(widget.tts, widget.memory, _samples[_lang.split('-').first.toLowerCase()] ?? '1, 2, 3', _lang).catchError((Object _) {}),
      icon: const Icon(Icons.volume_up_outlined, size: 18),
      label: Text(fr ? 'Essayer' : 'Try'),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 520) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          voiceField,
          const SizedBox(height: 10),
          Row(children: [Expanded(child: rateField), const SizedBox(width: 10), tryButton]),
        ]);
      }
      return Row(children: [Expanded(flex: 2, child: voiceField), const SizedBox(width: 10), Expanded(child: rateField), const SizedBox(width: 10), tryButton]);
    });
  }
}
