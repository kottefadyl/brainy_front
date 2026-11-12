// T49: Day and Calendar views of the Task list template. Each day of a repeating task has its own check.
import 'package:flutter/material.dart';

import 'collections_api.dart';
import 'data_format_colors.dart';
import 'entry_authors.dart';

typedef TaskOccurrence = ({String entryId, String date, bool done, bool overdue, bool repeating});

String isoDay(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime parseDay(String day) => DateTime.utc(int.parse(day.substring(0, 4)), int.parse(day.substring(5, 7)), int.parse(day.substring(8, 10)));
String addDays(String day, int count) => isoDay(parseDay(day).add(Duration(days: count)));
String monthStart(String day) => '${day.substring(0, 7)}-01';
String addMonths(String day, int count) { final date = parseDay(monthStart(day)); return isoDay(DateTime.utc(date.year, date.month + count)); }
String weekStart(String day) => addDays(day, -(parseDay(day).weekday - 1));

const _monthsFr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _daysFr = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
String _capital(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
String dayTitle(String day, bool fr) { final date = parseDay(day); return fr ? _capital('${_daysFr[date.weekday - 1]} ${date.day} ${_monthsFr[date.month - 1]} ${date.year}') : '${_daysEn[date.weekday - 1]}, ${_monthsEn[date.month - 1]} ${date.day}, ${date.year}'; }
String shortDay(String day, bool fr) { final date = parseDay(day); return fr ? '${date.day} ${_monthsFr[date.month - 1].substring(0, 3)}.' : '${_monthsEn[date.month - 1].substring(0, 3)} ${date.day}'; }
String monthTitle(String day, bool fr) { final date = parseDay(day); return fr ? _capital('${_monthsFr[date.month - 1]} ${date.year}') : '${_monthsEn[date.month - 1]} ${date.year}'; }

extension TaskPlannerApi on CollectionsApi {
  Future<({List<TaskOccurrence> occurrences, List<BrainyEntry> entries})> taskAgenda(String collectionId, String from, String to, String today, String timeZone) async {
    final data = await auth.authenticatedRequest(
      'query(\$id:String!,\$from:String!,\$to:String!,\$today:String!,\$tz:String!){taskAgenda(collectionId:\$id,from:\$from,to:\$to,today:\$today,timeZone:\$tz){occurrences{entryId date done overdue repeating} entries{id formatId createdAt updatedAt createdBy{userId name hasPhoto} updatedBy{userId name hasPhoto} values{fieldId value}}}}',
      {'id': collectionId, 'from': from, 'to': to, 'today': today, 'tz': timeZone},
    );
    final agenda = data['taskAgenda'] as Map<String, dynamic>;
    return (
      occurrences: [for (final item in agenda['occurrences'] as List<dynamic>) (entryId: item['entryId'] as String, date: item['date'] as String, done: item['done'] as bool, overdue: item['overdue'] as bool, repeating: item['repeating'] as bool)],
      entries: [for (final item in agenda['entries'] as List<dynamic>) BrainyEntry.fromJson(item as Map<String, dynamic>)],
    );
  }

  Future<void> setTaskDayDone(String collectionId, String entryId, String date, bool done, String timeZone) async {
    await auth.authenticatedRequest('mutation(\$id:String!,\$entry:String!,\$date:String!,\$done:Boolean!,\$tz:String!){setTaskDayDone(collectionId:\$id,entryId:\$entry,date:\$date,done:\$done,timeZone:\$tz){id}}', {'id': collectionId, 'entry': entryId, 'date': date, 'done': done, 'tz': timeZone});
  }
}

/// IANA zone of the device when Dart knows it, otherwise UTC (dates are local days anyway).
String deviceTimeZone() => deviceZoneOrOffset();

class TaskAgendaView extends StatefulWidget {
  const TaskAgendaView({super.key, required this.api, required this.collection, required this.calendar, required this.french, required this.onEdit, required this.onNewTask, this.today});
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool calendar, french;
  final Future<void> Function(BrainyEntry entry) onEdit;
  final Future<void> Function() onNewTask;
  /// For tests and previews; defaults to the device's local day.
  final String? today;
  @override
  State<TaskAgendaView> createState() => _TaskAgendaViewState();
}

class _TaskAgendaViewState extends State<TaskAgendaView> {
  late final String today = widget.today ?? isoDay(DateTime.now());
  late String day = today;
  late String month = monthStart(today);
  List<TaskOccurrence>? occurrences;
  Map<String, BrainyEntry> entries = {};
  String error = '';
  String busy = '';
  bool get fr => widget.french;
  Map<String, dynamic> get planner => widget.collection.taskPlanner!;
  ({String from, String to}) get range => widget.calendar ? (from: weekStart(month), to: addDays(weekStart(month), 41)) : (from: day, to: day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wanted = range;
    try {
      final agenda = await widget.api.taskAgenda(widget.collection.id, wanted.from, wanted.to, today, deviceTimeZone());
      if (!mounted || wanted != range) return;
      setState(() { occurrences = agenda.occurrences; entries = {for (final entry in agenda.entries) entry.id: entry}; error = ''; });
    } catch (cause) {
      if (mounted) setState(() => error = cause.toString());
    }
  }

  void _go(VoidCallback change) { setState(() { change(); occurrences = null; }); _load(); }

  Future<void> _toggle(TaskOccurrence item) async {
    setState(() { busy = '${item.entryId}-${item.date}'; occurrences = [for (final value in occurrences!) value == item ? (entryId: item.entryId, date: item.date, done: !item.done, overdue: item.overdue, repeating: item.repeating) : value]; });
    try {
      await widget.api.setTaskDayDone(widget.collection.id, item.entryId, item.date, !item.done, deviceTimeZone());
    } catch (cause) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cause.toString())));
    }
    if (mounted) setState(() => busy = '');
    await _load();
  }

  BrainyFormat? get _format => widget.collection.formats.where((item) => item.id == planner['formatId']).firstOrNull;
  String _title(BrainyEntry? entry) {
    final titleId = _format?.fields.where((field) => field.kind == BrainyFieldKind.title).firstOrNull?.id;
    final value = titleId == null ? '' : entry?.values[titleId] ?? '';
    return value.isEmpty ? (fr ? 'Tâche sans titre' : 'Untitled task') : value;
  }

  String _detail(TaskOccurrence item, BrainyEntry? entry) {
    String value(String key) => entry?.values[planner[key] as String] ?? '';
    if (item.repeating) return value('repeatFieldId');
    final start = value('startFieldId'), end = value('endFieldId');
    if (start.isNotEmpty && end.isNotEmpty && start != end) return fr ? 'Du ${shortDay(start, fr)} au ${shortDay(end, fr)}' : '${shortDay(start, fr)} to ${shortDay(end, fr)}';
    if (end.isNotEmpty) return '${fr ? 'Échéance' : 'Due'} ${shortDay(end, fr)}';
    return '';
  }

  Widget _dayList(String date) {
    final theme = Theme.of(context), scheme = theme.colorScheme, dark = theme.brightness == Brightness.dark;
    final items = (occurrences ?? []).where((item) => item.date == date).toList();
    final groups = [
      (fr ? 'En retard' : 'Overdue', items.where((item) => item.overdue && !item.done).toList()),
      (fr ? 'À faire' : 'To do', items.where((item) => !item.overdue && !item.done).toList()),
      (fr ? 'Faites' : 'Done', items.where((item) => item.done).toList()),
    ];
    final done = items.where((item) => item.done).length;
    final color = _format?.color ?? '#FFF5EB';
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(Icons.event_available_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(fr ? 'Rien de prévu ce jour.' : 'Nothing planned this day.', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: widget.onNewTask, icon: const Icon(Icons.add), label: Text(fr ? 'Nouvelle tâche' : 'New task')),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        liveRegion: true,
        child: Row(children: [
          Text(fr ? 'Faites : $done sur ${items.length}' : 'Done: $done of ${items.length}', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: done / items.length, minHeight: 8, color: const Color(0xFF1B7A45), backgroundColor: scheme.surfaceContainerHighest))),
        ]),
      ),
      for (final (label, list) in groups)
        if (list.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text('${label.toUpperCase()}  ${list.length}', style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: .5))),
          for (final item in list)
            Builder(builder: (context) {
              final entry = entries[item.entryId];
              final name = _title(entry), info = _detail(item, entry);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                color: DataFormatColors.surface(color, dark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: item.overdue && !item.done ? scheme.error : DataFormatColors.marker(color, dark).withValues(alpha: .3))),
                clipBehavior: Clip.antiAlias,
                child: Row(children: [
                  Expanded(
                    child: CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      value: item.done,
                      onChanged: busy == '${item.entryId}-${item.date}' ? null : (_) => _toggle(item),
                      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (entry != null) EntryAuthors(entry: entry, collection: widget.collection, compact: true),
                        Text(name, style: TextStyle(fontWeight: FontWeight.w600, decoration: item.done ? TextDecoration.lineThrough : null, color: item.done ? scheme.onSurfaceVariant : null)),
                      ]),
                      subtitle: info.isEmpty ? null : Row(children: [if (item.repeating) Icon(Icons.repeat, size: 14, color: scheme.onSurfaceVariant), if (item.repeating) const SizedBox(width: 4), Flexible(child: Text(info, style: TextStyle(color: item.overdue ? scheme.error : scheme.onSurfaceVariant)))]),
                    ),
                  ),
                  if (entry != null) IconButton(tooltip: '${fr ? 'Modifier' : 'Edit'} : $name', onPressed: () async { await widget.onEdit(entry); _load(); }, icon: const Icon(Icons.edit_outlined)),
                ]),
                ),
              );
            }),
        ],
    ]);
  }

  Widget _calendar() {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final names = fr ? ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'] : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(14), color: scheme.surface),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Row(children: [for (final name in names) Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(name, textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700))))]),
        for (var week = 0; week < 6; week++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var index = 0; index < 7; index++)
              Expanded(child: Builder(builder: (context) {
                final date = addDays(range.from, week * 7 + index);
                final items = (occurrences ?? []).where((item) => item.date == date).toList();
                final done = items.where((item) => item.done).length;
                final outside = date.substring(0, 7) != month.substring(0, 7);
                final late = items.any((item) => item.overdue && !item.done);
                final complete = items.isNotEmpty && done == items.length;
                return Semantics(
                  button: true,
                  selected: date == day,
                  label: '${dayTitle(date, fr)} : ${items.isEmpty ? (fr ? 'aucune tâche' : 'no task') : (fr ? '$done sur ${items.length} faites' : '$done of ${items.length} done')}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => setState(() => day = date),
                    child: Container(
                      height: narrow ? 58 : 104,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: outside ? scheme.surfaceContainerHighest.withValues(alpha: .4) : null,
                        border: Border(top: BorderSide(color: scheme.outlineVariant), left: index == 0 ? BorderSide.none : BorderSide(color: scheme.outlineVariant)),
                      ),
                      foregroundDecoration: date == day ? BoxDecoration(border: Border.all(color: scheme.primary, width: 2)) : null,
                      child: Column(crossAxisAlignment: narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: narrow ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween, children: [
                          Container(
                            width: 24, height: 24, alignment: Alignment.center,
                            decoration: date == today ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle) : null,
                            child: Text('${parseDay(date).day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: date == today ? scheme.onPrimary : outside ? scheme.onSurfaceVariant : null)),
                          ),
                          if (!narrow && items.isNotEmpty) _count(done, items.length, complete, late),
                        ]),
                        if (narrow && items.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: _count(done, items.length, complete, late)),
                        if (!narrow)
                          for (final item in items.take(items.length > 3 ? 2 : 3))
                            Padding(padding: const EdgeInsets.only(top: 2), child: Text(_title(entries[item.entryId]), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, decoration: item.done ? TextDecoration.lineThrough : null, color: item.done ? scheme.onSurfaceVariant : null))),
                        if (!narrow && items.length > 3) Text('+${items.length - 2}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                  ),
                );
              })),
          ]),
      ]),
    );
  }

  Widget _count(int done, int total, bool complete, bool late) {
    final scheme = Theme.of(context).colorScheme;
    final color = complete ? const Color(0xFF1B7A45) : late ? scheme.error : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
      child: Text('$done/$total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(tooltip: widget.calendar ? (fr ? 'Mois précédent' : 'Previous month') : (fr ? 'Jour précédent' : 'Previous day'), onPressed: () => _go(() => widget.calendar ? month = addMonths(month, -1) : day = addDays(day, -1)), icon: const Icon(Icons.chevron_left)),
        Flexible(child: Text(widget.calendar ? monthTitle(month, fr) : dayTitle(day, fr), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        IconButton(tooltip: widget.calendar ? (fr ? 'Mois suivant' : 'Next month') : (fr ? 'Jour suivant' : 'Next day'), onPressed: () => _go(() => widget.calendar ? month = addMonths(month, 1) : day = addDays(day, 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
        if (!widget.calendar && day == today) Chip(label: Text(fr ? 'Aujourd’hui' : 'Today'), visualDensity: VisualDensity.compact),
        if (!widget.calendar)
          IconButton(tooltip: fr ? 'Choisir un jour' : 'Choose a day', icon: const Icon(Icons.calendar_month_outlined), onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: parseDay(day).toLocal(), firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (picked != null) _go(() => day = isoDay(picked));
          }),
        if ((widget.calendar ? month != monthStart(today) || day != today : day != today)) OutlinedButton(onPressed: () => _go(() { day = today; month = monthStart(today); }), child: Text(fr ? 'Aujourd’hui' : 'Today')),
        FilledButton.tonalIcon(onPressed: () async { await widget.onNewTask(); _load(); }, icon: const Icon(Icons.add), label: Text(fr ? 'Nouvelle tâche' : 'New task')),
      ]),
    ]);
    Widget body;
    if (error.isNotEmpty) {
      body = Column(children: [Text(error, style: TextStyle(color: theme.colorScheme.error)), TextButton(onPressed: _load, child: Text(fr ? 'Réessayer' : 'Retry'))]);
    } else if (occurrences == null) {
      body = const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    } else if (!widget.calendar) {
      body = _dayList(day);
    } else {
      final dayPanel = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(dayTitle(day, fr), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), _dayList(day)]);
      body = wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 8, child: _calendar()), const SizedBox(width: 20), Expanded(flex: 5, child: dayPanel)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_calendar(), const SizedBox(height: 16), dayPanel]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: 12), body]);
  }
}

