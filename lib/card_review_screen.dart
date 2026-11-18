// T56: review of two-sided cards (same meaning as the web's card-review.tsx). The front is shown, the person turns
// the card, then answers how well they knew it; Brainy schedules when it comes back (spaced repetition, per person).
import 'card_progress.dart';
import 'flip_card.dart';
import 'link_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'collections_api.dart';
import 'data_format_colors.dart';
import 'entry_clipboard.dart';
import 'app_strings.dart';

const flashCardsTemplate = 'cards';
bool isFlashCards(BrainyCollection? collection) => collection?.templateId == flashCardsTemplate;

/// The face a field is on: its own choice, otherwise the title on the front and the rest on the back.
String cardFaceOf(BrainyFieldKind kind, String? face) => face ?? (kind == BrainyFieldKind.title ? 'FRONT' : 'BACK');

typedef CardDeck = ({String formatId, int total, int due, int fresh});
typedef ReviewCard = ({BrainyEntry entry, Map<String, int> preview});

extension FlashCardsApi on CollectionsApi {
  Future<List<CardDeck>> cardDecks(String collectionId) async {
    final data = await auth.authenticatedRequest('query(\$c:String!){cardDecks(collectionId:\$c){formatId total due fresh}}', {'c': collectionId});
    return [for (final item in data['cardDecks'] as List<dynamic>) (formatId: item['formatId'] as String, total: item['total'] as int, due: item['due'] as int, fresh: item['fresh'] as int)];
  }

  Future<List<ReviewCard>> cardSession(String collectionId, String formatId, int count, String order) async {
    final data = await auth.authenticatedRequest(
      'query(\$c:String!,\$f:String!,\$n:Int!,\$o:CardReviewOrder!,\$z:Int){cardReviewSession(collectionId:\$c,formatId:\$f,count:\$n,order:\$o,utcOffsetMinutes:\$z){entry{id formatId createdAt updatedAt values{fieldId value}} preview{again hard good easy}}}',
      {'c': collectionId, 'f': formatId, 'n': count, 'o': order, 'z': cardUtcOffset()},
    );
    return [
      for (final item in data['cardReviewSession'] as List<dynamic>)
        (entry: BrainyEntry.fromJson(item['entry'] as Map<String, dynamic>), preview: (item['preview'] as Map<String, dynamic>).map((key, value) => MapEntry(key.toUpperCase(), value as int))),
    ];
  }

  Future<void> gradeCard(String collectionId, String entryId, String grade) => auth.authenticatedRequest(
        'mutation(\$c:String!,\$e:String!,\$g:CardGrade!,\$z:Int){gradeCard(collectionId:\$c,entryId:\$e,grade:\$g,utcOffsetMinutes:\$z){entryId}}',
        {'c': collectionId, 'e': entryId, 'g': grade, 'z': cardUtcOffset()},
      );

  Future<void> setCardSpeechLanguage(String collectionId, String formatId, String? language) => auth.authenticatedRequest(
        'mutation(\$c:String!,\$f:String!,\$l:String){setCardSpeechLanguage(collectionId:\$c,formatId:\$f,language:\$l){id}}',
        {'c': collectionId, 'f': formatId, 'l': language},
      );
}

/// "10 min", "1 d", "3 mo"… for the hint under an answer button.
String intervalLabel(int minutes, bool french) {
  if (minutes < 60) return '${minutes < 1 ? 1 : minutes} min';
  if (minutes < 1440) return '${(minutes / 60).round()} h';
  final days = (minutes / 1440).round();
  if (days < 30) return french ? '$days j' : '$days d';
  if (days < 365) return french ? '${(days / 30).round()} mois' : '${(days / 30).round()} mo';
  return french ? '${(days / 36.5).round() / 10} an(s)' : '${(days / 36.5).round() / 10} y';
}

const cardSpeechLanguages = [
  ('en-GB', 'English (UK)', 'Anglais (Royaume-Uni)'), ('en-US', 'English (US)', 'Anglais (États-Unis)'), ('fr-FR', 'French', 'Français'), ('es-ES', 'Spanish', 'Espagnol'),
  ('de-DE', 'German', 'Allemand'), ('it-IT', 'Italian', 'Italien'), ('pt-PT', 'Portuguese', 'Portugais'), ('pt-BR', 'Portuguese (Brazil)', 'Portugais (Brésil)'),
  ('nl-NL', 'Dutch', 'Néerlandais'), ('ar-SA', 'Arabic', 'Arabe'), ('zh-CN', 'Chinese', 'Chinois'), ('ja-JP', 'Japanese', 'Japonais'), ('ko-KR', 'Korean', 'Coréen'), ('ru-RU', 'Russian', 'Russe'),
];

