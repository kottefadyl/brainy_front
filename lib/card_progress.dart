// T57: my learning progress on two-sided cards (same meaning as the web's card-progress.tsx) — daily goal,
// statistics and the cards I forget most. Personal learning figures: shown even when "Calculations and statistics" is off.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_strings.dart';
import 'collections_api.dart';

/// Minutes east of UTC: days, goals and streaks follow the person's own clock.
int cardUtcOffset() => DateTime.now().timeZoneOffset.inMinutes;

class CardStats {
  const CardStats({required this.total, required this.fresh, required this.learning, required this.mature, required this.reviewed7, required this.reviewed30, required this.successRate30, required this.days, required this.forecast, required this.hardest, required this.reviewedToday, required this.newToday, required this.goal, required this.newLimit, required this.streak});

  final int total, fresh, learning, mature, reviewed7, reviewed30;
  final double? successRate30;
  final List<({String day, int answers, int remembered})> days;
  final List<int> forecast;
  final List<({String entryId, String title, int forgotten})> hardest;
  final int reviewedToday, newToday, streak;
  final int? goal, newLimit;

  /// New cards a "due then new" review may still show today (null = no limit).
  int? get newLeft => newLimit == null ? null : math.max(0, newLimit! - newToday);

  factory CardStats.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>;
    return CardStats(
      total: json['total'] as int,
      fresh: json['fresh'] as int,
      learning: json['learning'] as int,
      mature: json['mature'] as int,
      reviewed7: json['reviewed7'] as int,
      reviewed30: json['reviewed30'] as int,
      successRate30: (json['successRate30'] as num?)?.toDouble(),
      days: [for (final item in json['days'] as List<dynamic>) (day: item['day'] as String, answers: item['answers'] as int, remembered: item['remembered'] as int)],
      forecast: [for (final item in json['forecast'] as List<dynamic>) item as int],
      hardest: [for (final item in json['hardest'] as List<dynamic>) (entryId: item['entryId'] as String, title: item['title'] as String, forgotten: item['forgotten'] as int)],
      reviewedToday: today['reviewed'] as int,
      newToday: today['newCards'] as int,
      goal: today['goal'] as int?,
      newLimit: today['newLimit'] as int?,
      streak: today['streak'] as int,
    );
  }
}

extension CardProgressApi on CollectionsApi {
  Future<CardStats> cardStats(String collectionId, {String? formatId}) async {
    final data = await auth.authenticatedRequest(
      'query(\$c:String!,\$f:String,\$z:Int){cardStats(collectionId:\$c,formatId:\$f,utcOffsetMinutes:\$z){total fresh learning mature reviewed7 reviewed30 successRate30 days{day answers remembered} forecast hardest{entryId title forgotten} today{reviewed newCards goal newLimit streak}}}',
      {'c': collectionId, 'f': formatId, 'z': cardUtcOffset()},
    );
    return CardStats.fromJson(data['cardStats'] as Map<String, dynamic>);
  }

  Future<void> setCardGoal(String collectionId, int? reviewsPerDay, int? newPerDay) => auth.authenticatedRequest(
        'mutation(\$c:String!,\$r:Int,\$n:Int){setCardGoal(collectionId:\$c,reviewsPerDay:\$r,newPerDay:\$n){reviewsPerDay}}',
        {'c': collectionId, 'r': reviewsPerDay, 'n': newPerDay},
      );
}

const _violet = Color(0xFF8B5CF6);

String _dayLabel(String day, bool fr, {bool weekday = false}) {
  final date = DateTime.parse(day);
  const weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const weekdaysFr = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const monthsFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  if (weekday) return (fr ? weekdaysFr : weekdaysEn)[date.weekday - 1];
  return '${date.day} ${(fr ? monthsFr : monthsEn)[date.month - 1]}';
}

String _shiftDay(String day, int delta) => DateTime.parse(day).add(Duration(days: delta)).toIso8601String().substring(0, 10);