const _repeatChoices = {'ONCE': ['once', 'une seule fois'], 'EVERY_N_DAYS': ['every n days', 'tous les n jours'], 'WEEKDAYS': ['some weekdays', 'certains jours de la semaine'], 'DAILY': ['every day', 'chaque jour'], 'WEEKLY': ['every week', 'chaque semaine'], 'MONTHLY': ['every month', 'chaque mois']};
String repeatKind(String? value) {
  final key = (value ?? '').trim().toLowerCase();
  if (key.isEmpty) return 'ONCE';
  return _repeatChoices.entries.where((item) => item.value.contains(key)).firstOrNull?.key ?? 'ONCE';
}

/// T49: in the task form, show only the fields that matter for the chosen Repeat.
Set<String> hiddenTaskFieldIds(BrainyCollection collection, String formatId, Map<String, String> values) {
  final planner = collection.taskPlanner;
  if (planner == null || planner['formatId'] != formatId) return const {};
  final repeat = repeatKind(values[planner['repeatFieldId']]);
  return {
    if (repeat != 'EVERY_N_DAYS') planner['intervalFieldId'] as String,
    if (repeat != 'WEEKDAYS') planner['weekdaysFieldId'] as String,
    if (repeat != 'ONCE') planner['doneFieldId'] as String,
    if (repeat != 'ONCE' && planner['completedFieldId'] != null) planner['completedFieldId'] as String,
  };
}

/// T49/2: offsets that are not whole hours have no Etc/GMT zone; the zone using that offset today stands in.
const _partHourZones = {
  330: 'Asia/Kolkata', 345: 'Asia/Kathmandu', 210: 'Asia/Tehran', 270: 'Asia/Kabul', 390: 'Asia/Yangon',
  570: 'Australia/Darwin', 630: 'Australia/Adelaide', 525: 'Australia/Eucla', 765: 'Pacific/Chatham', 825: 'Pacific/Chatham',
  -210: 'America/St_Johns', -150: 'America/St_Johns', -570: 'Pacific/Marquesas',
};

/// Named zone when Dart knows it, else a fixed-offset zone (Etc/GMT signs are inverted), else UTC.
String deviceZoneOrOffset() => zoneForOffset(DateTime.now().timeZoneName, DateTime.now().timeZoneOffset);

String zoneForOffset(String name, Duration offset) {
  if (name.contains('/')) return name;
  if (offset.inMinutes % 60 != 0) return _partHourZones[offset.inMinutes] ?? 'UTC';
  final hours = offset.inHours;
  return hours == 0 ? 'UTC' : 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
}