/// Front / back choice of a field in the data format editor.
class CardFaceSelector extends StatelessWidget {
  const CardFaceSelector({super.key, required this.value, required this.french, required this.onChanged});
  final String value;
  final bool french;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8, top: 4),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [ButtonSegment(value: 'FRONT', label: Text(french ? 'Recto' : 'Front')), ButtonSegment(value: 'BACK', label: Text(french ? 'Verso' : 'Back'))],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      );
}

/// Summary above the entries: cards to review today, and the button to start.
class CardReviewBanner extends StatefulWidget {
  const CardReviewBanner({super.key, required this.api, required this.collection, required this.onStart});
  final CollectionsApi api;
  final BrainyCollection collection;
  final VoidCallback onStart;
  @override
  State<CardReviewBanner> createState() => _CardReviewBannerState();
}

class _CardReviewBannerState extends State<CardReviewBanner> {
  List<CardDeck>? _decks;
  CardStats? _stats;

  @override
  void initState() {
    super.initState();
    widget.api.cardDecks(widget.collection.id).then((value) { if (mounted) setState(() => _decks = value); }).catchError((Object _) {});
    widget.api.cardStats(widget.collection.id).then((value) { if (mounted) setState(() => _stats = value); }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final scheme = Theme.of(context).colorScheme;
    final decks = _decks;
    final total = decks?.fold<int>(0, (sum, deck) => sum + deck.total) ?? 0;
    final due = decks?.fold<int>(0, (sum, deck) => sum + deck.due) ?? 0;
    final fresh = decks?.fold<int>(0, (sum, deck) => sum + deck.fresh) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(14), color: const Color(0xFF8B5CF6).withValues(alpha: .08)),
      child: Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.style_outlined, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9)),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(fr ? 'Révision' : 'Review', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                decks == null ? (fr ? 'Chargement…' : 'Loading…') : total == 0 ? (fr ? 'Ajoutez des cartes pour commencer à réviser.' : 'Add cards to start reviewing.') : fr ? '$due à revoir aujourd’hui · $fresh nouvelle(s) · $total au total' : '$due due today · $fresh new · $total in all',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (_stats != null && total > 0) Padding(padding: const EdgeInsets.only(top: 4), child: CardGoalLine(stats: _stats!)),
            ]),
          ),
        ]),
        FilledButton.icon(onPressed: total == 0 ? null : widget.onStart, icon: const Icon(Icons.style_outlined), label: Text(fr ? 'Réviser' : 'Review')),
      ]),
    );
  }
}

Future<void> openCardReview(BuildContext context, {required CollectionsApi api, required BrainyCollection collection, required bool owner, Future<void> Function()? onCollectionChanged}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CardReviewScreen(api: api, collection: collection, owner: owner, onCollectionChanged: onCollectionChanged)));

class CardReviewScreen extends StatefulWidget {
  const CardReviewScreen({super.key, required this.api, required this.collection, required this.owner, this.onCollectionChanged, this.tts});
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool owner;
  final Future<void> Function()? onCollectionChanged;
  /// For tests; the device voice otherwise.
  final FlutterTts? tts;
  @override
  State<CardReviewScreen> createState() => _CardReviewScreenState();
}

enum _Phase { setup, review, done }

class _CardReviewScreenState extends State<CardReviewScreen> {
  late String _formatId = widget.collection.formats.first.id;
  late final Map<String, String?> _speech = {for (final format in widget.collection.formats) format.id: format.speechLanguage};
  List<CardDeck>? _decks;
  int _count = 20;
  String _order = 'DUE';
  _Phase _phase = _Phase.setup;
  List<ReviewCard> _queue = [];
  final Set<String> _repeated = {};
  int _index = 0;
  bool _turned = false, _busy = false;
  final Map<String, int> _answers = {'AGAIN': 0, 'HARD': 0, 'GOOD': 0, 'EASY': 0};
  String? _error;
  late final FlutterTts _tts = widget.tts ?? FlutterTts();
  final _focus = FocusNode();

