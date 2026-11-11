import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'app_strings.dart';
import 'collections_api.dart';

Future<BrainyCollection?> showSavedViewEditor(
  BuildContext context, {
  required CollectionsApi api,
  required BrainyCollection collection,
  Map<String, dynamic>? existing,
  String search = '',
  String? formatId,
  String? filterFieldId,
  String filterOperator = 'EQ',
  String filterValue = '',
}) => showDialog<BrainyCollection>(
  context: context,
  builder: (context) => _SavedViewDialog(
    api: api,
    collection: collection,
    existing: existing,
    search: search,
    formatId: formatId,
    filterFieldId: filterFieldId,
    filterOperator: filterOperator,
    filterValue: filterValue,
  ),
);

class _SavedViewDialog extends StatefulWidget {
  const _SavedViewDialog({
    required this.api,
    required this.collection,
    this.existing,
    required this.search,
    this.formatId,
    this.filterFieldId,
    required this.filterOperator,
    required this.filterValue,
  });
  final CollectionsApi api;
  final BrainyCollection collection;
  final Map<String, dynamic>? existing;
  final String search;
  final String? formatId;
  final String? filterFieldId;
  final String filterOperator;
  final String filterValue;

  @override
  State<_SavedViewDialog> createState() => _SavedViewDialogState();
}