/// "12 / 20 today · 3 days in a row" — for the banner and the review page.
class CardGoalLine extends StatelessWidget {
  const CardGoalLine({super.key, required this.stats});
  final CardStats stats;

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final goal = stats.goal;
    final reviewed = stats.reviewedToday;
    return Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (goal != null) ...[
        Semantics(
          label: fr ? 'Objectif du jour' : "Today's goal",
          value: '$reviewed / $goal',
          child: SizedBox(width: 90, child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: math.min(1, reviewed / goal), minHeight: 6, color: _violet, backgroundColor: scheme.outlineVariant))),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.track_changes, size: 15, color: scheme.onSurface),
          const SizedBox(width: 4),
          Text('${fr ? '$reviewed / $goal aujourd’hui' : '$reviewed / $goal today'}${reviewed >= goal ? ' ✓' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ] else
        Text(fr ? '$reviewed carte(s) révisée(s) aujourd’hui' : '$reviewed card(s) reviewed today', style: const TextStyle(fontWeight: FontWeight.w600)),
      if (stats.streak > 0)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_fire_department_outlined, size: 15, color: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
          const SizedBox(width: 3),
          Text(
            fr ? '${stats.streak} jour${stats.streak > 1 ? 's' : ''} de suite' : '${stats.streak} day${stats.streak > 1 ? 's' : ''} in a row',
            style: TextStyle(fontWeight: FontWeight.w600, color: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
          ),
        ]),
    ]);
  }
}

/// Statistics, charts, most forgotten cards and my daily goal.
class CardProgressPanel extends StatefulWidget {
  const CardProgressPanel({super.key, required this.api, required this.collectionId, this.formatId, this.formatName});
  final CollectionsApi api;
  final String collectionId;
  final String? formatId;
  final String? formatName;

  @override
  State<CardProgressPanel> createState() => _CardProgressPanelState();
}

class _CardProgressPanelState extends State<CardProgressPanel> {
  CardStats? _stats;
  String? _error;
  final _reviews = TextEditingController();
  final _fresh = TextEditingController();
  bool _saving = false;
  String? _saved;
  String? _goalError;

  @override
  void initState() {
    super.initState();
    _load(resetForm: true);
  }