  bool get _fr => AppStrings.of(context).isFrench;
  BrainyFormat get _format => widget.collection.formats.firstWhere((item) => item.id == _formatId, orElse: () => widget.collection.formats.first);
  CardDeck? get _deck => _decks?.where((item) => item.formatId == _format.id).firstOrNull;
  /// T57: my daily limit of new cards caps the new cards of a "due then new" review.
  CardStats? _progress;
  int _sessions = 0;
  int get _available {
    final deck = _deck;
    if (deck == null) return 0;
    if (_order != 'DUE') return deck.total;
    final left = _progress?.newLeft;
    return deck.due + (left == null || left > deck.fresh ? deck.fresh : left);
  }

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  @override
  void dispose() {
    _focus.dispose();
    _tts.stop().catchError((Object _) => null);
    super.dispose();
  }

  Future<void> _loadDecks() async {
    try {
      final decks = await widget.api.cardDecks(widget.collection.id);
      final progress = await widget.api.cardStats(widget.collection.id).then<CardStats?>((value) => value, onError: (Object _) => null);
      if (!mounted) return;
      _progress = progress;
      setState(() {
        _decks = decks;
        if (!decks.any((item) => item.formatId == _formatId && item.total > 0)) _formatId = decks.where((item) => item.total > 0).firstOrNull?.formatId ?? _formatId;
      });
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    }
  }