class _SavedViewDialogState extends State<_SavedViewDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?['name'] as String? ?? '',
  );
  late String _layout = widget.existing?['layout'] as String? ?? 'LIST';
  late String? _taskDone = widget.existing?['taskDoneFieldId'] as String?;
  late String? _taskDue = widget.existing?['taskDueFieldId'] as String?;
  late String? _taskCompleted =
      widget.existing?['taskCompletedFieldId'] as String?;
  late String? _taskPriority =
      widget.existing?['taskPriorityFieldId'] as String?;
  late String? _calendarStart =
      widget.existing?['calendarStartFieldId'] as String?;
  late String? _calendarEnd = widget.existing?['calendarEndFieldId'] as String?;
  late final TextEditingController _timeZone = TextEditingController(
    text: widget.existing?['calendarTimeZone'] as String? ?? 'UTC',
  );
  late String _sort = widget.existing?['sort'] as String? ?? 'NEWEST';
  late List<String> _manualOrderFieldIds = (widget.existing?['manualOrderFieldIds'] as List<dynamic>? ?? const []).cast<String>().toList();
  late bool _group = widget.existing?['groupByFormat'] as bool? ?? false;
  late List<String> _formats =
      (widget.existing?['formatIds'] as List<dynamic>?)
          ?.cast<String>()
          .toList() ??
      (widget.formatId != null
          ? [widget.formatId!]
          : widget.collection.formats.map((item) => item.id).toList());
  late List<String> _columns =
      (widget.existing?['columnFieldIds'] as List<dynamic>?)
          ?.cast<String>()
          .toList() ??
      [];
  bool _busy = false;
  String? _error;
  bool get _fr => AppStrings.of(context).isFrench;

  @override
  void dispose() {
    _name.dispose();
    _timeZone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formats.isEmpty || _name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fields = widget.collection.formats
          .where((format) => _formats.contains(format.id))
          .expand((format) => format.fields)
          .map((field) => field.id)
          .toSet();
      final filterId =
          widget.existing?['filterFieldId'] as String? ??
          (_formats.length == 1 &&
                  _formats.single == widget.formatId &&
                  widget.filterValue.isNotEmpty
              ? widget.filterFieldId
              : null);
      final input = <String, dynamic>{
        'name': _name.text.trim(),
        'layout': _layout,
        'formatIds': _formats,
        'columnFieldIds': _columns.where(fields.contains).toList(),
        'search': widget.existing?['search'] as String? ?? widget.search,
        'sort': _sort,
        'manualOrderFieldIds': _sort == 'MANUAL' ? _manualOrderFieldIds.where(fields.contains).toList() : <String>[],
        'groupByFormat': _group,
        if (_layout == 'TASKS') ...{
          'taskDoneFieldId': _taskDone,
          if (_taskDue != null) 'taskDueFieldId': _taskDue,
          if (_taskCompleted != null) 'taskCompletedFieldId': _taskCompleted,
          if (_taskPriority != null) 'taskPriorityFieldId': _taskPriority,
        },
        if (_layout == 'CALENDAR') ...{
          'calendarStartFieldId': _calendarStart,
          'calendarEndFieldId': _calendarEnd,
          'calendarTimeZone': _timeZone.text.trim(),
        },
        if (filterId != null && fields.contains(filterId)) ...{
          'filterFieldId': filterId,
          'filterOperator':
              widget.existing?['filterOperator'] as String? ??
              widget.filterOperator,
          'filterValue':
              widget.existing?['filterValue'] as String? ?? widget.filterValue,
        },
      };
      final updated = await widget.api.saveView(
        widget.collection.id,
        input,
        viewId: widget.existing?['id'] as String?,
      );
      if (mounted) Navigator.pop(context, updated);
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
  Widget build(BuildContext context) {
    final fields = widget.collection.formats
        .where((format) => _formats.contains(format.id))
        .expand((format) => format.fields.map((field) => (format.name, field)))
        .toList();
    return AdaptiveFormDialog(
      title: Text(
        widget.existing == null
            ? (_fr ? 'Enregistrer une vue' : 'Save a view')
            : (_fr ? 'Modifier la vue' : 'Edit view'),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                maxLength: 80, buildCounter: quietFormCounter,
                decoration: InputDecoration(
                  labelText: _fr ? 'Nom de la vue' : 'View name',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(isExpanded: true, 
                initialValue: _layout,
                decoration: InputDecoration(
                  labelText: _fr ? 'Présentation' : 'Layout',
                ),
                items: [
                  DropdownMenuItem(
                    value: 'LIST',
                    child: Text(_fr ? 'Liste' : 'List', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'TABLE',
                    child: Text(_fr ? 'Tableau' : 'Table', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'CARDS',
                    child: Text(_fr ? 'Fiches' : 'Cards', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'TASKS',
                    child: Text(_fr ? 'Tâches' : 'Tasks', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'CALENDAR',
                    child: Text(_fr ? 'Agenda' : 'Calendar', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (widget.collection.taskPlanner != null || _layout.startsWith('TASK_')) ...[
                    DropdownMenuItem(value: 'TASK_DAY', child: Text(_fr ? 'Tâches du jour' : 'Tasks by day', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'TASK_CALENDAR', child: Text(_fr ? 'Calendrier des tâches' : 'Task calendar', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ],
                onChanged: (value) => setState(() {
                  _layout = value ?? 'LIST';
                  if (_layout == 'TASKS' || _layout == 'CALENDAR') {
                    _formats = _formats.take(1).toList();
                    _sort = 'NEWEST';
                  }
                  final planner = widget.collection.taskPlanner;
                  if (_layout.startsWith('TASK_') && planner != null) {
                    _formats = [planner['formatId'] as String];
                    _sort = 'NEWEST';
                  }
                }),
              ),
              const SizedBox(height: 12),
              Text(_fr ? 'Formats de données' : 'Data formats'),
              for (final format in widget.collection.formats)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(format.name),
                  value: _formats.contains(format.id),
                  onChanged: (checked) => setState(() {
                    _formats = checked == true
                        ? (_layout == 'TASKS' || _layout == 'CALENDAR'
                              ? [format.id]
                              : [..._formats, format.id])
                        : _formats.where((id) => id != format.id).toList();
                  }),
                ),
              if (_layout == 'TASKS') ...[
                _fieldChoice(
                  _fr ? 'Champ terminé (oui/non)' : 'Done field (yes/no)',
                  fields,
                  [BrainyFieldKind.boolean],
                  _taskDone,
                  (value) => setState(() => _taskDone = value),
                ),
                _fieldChoice(
                  _fr ? 'Échéance' : 'Due date',
                  fields,
                  [BrainyFieldKind.date, BrainyFieldKind.datetime],
                  _taskDue,
                  (value) => setState(() => _taskDue = value),
                ),
                _fieldChoice(
                  _fr ? 'Date d’achèvement' : 'Completion date',
                  fields,
                  [BrainyFieldKind.datetime],
                  _taskCompleted,
                  (value) => setState(() => _taskCompleted = value),
                ),
                _fieldChoice(
                  _fr ? 'Priorité' : 'Priority',
                  fields,
                  [BrainyFieldKind.select, BrainyFieldKind.number],
                  _taskPriority,
                  (value) => setState(() => _taskPriority = value),
                ),
              ],
              if (_layout == 'CALENDAR') ...[
                _fieldChoice(
                  _fr ? 'Début' : 'Start',
                  fields,
                  [BrainyFieldKind.datetime],
                  _calendarStart,
                  (value) => setState(() => _calendarStart = value),
                ),
                _fieldChoice(
                  _fr ? 'Fin' : 'End',
                  fields,
                  [BrainyFieldKind.datetime],
                  _calendarEnd,
                  (value) => setState(() => _calendarEnd = value),
                ),
                TextField(
                  controller: _timeZone,
                  decoration: InputDecoration(
                    labelText: _fr ? 'Fuseau horaire IANA' : 'IANA time zone',
                  ),
                ),
              ],
              if (_layout == 'TABLE') ...[
                Text(_fr ? 'Colonnes' : 'Columns'),
                for (final item in fields)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item.$1} · ${item.$2.name}'),
                    value: _columns.contains(item.$2.id),
                    onChanged: (checked) => setState(() {
                      _columns = checked == true
                          ? [..._columns, item.$2.id]
                          : _columns.where((id) => id != item.$2.id).toList();
                    }),
                  ),
              ],
              DropdownButtonFormField<String>(isExpanded: true, 
                initialValue: _sort,
                decoration: InputDecoration(labelText: _fr ? 'Tri' : 'Sort'),
                items: [
                  DropdownMenuItem(
                    value: 'NEWEST',
                    child: Text(_fr ? 'Plus récent d’abord' : 'Newest first', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'OLDEST',
                    child: Text(_fr ? 'Plus ancien d’abord' : 'Oldest first', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (_layout != 'TASKS' && _layout != 'CALENDAR') DropdownMenuItem(value: 'MANUAL', child: Text(_fr ? 'Ordre saisi' : 'Entered order', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _sort = value ?? 'NEWEST'),
              ),
              if (_sort == 'MANUAL') for (final format in widget.collection.formats.where((item) => _formats.contains(item.id))) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(isExpanded: true, 
                  key: ValueKey('manual-${format.id}-${_manualOrderFieldIds.join(',')}'),
                  initialValue: format.fields.where((field) => _manualOrderFieldIds.contains(field.id)).firstOrNull?.id,
                  decoration: InputDecoration(labelText: '${_fr ? 'Champ d’ordre' : 'Order field'} · ${format.name}'),
                  items: [for (final field in format.fields.where((item) => item.kind == BrainyFieldKind.number)) DropdownMenuItem(value: field.id, child: Text(field.name, maxLines: 1, overflow: TextOverflow.ellipsis))],
                  onChanged: (value) => setState(() { _manualOrderFieldIds = _manualOrderFieldIds.where((id) => !format.fields.any((field) => field.id == id)).toList(); if (value != null) _manualOrderFieldIds.add(value); }),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _fr
                      ? 'Grouper par format de données'
                      : 'Group by data format',
                ),
                value: _group,
                onChanged: (value) => setState(() => _group = value ?? false),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_fr ? 'Annuler' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _formats.isEmpty ? null : _save,
          child: Text(_fr ? 'Enregistrer' : 'Save'),
        ),
      ],
    );
  }

  Widget _fieldChoice(
    String label,
    List<(String, BrainyField)> fields,
    List<BrainyFieldKind> kinds,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    final options = fields
        .where((item) => kinds.contains(item.$2.kind))
        .toList();
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${_formats.join(',')}'),
      initialValue: options.any((item) => item.$2.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('—', maxLines: 1, overflow: TextOverflow.ellipsis)),
        for (final item in options)
          DropdownMenuItem(value: item.$2.id, child: Text(item.$2.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (next) => onChanged(next?.isEmpty == true ? null : next),
    );
  }
}
