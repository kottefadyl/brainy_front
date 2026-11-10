import 'package:flutter/material.dart';

import 'entry_editor_pickers.dart';
import 'adaptive_form.dart';
import 'app_strings.dart';
import 'collections_api.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.api,
    required this.collection,
    required this.view,
    required this.onEdit,
    this.onRemind,
  });
  final CollectionsApi api;
  final BrainyCollection collection;
  final Map<String, dynamic> view;
  final ValueChanged<BrainyEntry> onEdit;
  /// Null when reminders are paused on this hosting.
  final ValueChanged<BrainyEntry>? onRemind;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _date = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String _mode = 'WEEK';
  List<Map<String, dynamic>> _events = [];
  bool _loading = false;
  String? _error;
  int _request = 0;
  bool get _fr => AppStrings.of(context).isFrench;
  String _dateText(DateTime date) => date.toIso8601String().substring(0, 10);
  DateTime get _start => switch (_mode) {
    'DAY' => _date,
    'MONTH' => DateTime.utc(_date.year, _date.month),
    _ => _date.subtract(Duration(days: _date.weekday - 1)),
  };
  DateTime get _end => switch (_mode) {
    'DAY' => _start.add(const Duration(days: 1)),
    'MONTH' => DateTime.utc(_date.year, _date.month + 1),
    _ => _start.add(const Duration(days: 7)),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.id != widget.collection.id ||
        oldWidget.view['id'] != widget.view['id']) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.api.calendarOccurrences(
        widget.collection.id,
        widget.view['id'] as String,
        _start.subtract(const Duration(days: 1)),
        _end.add(const Duration(days: 1)),
      );
      if (!mounted || request != _request) return;
      setState(() {
        _events = events.where((item) {
          final date = item['localDate'] as String;
          return date.compareTo(_dateText(_start)) >= 0 &&
              date.compareTo(_dateText(_end)) < 0;
        }).toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = AppStrings.of(context).error(error);
        });
      }
    }
  }

  void _shift(int direction) {
    setState(() {
      _date = _mode == 'MONTH'
          ? DateTime.utc(_date.year, _date.month + direction, 1)
          : _date.add(Duration(days: direction * (_mode == 'WEEK' ? 7 : 1)));
    });
    _load();
  }

  String _title(BrainyEntry entry) {
    final format = widget.collection.formatFor(entry);
    final title = format.fields
        .where((field) => field.kind == BrainyFieldKind.title)
        .firstOrNull;
    return entry.values[title?.id] ?? format.name;
  }

  Future<void> _skip(Map<String, dynamic> occurrence) async {
    try {
      final entry = BrainyEntry.fromJson(
        occurrence['entry'] as Map<String, dynamic>,
      );
      final recurrence = entry.recurrence;
      if (recurrence == null) return;
      await widget.api.setEntryRecurrence(
        widget.collection.id,
        widget.view['id'] as String,
        entry.id,
        {
          'timeZone': recurrence['timeZone'],
          'frequency': recurrence['frequency'],
          'interval': recurrence['interval'],
          if (recurrence['untilDate'] != null)
            'untilDate': recurrence['untilDate'],
          'excludedDates': [
            ...{
              ...(recurrence['excludedDates'] as List<dynamic>).cast<String>(),
              occurrence['localDate'] as String,
            },
          ],
        },
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      _end.difference(_start).inDays,
      (index) => _start.add(Duration(days: index)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              onPressed: () => _shift(-1),
              tooltip: _fr ? 'Période précédente' : 'Previous period',
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_dateText(_start)} → ${_dateText(_end.subtract(const Duration(days: 1)))}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: () => _shift(1),
              tooltip: _fr ? 'Période suivante' : 'Next period',
              icon: const Icon(Icons.chevron_right),
            ),
            DropdownButton<String>(
              value: _mode,
              items: [
                DropdownMenuItem(
                  value: 'DAY',
                  child: Text(_fr ? 'Jour' : 'Day'),
                ),
                DropdownMenuItem(
                  value: 'WEEK',
                  child: Text(_fr ? 'Semaine' : 'Week'),
                ),
                DropdownMenuItem(
                  value: 'MONTH',
                  child: Text(_fr ? 'Mois' : 'Month'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _mode = value);
                  _load();
                }
              },
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        for (final day in days) _day(day),
      ],
    );
  }

  Widget _day(DateTime day) {
    final date = _dateText(day);
    final events = _events.where((item) => item['localDate'] == date).toList();
    return Card(
      color: const Color(0xFFF8FBFF),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${MaterialLocalizations.of(context).formatMediumDate(day)} · ${widget.view['calendarTimeZone']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (events.isEmpty)
              Text(
                _fr ? 'Aucun rendez-vous' : 'No events',
                style: const TextStyle(color: Color(0xFF63758E), fontSize: 12),
              ),
            for (final occurrence in events)
              Builder(
                builder: (context) {
                  final entry = BrainyEntry.fromJson(
                    occurrence['entry'] as Map<String, dynamic>,
                  );
                  return Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => widget.onEdit(entry),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_title(entry)} · ${occurrence['localStartClock']}–${occurrence['localEndClock']} (${occurrence['timeZone']})',
                            ),
                          ),
                        ),
                      ),
                      if (widget.onRemind != null) IconButton(
                        onPressed: () => widget.onRemind!(entry),
                        tooltip: _fr ? 'Rappels' : 'Reminders',
                        icon: const Icon(Icons.notifications_outlined),
                      ),
                      IconButton(
                        onPressed: () async {
                          final changed = await showRecurrenceEditor(
                            context,
                            api: widget.api,
                            collection: widget.collection,
                            view: widget.view,
                            entry: entry,
                          );
                          if (changed) _load();
                        },
                        tooltip: _fr
                            ? 'Récurrence et exceptions'
                            : 'Recurrence and exceptions',
                        icon: const Icon(Icons.repeat),
                      ),
                      if (occurrence['recurring'] == true)
                        IconButton(
                          onPressed: () => _skip(occurrence),
                          tooltip: _fr
                              ? 'Ignorer cette occurrence'
                              : 'Skip this occurrence',
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showRecurrenceEditor(
  BuildContext context, {
  required CollectionsApi api,
  required BrainyCollection collection,
  required Map<String, dynamic> view,
  required BrainyEntry entry,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _RecurrenceDialog(
        api: api,
        collection: collection,
        view: view,
        entry: entry,
      ),
    ) ??
    false;

class _RecurrenceDialog extends StatefulWidget {
  const _RecurrenceDialog({
    required this.api,
    required this.collection,
    required this.view,
    required this.entry,
  });
  final CollectionsApi api;
  final BrainyCollection collection;
  final Map<String, dynamic> view;
  final BrainyEntry entry;
  @override
  State<_RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<_RecurrenceDialog> {
  late String _frequency =
      widget.entry.recurrence?['frequency'] as String? ?? 'WEEKLY';
  late int _interval = widget.entry.recurrence?['interval'] as int? ?? 1;
  late final TextEditingController _zone = TextEditingController(
    text:
        widget.entry.recurrence?['timeZone'] as String? ??
        widget.view['calendarTimeZone'] as String? ??
        'UTC',
  );
  late final TextEditingController _until = TextEditingController(
    text: widget.entry.recurrence?['untilDate'] as String? ?? '',
  );
  late final List<String> _exceptions =
      (widget.entry.recurrence?['excludedDates'] as List<dynamic>?)
          ?.cast<String>()
          .toList() ??
      [];
  bool _busy = false;
  String? _error;
  bool get _fr => AppStrings.of(context).isFrench;
  @override
  void dispose() {
    _zone.dispose();
    _until.dispose();
    super.dispose();
  }

  Future<void> _save(bool clear) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.setEntryRecurrence(
        widget.collection.id,
        widget.view['id'] as String,
        widget.entry.id,
        clear
            ? null
            : {
                'timeZone': _zone.text.trim(),
                'frequency': _frequency,
                'interval': _interval,
                if (_until.text.trim().isNotEmpty)
                  'untilDate': _until.text.trim(),
                'excludedDates': _exceptions,
              },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppStrings.of(context).error(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(_fr ? 'Récurrence du rendez-vous' : 'Event recurrence'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(isExpanded: true, 
              initialValue: _frequency,
              decoration: InputDecoration(
                labelText: _fr ? 'Répéter' : 'Repeat',
              ),
              items: [
                DropdownMenuItem(
                  value: 'DAILY',
                  child: Text(_fr ? 'Chaque jour' : 'Daily', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'WEEKLY',
                  child: Text(_fr ? 'Chaque semaine' : 'Weekly', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'MONTHLY',
                  child: Text(_fr ? 'Chaque mois' : 'Monthly', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _frequency = value ?? 'WEEKLY'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(isExpanded: true, 
              initialValue: _interval,
              decoration: InputDecoration(
                labelText: _fr ? 'Intervalle' : 'Interval',
              ),
              items: [
                for (var i = 1; i <= 30; i++)
                  DropdownMenuItem(value: i, child: Text('$i', maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _interval = value ?? 1),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _zone,
              decoration: InputDecoration(
                labelText: _fr ? 'Fuseau horaire IANA' : 'IANA time zone',
              ),
            ),
            const SizedBox(height: 12),
            LocalizedDateField(
              controller: _until,
              kind: StoredDateKind.date,
              label: _fr ? 'Jusqu’au' : 'Until',
              onPick: () => pickEntryDate(context, _until),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 5,
              children: [
                for (final date in _exceptions)
                  InputChip(
                    label: Text(date),
                    onDeleted: () => setState(() => _exceptions.remove(date)),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200),
                  initialDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    final text = date.toIso8601String().substring(0, 10);
                    if (!_exceptions.contains(text)) _exceptions.add(text);
                  });
                }
              },
              icon: const Icon(Icons.event_busy),
              label: Text(_fr ? 'Ajouter une exception' : 'Add exception'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(_fr ? 'Annuler' : 'Cancel'),
      ),
      if (widget.entry.recurrence != null)
        TextButton(
          onPressed: _busy ? null : () => _save(true),
          child: Text(_fr ? 'Arrêter la répétition' : 'Stop repeating'),
        ),
      FilledButton(
        onPressed: _busy ? null : () => _save(false),
        child: Text(_fr ? 'Enregistrer' : 'Save'),
      ),
    ],
  );
}