  Future<void> _start() async {
    setState(() { _busy = true; _error = null; });
    try {
      final cards = await widget.api.cardSession(widget.collection.id, _format.id, _count, _order);
      if (!mounted) return;
      setState(() {
        _queue = cards;
        _index = 0;
        _turned = false;
        _repeated.clear();
        _answers.updateAll((_, _) => 0);
        _phase = cards.isEmpty ? _Phase.done : _Phase.review;
      });
      _focus.requestFocus();
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(String grade) async {
    if (_busy || _index >= _queue.length) return;
    final card = _queue[_index];
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.gradeCard(widget.collection.id, card.entry.id, grade);
      if (!mounted) return;
      setState(() {
        _answers[grade] = (_answers[grade] ?? 0) + 1;
        // A forgotten card comes back once more at the end of this session.
        if (grade == 'AGAIN' && _repeated.add(card.entry.id)) _queue = [..._queue, (entry: card.entry, preview: const {'AGAIN': 10, 'HARD': 1440, 'GOOD': 1440, 'EASY': 5760})];
        if (_index + 1 >= _queue.length) {
          _phase = _Phase.done;
          _sessions++;
          _loadDecks();
        } else {
          _index++;
          _turned = false;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _speak(String text) async {
    final language = _speech[_format.id];
    try {
      await _tts.stop();
      if (language != null) await _tts.setLanguage(language);
      await _tts.speak(text);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_fr ? 'La lecture à voix haute n’est pas disponible sur cet appareil.' : 'Reading aloud is not available on this device.')));
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _phase != _Phase.review) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (!_turned && (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter)) { setState(() => _turned = true); return KeyEventResult.handled; }
    if (_turned) {
      final grade = {LogicalKeyboardKey.digit1: 'AGAIN', LogicalKeyboardKey.digit2: 'HARD', LogicalKeyboardKey.digit3: 'GOOD', LogicalKeyboardKey.digit4: 'EASY', LogicalKeyboardKey.space: 'GOOD'}[key];
      if (grade != null) { _answer(grade); return KeyEventResult.handled; }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final fr = _fr;
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Révision des cartes' : 'Card review')),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                if (_phase == _Phase.setup) _setup(),
                if (_phase == _Phase.review) _session(),
                if (_phase == _Phase.done) _done(),
                if (_phase != _Phase.review) ...[
                  const SizedBox(height: 20),
                  CardProgressPanel(
                    key: ValueKey('progress-${_format.id}-$_sessions-${_phase.name}'),
                    api: widget.api,
                    collectionId: widget.collection.id,
                    formatId: widget.collection.formats.length > 1 ? _format.id : null,
                    formatName: widget.collection.formats.length > 1 ? _format.name : null,
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _setup() {
    final fr = _fr;
    final deck = _deck;
    final count = _available < _count ? _available : _count;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(fr ? 'Préparer une révision' : 'Set up a review', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      if (widget.collection.formats.length > 1) ...[
        DropdownButtonFormField<String>(
          initialValue: _format.id,
          isExpanded: true,
          decoration: InputDecoration(labelText: fr ? 'Format de données' : 'Data format', border: const OutlineInputBorder()),
          items: [for (final format in widget.collection.formats) DropdownMenuItem(value: format.id, child: Text(format.name, overflow: TextOverflow.ellipsis))],
          onChanged: (value) => setState(() => _formatId = value ?? _formatId),
        ),
        const SizedBox(height: 12),
      ],
      DropdownButtonFormField<String>(
        initialValue: _order,
        isExpanded: true,
        decoration: InputDecoration(labelText: fr ? 'Ordre' : 'Order', border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem(value: 'DUE', child: Text(fr ? 'À revoir aujourd’hui, puis nouvelles' : 'Due today, then new cards', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: 'OLDEST', child: Text(fr ? 'De la plus ancienne à la plus récente' : 'Oldest to newest', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: 'NEWEST', child: Text(fr ? 'De la plus récente à la plus ancienne' : 'Newest to oldest', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: 'RANDOM', child: Text(fr ? 'Au hasard' : 'Random')),
        ],
        onChanged: (value) => setState(() => _order = value ?? 'DUE'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: _count,
        isExpanded: true,
        decoration: InputDecoration(labelText: fr ? 'Nombre de cartes' : 'Number of cards', border: const OutlineInputBorder()),
        items: [for (final value in const [5, 10, 20, 50, 100, 200]) DropdownMenuItem(value: value, child: Text(value == 200 ? (fr ? 'Toutes (200 au plus)' : 'All (up to 200)') : '$value'))],
        onChanged: (value) => setState(() => _count = value ?? 20),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _speech[_format.id] ?? '',
        isExpanded: true,
        decoration: InputDecoration(labelText: fr ? 'Lecture à voix haute' : 'Read aloud', border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem(value: '', child: Text(fr ? 'Langue de l’appareil' : 'Device language')),
          for (final (code, en, frLabel) in cardSpeechLanguages) DropdownMenuItem(value: code, child: Text(fr ? frLabel : en)),
        ],
        onChanged: !widget.owner ? null : (value) async {
          final language = value == null || value.isEmpty ? null : value;
          setState(() => _speech[_format.id] = language);
          try {
            await widget.api.setCardSpeechLanguage(widget.collection.id, _format.id, language);
            await widget.onCollectionChanged?.call();
          } catch (error) {
            if (mounted) setState(() => _error = AppStrings.of(context).error(error));
          }
        },
      ),
      const SizedBox(height: 12),
      Text(deck == null ? (fr ? 'Chargement…' : 'Loading…') : fr ? '${deck.due} à revoir aujourd’hui · ${deck.fresh} nouvelle(s) · ${deck.total} au total' : '${deck.due} due today · ${deck.fresh} new · ${deck.total} in all', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _busy || _available == 0 ? null : _start,
          icon: const Icon(Icons.style_outlined),
          label: Text(_available == 0 ? (fr ? 'Rien à revoir pour l’instant' : 'Nothing to review right now') : (fr ? 'Commencer ($count)' : 'Start ($count)')),
        ),
      ),
    ]);
  }

  Widget _session() {
    final fr = _fr;
    final card = _queue[_index];
    final format = _format;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final front = format.fields.where((field) => cardFaceOf(field.kind, field.face) == 'FRONT').toList();
    final back = format.fields.where((field) => cardFaceOf(field.kind, field.face) == 'BACK').toList();
    final grades = [('AGAIN', fr ? 'À revoir' : 'Again', const Color(0xFFDC2626)), ('HARD', fr ? 'Difficile' : 'Hard', const Color(0xFFD97706)), ('GOOD', fr ? 'Bien' : 'Good', const Color(0xFF16A34A)), ('EASY', fr ? 'Facile' : 'Easy', const Color(0xFF2563EB))];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        liveRegion: true,
        child: Row(children: [
          Text(fr ? 'Carte ${_index + 1} sur ${_queue.length}' : 'Card ${_index + 1} of ${_queue.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: _index / _queue.length, minHeight: 6, color: const Color(0xFF8B5CF6)))),
        ]),
      ),
      const SizedBox(height: 14),
      FlipCard(
        key: ValueKey('${card.entry.id}-$_index'),
        turned: _turned,
        onTurn: () => setState(() => _turned = true),
        decoration: BoxDecoration(
          color: DataFormatColors.surface(format.color, dark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DataFormatColors.marker(format.color, dark).withValues(alpha: .35)),
        ),
        front: _face(fr ? 'RECTO' : 'FRONT', front, card.entry),
        back: _face(fr ? 'VERSO' : 'BACK', back, card.entry),
      ),
      const SizedBox(height: 16),
      if (!_turned)
        Center(child: FilledButton.icon(onPressed: () => setState(() => _turned = true), icon: const Icon(Icons.flip_outlined), label: Text(fr ? 'Retourner la carte' : 'Turn the card')))
      else
        LayoutBuilder(builder: (context, constraints) {
          final perRow = constraints.maxWidth < 480 ? 2 : 4;
          final width = (constraints.maxWidth - (perRow - 1) * 8) / perRow;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (grade, label, color) in grades)
              SizedBox(
                width: width,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _answer(grade),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 60), side: BorderSide(color: color.withValues(alpha: .6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: dark ? Color.lerp(color, Colors.white, .45) : color)),
                    Text(intervalLabel(card.preview[grade] ?? 0, fr), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                ),
              ),
          ]);
        }),
    ]);
  }

  Widget _face(String label, List<BrainyField> fields, BrainyEntry entry) {
    final fr = _fr;
    final scheme = Theme.of(context).colorScheme;
    final copy = AppStrings.of(context);
    final filled = fields.where((field) => (entry.values[field.id] ?? '').trim().isNotEmpty).toList();
    final spoken = filled.where((field) => const [BrainyFieldKind.title, BrainyFieldKind.text, BrainyFieldKind.longText].contains(field.kind)).map((field) => entry.values[field.id]!).join('. ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1))),
        if (spoken.isNotEmpty) TextButton.icon(onPressed: () => _speak(spoken), icon: const Icon(Icons.volume_up_outlined, size: 18), label: Text(fr ? 'Écouter' : 'Listen')),
      ]),
      if (filled.isEmpty) Text(fr ? 'Rien sur cette face.' : 'Nothing on this side.', style: TextStyle(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
      for (final field in filled)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Builder(builder: (context) {
            final value = entry.values[field.id]!;
            if (field.kind == BrainyFieldKind.title) return Text(value, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(field.name, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              if (field.kind == BrainyFieldKind.link)
                LinkMediaView(
                  url: value,
                  french: fr,
                  probe: true,
                  fallback: Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new, size: 18), label: Text(value, overflow: TextOverflow.ellipsis))),
                )
              else
                Text(displayEntryValue(field, value, copy, collection: widget.collection), style: const TextStyle(fontSize: 16, height: 1.5)),
            ]);
          }),
        ),
    ]);
  }

  Widget _done() {
    final fr = _fr;
    final known = (_answers['GOOD'] ?? 0) + (_answers['EASY'] ?? 0);
    return Column(children: [
      const SizedBox(height: 12),
      CircleAvatar(radius: 28, backgroundColor: const Color(0xFF16A34A).withValues(alpha: .16), child: const Icon(Icons.check, color: Color(0xFF15803D), size: 28)),
      const SizedBox(height: 12),
      Text(_queue.isEmpty ? (fr ? 'Rien à revoir pour l’instant' : 'Nothing to review right now') : (fr ? 'Révision terminée' : 'Review finished'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      if (_queue.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(fr ? '$known bien su(s) · ${_answers['HARD']} difficile(s) · ${_answers['AGAIN']} à revoir' : '$known known · ${_answers['HARD']} hard · ${_answers['AGAIN']} to see again'),
      ],
      const SizedBox(height: 8),
      Text(fr ? 'Chaque carte reviendra au bon moment : plus vous la connaissez, plus elle revient tard.' : 'Each card comes back at the right time: the better you know it, the later it returns.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, children: [
        OutlinedButton(onPressed: () => setState(() => _phase = _Phase.setup), child: Text(fr ? 'Nouvelle révision' : 'New review')),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(fr ? 'Terminer' : 'Finish')),
      ]),
    ]);
  }
}