  @override
  void didUpdateWidget(covariant CardProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formatId != widget.formatId) _load();
  }

  @override
  void dispose() {
    _reviews.dispose();
    _fresh.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetForm = false}) async {
    try {
      final stats = await widget.api.cardStats(widget.collectionId, formatId: widget.formatId);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _error = null;
        if (resetForm) {
          _reviews.text = stats.goal?.toString() ?? '';
          _fresh.text = stats.newLimit?.toString() ?? '';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    }
  }

  Future<void> _saveGoal() async {
    final fr = AppStrings.of(context).isFrench;
    int? parse(String value) => value.trim().isEmpty ? null : int.tryParse(value.trim());
    setState(() { _saving = true; _saved = null; _goalError = null; });
    try {
      await widget.api.setCardGoal(widget.collectionId, parse(_reviews.text), parse(_fresh.text));
      if (!mounted) return;
      setState(() => _saved = fr ? 'Objectif enregistré.' : 'Goal saved.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _goalError = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final scheme = Theme.of(context).colorScheme;
    final stats = _stats;
    final box = BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(16), color: scheme.surface);
    if (_error != null) return Text(_error!, style: TextStyle(color: scheme.error));
    if (stats == null) return Container(padding: const EdgeInsets.all(20), decoration: box, child: Text(fr ? 'Chargement des progrès…' : 'Loading progress…', style: TextStyle(color: scheme.onSurfaceVariant)));
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final percent = stats.successRate30 == null ? '—' : '${(stats.successRate30! * 100).round()} %';
    final today = stats.days.isEmpty ? '' : stats.days.last.day;
    final maxDay = math.max(1, stats.days.fold<int>(0, (top, day) => math.max(top, day.answers)));
    final maxDue = math.max(1, stats.forecast.fold<int>(0, math.max));
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: box,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 16, runSpacing: 8, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${fr ? 'Mes progrès' : 'My progress'}${widget.formatName == null ? '' : ' · ${widget.formatName}'}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
          CardGoalLine(stats: stats),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 420 ? 2 : constraints.maxWidth < 640 ? 3 : 5;
          final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
          Widget tile(String label, String value, String hint) => Container(
                width: width,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: scheme.outlineVariant), color: _violet.withValues(alpha: .05)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: muted.copyWith(fontWeight: FontWeight.w600)),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                  Text(hint, style: muted.copyWith(fontSize: 11.5)),
                ]),
              );
          return Wrap(spacing: 10, runSpacing: 10, children: [
            tile(fr ? 'Nouvelles' : 'New', '${stats.fresh}', fr ? 'jamais révisées' : 'never reviewed'),
            tile(fr ? 'En cours' : 'Learning', '${stats.learning}', fr ? 'retour avant 21 j' : 'back within 21 d'),
            tile(fr ? 'Acquises' : 'Learned', '${stats.mature}', fr ? 'retour à 21 j ou plus' : 'back in 21 d or more'),
            tile(fr ? 'Révisions' : 'Reviews', '${stats.reviewed7}', fr ? '7 jours · ${stats.reviewed30} sur 30' : '7 days · ${stats.reviewed30} in 30'),
            tile(fr ? 'Réussite' : 'Success', percent, fr ? 'réponses autres que « À revoir », 30 j' : 'answers other than Again, 30 d'),
          ]);
        }),
        const SizedBox(height: 18),
        Text(fr ? 'Révisions des 30 derniers jours' : 'Reviews over the last 30 days', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        SizedBox(
          height: 84,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final day in stats.days)
              Expanded(
                child: Tooltip(
                  message: fr ? '${_dayLabel(day.day, fr)} : ${day.answers} réponse(s), ${day.remembered} retenue(s)' : '${_dayLabel(day.day, fr)}: ${day.answers} answer(s), ${day.remembered} remembered',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FractionallySizedBox(
                      heightFactor: day.answers == 0 ? 0.0 : math.max(.06, day.answers / maxDay),
                      alignment: Alignment.bottomCenter,
                      child: Container(decoration: BoxDecoration(color: day.day == today ? _violet : _violet.withValues(alpha: .6), borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(stats.days.isEmpty ? '' : _dayLabel(stats.days.first.day, fr), style: muted.copyWith(fontSize: 11.5)),
          Text(fr ? 'aujourd’hui' : 'today', style: muted.copyWith(fontSize: 11.5)),
        ]),
        const SizedBox(height: 16),
        Text(fr ? 'À revoir les 7 prochains jours' : 'Due over the next 7 days', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        SizedBox(
          height: 108,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var index = 0; index < stats.forecast.length; index++)
              Expanded(
                child: Semantics(
                  label: '${index == 0 ? (fr ? 'Aujourd’hui' : 'Today') : _dayLabel(_shiftDay(today, index), fr, weekday: true)}: ${stats.forecast[index]}',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(stats.forecast[index] == 0 ? '' : '${stats.forecast[index]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Expanded(
                        child: FractionallySizedBox(
                          heightFactor: stats.forecast[index] == 0 ? 0.0 : math.max(.06, stats.forecast[index] / maxDue),
                          alignment: Alignment.bottomCenter,
                          child: Container(decoration: BoxDecoration(color: _violet.withValues(alpha: .7), borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 3),
                      Text(index == 0 ? (fr ? 'Auj.' : 'Today') : _dayLabel(_shiftDay(today, index), fr, weekday: true), style: muted.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.clip),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        if (stats.hardest.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(fr ? 'Les plus souvent oubliées' : 'Most often forgotten', style: heading?.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          for (final (index, card) in stats.hardest.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${index + 1}. ${card.title}'),
                TextSpan(text: fr ? '   ${card.forgotten} fois « À revoir »' : '   “Again” ${card.forgotten}×', style: muted),
              ])),
            ),
        ],
        const SizedBox(height: 14),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: 8),
        Text(fr ? 'Mon objectif quotidien' : 'My daily goal', style: heading?.copyWith(fontSize: 14)),
        const SizedBox(height: 4),
        Text(fr ? 'Rien que pour vous : chaque personne choisit le sien. Laissez vide pour ne rien fixer.' : 'Just for you: each person chooses their own. Leave empty for none.', style: muted.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: 240,
            child: TextField(
              key: const ValueKey('card-goal-reviews'),
              controller: _reviews,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: InputDecoration(labelText: fr ? 'Cartes à réviser par jour' : 'Cards to review per day', hintText: fr ? 'Aucun objectif' : 'No goal', border: const OutlineInputBorder()),
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              key: const ValueKey('card-goal-new'),
              controller: _fresh,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: InputDecoration(labelText: fr ? 'Nouvelles cartes par jour, au plus' : 'New cards per day, at most', hintText: fr ? 'Sans limite' : 'No limit', border: const OutlineInputBorder()),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(fr ? 'La limite de nouvelles cartes s’applique à l’ordre « À revoir aujourd’hui, puis nouvelles ».' : 'The new-card limit applies to the order “Due today, then new cards”.', style: muted.copyWith(fontSize: 12)),
        if (_goalError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_goalError!, style: TextStyle(color: scheme.error))),
        if (_saved != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_saved!, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)))),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(onPressed: _saving ? null : _saveGoal, child: Text(_saving ? (fr ? 'Enregistrement…' : 'Saving…') : (fr ? 'Enregistrer l’objectif' : 'Save the goal'))),
        ),
      ]),
    );
  }
}
