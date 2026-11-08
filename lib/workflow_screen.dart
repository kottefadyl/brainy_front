import 'package:flutter/material.dart';

import 'collections_api.dart';
import 'workflow_api.dart';

Future<bool> showWorkflowScreen(
  BuildContext context,
  CollectionsApi api,
  BrainyCollection collection,
  String userId, {
  required bool french,
}) async =>
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkflowScreen(
          api: api,
          initial: collection,
          userId: userId,
          french: french,
        ),
      ),
    ) ??
    false;

class WorkflowScreen extends StatefulWidget {
  const WorkflowScreen({
    super.key,
    required this.api,
    required this.initial,
    required this.userId,
    required this.french,
  });
  final CollectionsApi api;
  final BrainyCollection initial;
  final String userId;
  final bool french;
  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  late BrainyCollection collection = widget.initial;
  String? formatId;
  BrainyEntryPage? page;
  String? currentAfter;
  final previousCursors = <String?>[];
  List<Map<String, dynamic>> notices = [];
  bool busy = false;
  bool changed = false;
  String? error;
  String t(String fr, String en) => widget.french ? fr : en;
  String dateLabel(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return '';
    final local = MaterialLocalizations.of(context);
    return '${local.formatMediumDate(date)} ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  String message(Object cause) {
    final value = '$cause';
    if (!widget.french) return value;
    const errors = <String, String>{
      'This transition is not allowed': 'Cette transition n’est pas autorisée.',
      'Change the state with a workflow transition':
          'Changez l’état avec une transition du flux.',
      'This entry changed elsewhere':
          'Cette entrée a été modifiée ailleurs. Actualisez et réessayez.',
      'Start this entry in the initial state':
          'Commencez cette entrée dans l’état initial.',
      'Only a collection owner can perform this action':
          'Seul le propriétaire de la collection peut effectuer cette action.',
      'Read-only members cannot modify collection data':
          'Les membres en lecture seule ne peuvent pas modifier la collection.',
      'Assign to the owner or an editor': 'Assignez l’entrée au propriétaire ou à un éditeur ayant accès à ce format de données.',
      'Choose a valid due date and time': 'Choisissez une échéance valide.',
      'This entry has no workflow': 'Cette entrée n’a pas de flux d’états.',
    };
    for (final item in errors.entries) {
      if (value.contains(item.key)) return item.value;
    }
    final required = RegExp(r'Fill in (.+) before entering (.+)')
        .firstMatch(value);
    if (required != null) {
      return 'Renseignez ${required[1]} avant de passer à ${required[2]}.';
    }
    return t('Opération impossible. Actualisez et réessayez.', value);
  }

  BrainyFormat? get format =>
      collection.formats.where((item) => item.id == formatId).firstOrNull;
  bool get owner => collection.ownerId == widget.userId;

  @override
  void initState() {
    super.initState();
    formatId =
        collection.formats
            .where((item) => item.workflow != null)
            .firstOrNull
            ?.id ??
        collection.formats.firstOrNull?.id;
    _load();
  }

  Future<void> _load({String? after}) async {
    try {
      final selected = format;
      final results = await Future.wait<dynamic>([
        selected?.workflow == null
            ? Future.value(null)
            : widget.api.entriesPage(
                collection.id,
                formatId: selected!.id,
                after: after,
              ),
        widget.api.workflowNotifications(),
      ]);
      if (mounted) {
        setState(() {
          page = results[0] as BrainyEntryPage?;
          notices = results[1] as List<Map<String, dynamic>>;
          error = null;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = message(cause));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      changed = true;
      await _load(after: currentAfter);
    } catch (cause) {
      if (mounted) setState(() => error = message(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addTemplate() async {
    final free = brainyFormatColors
        .where(
          (color) => !collection.formats.any((item) => item.color == color),
        )
        .firstOrNull;
    if (free == null) return;
    String template = 'TASK';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(t('Ajouter un format de données', 'Add a data format')),
          content: DropdownButtonFormField<String>(
            initialValue: template,
            decoration: InputDecoration(labelText: t('Modèle', 'Model')),
            items: [
              DropdownMenuItem(value: 'TASK', child: Text(t('Tâche', 'Task'))),
              DropdownMenuItem(
                value: 'APPROVAL',
                child: Text(t('Demande à valider', 'Approval request')),
              ),
              DropdownMenuItem(
                value: 'CASE',
                child: Text(t('Dossier suivi', 'Tracked case')),
              ),
            ],
            onChanged: (value) => update(() => template = value ?? 'TASK'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('Annuler', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, template),
              child: Text(t('Ajouter', 'Add')),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _run(() async {
      collection = await widget.api.addWorkflowTemplate(
        collection.id,
        selected,
        free,
        widget.french ? 'fr' : 'en',
      );
      formatId = collection.formats.last.id;
      currentAfter = null;
      previousCursors.clear();
    });
  }

  Future<void> _configure() async {
    final selected = format;
    if (selected == null) return;
    final choices = selected.fields
        .where(
          (field) =>
              field.kind == BrainyFieldKind.select && field.options.length >= 2,
        )
        .toList();
    if (choices.isEmpty) {
      setState(
        () => error = t(
          'Ajoutez d’abord un champ à choix unique avec au moins deux choix.',
          'Add a single-choice field with at least two choices first.',
        ),
      );
      return;
    }
    String fieldId =
        selected.workflow?['stateFieldId'] as String? ?? choices.first.id;
    String initial =
        selected.workflow?['initialState'] as String? ??
        choices.first.options.first;
    List<Map<String, dynamic>> transitions =
        ((selected.workflow?['transitions'] as List<dynamic>?) ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    if (transitions.isEmpty) {
      transitions = [
        for (var i = 0; i < choices.first.options.length - 1; i++)
          {
            'from': choices.first.options[i],
            'to': choices.first.options[i + 1],
            'minimumRole': 'EDITOR',
          },
      ];
    }
    List<Map<String, dynamic>> requirements =
        ((selected.workflow?['requirements'] as List<dynamic>?) ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final states = choices
              .firstWhere((field) => field.id == fieldId)
              .options;
          return AlertDialog(
            title: Text(t('Flux d’états', 'State flow')),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        'Les transitions protègent le champ d’état contre les modifications directes.',
                        'Transitions protect the state field from direct edits.',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: fieldId,
                      decoration: InputDecoration(
                        labelText: t('Champ d’état', 'State field'),
                      ),
                      items: [
                        for (final field in choices)
                          DropdownMenuItem(
                            value: field.id,
                            child: Text(field.name),
                          ),
                      ],
                      onChanged: (value) => update(() {
                        fieldId = value!;
                        initial = choices
                            .firstWhere((field) => field.id == fieldId)
                            .options
                            .first;
                        transitions = [
                          for (
                            var i = 0;
                            i <
                                choices
                                        .firstWhere(
                                          (field) => field.id == fieldId,
                                        )
                                        .options
                                        .length -
                                    1;
                            i++
                          )
                            {
                              'from': choices
                                  .firstWhere((field) => field.id == fieldId)
                                  .options[i],
                              'to': choices
                                  .firstWhere((field) => field.id == fieldId)
                                  .options[i + 1],
                              'minimumRole': 'EDITOR',
                            },
                        ];
                        requirements = [];
                      }),
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey('initial-$fieldId'),
                      initialValue: initial,
                      decoration: InputDecoration(
                        labelText: t('État initial', 'Initial state'),
                      ),
                      items: [
                        for (final state in states)
                          DropdownMenuItem(value: state, child: Text(state)),
                      ],
                      onChanged: (value) => update(() => initial = value!),
                    ),
                    const SizedBox(height: 12),
                    Text(t('Transitions autorisées', 'Allowed transitions')),
                    for (var i = 0; i < transitions.length; i++)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: transitions[i]['from'] as String,
                              isExpanded: true,
                              items: [
                                for (final state in states)
                                  DropdownMenuItem(
                                    value: state,
                                    child: Text(state),
                                  ),
                              ],
                              onChanged: (value) =>
                                  update(() => transitions[i]['from'] = value),
                            ),
                          ),
                          const Icon(Icons.arrow_forward),
                          Expanded(
                            child: DropdownButton<String>(
                              value: transitions[i]['to'] as String,
                              isExpanded: true,
                              items: [
                                for (final state in states)
                                  DropdownMenuItem(
                                    value: state,
                                    child: Text(state),
                                  ),
                              ],
                              onChanged: (value) =>
                                  update(() => transitions[i]['to'] = value),
                            ),
                          ),
                          DropdownButton<String>(
                            value: transitions[i]['minimumRole'] as String,
                            items: [
                              DropdownMenuItem(
                                value: 'EDITOR',
                                child: Text(t('Éditeur', 'Editor')),
                              ),
                              DropdownMenuItem(
                                value: 'OWNER',
                                child: Text(t('Propriétaire', 'Owner')),
                              ),
                            ],
                            onChanged: (value) => update(
                              () => transitions[i]['minimumRole'] = value,
                            ),
                          ),
                          IconButton(
                            tooltip: t('Retirer', 'Remove'),
                            onPressed: () =>
                                update(() => transitions.removeAt(i)),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    TextButton.icon(
                      onPressed: () => update(
                        () => transitions.add({
                          'from': states.first,
                          'to': states.last,
                          'minimumRole': 'EDITOR',
                        }),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        t('Ajouter une transition', 'Add transition'),
                      ),
                    ),
                    Text(
                      t('Champs requis par état', 'Required fields per state'),
                    ),
                    for (final state in states)
                      ExpansionTile(
                        title: Text(state),
                        children: [
                          for (final field in selected.fields.where(
                            (field) => field.id != fieldId,
                          ))
                            CheckboxListTile(
                              dense: true,
                              title: Text(field.name),
                              value:
                                  ((requirements
                                                  .where(
                                                    (row) =>
                                                        row['state'] == state,
                                                  )
                                                  .firstOrNull?['fieldIds']
                                              as List<dynamic>?) ??
                                          [])
                                      .contains(field.id),
                              onChanged: (checked) => update(() {
                                final ids = List<String>.from(
                                  (requirements
                                              .where(
                                                (row) => row['state'] == state,
                                              )
                                              .firstOrNull?['fieldIds']
                                          as List<dynamic>?) ??
                                      [],
                                );
                                if (checked == true) {
                                  ids.add(field.id);
                                } else {
                                  ids.remove(field.id);
                                }
                                requirements.removeWhere(
                                  (row) => row['state'] == state,
                                );
                                if (ids.isNotEmpty) {
                                  requirements.add({
                                    'state': state,
                                    'fieldIds': ids,
                                  });
                                }
                              }),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('Annuler', 'Cancel')),
              ),
              FilledButton(
                onPressed: transitions.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, {
                        'stateFieldId': fieldId,
                        'initialState': initial,
                        'transitions': transitions,
                        'requirements': requirements,
                        'expectedVersion': selected.version,
                      }),
                child: Text(t('Enregistrer', 'Save')),
              ),
            ],
          );
        },
      ),
    );
    if (saved != null) {
      await _run(() async {
        collection = await widget.api.setWorkflow(
          collection.id,
          selected.id,
          saved,
        );
      });
    }
  }

  Future<void> _assign(BrainyEntry entry) async {
    String assignee = entry.workflow?['assigneeUserId'] as String? ?? '';
    DateTime? due = DateTime.tryParse(entry.workflow?['dueAt'] as String? ?? '')
        ?.toLocal();
    int minutes =
        (entry.workflow?['reminderMinutesBefore'] as num?)?.toInt() ?? 60;
    final people = <String, String>{
      (collection.ownerId ?? widget.userId): t('Propriétaire', 'Owner'),
    };
    for (final member in collection.members) {
      if (member.role == BrainyCollectionRole.reader) continue;
      if (member.sharedFieldIds.isNotEmpty &&
          !format!.fields.every(
            (field) => member.sharedFieldIds.contains(field.id),
          )) {
        continue;
      }
      people[member.userId] = member.name.isEmpty ? member.email : member.name;
    }
    if (!people.containsKey(assignee)) assignee = '';
    final input = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(t('Assignation et échéance', 'Assignment and due date')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: assignee,
                decoration: InputDecoration(labelText: t('Compte', 'Account')),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(t('Non assigné', 'Unassigned')),
                  ),
                  for (final person in people.entries)
                    DropdownMenuItem(
                      value: person.key,
                      child: Text(person.value),
                    ),
                ],
                onChanged: (value) => update(() => assignee = value ?? ''),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: due ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null || !ctx.mounted) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(due ?? DateTime.now()),
                  );
                  if (time != null) {
                    update(
                      () => due = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.event),
                label: Text(
                  due == null
                      ? t('Choisir une échéance', 'Choose due date')
                      : MaterialLocalizations.of(ctx).formatMediumDate(due!),
                ),
              ),
              if (due != null)
                TextButton(
                  onPressed: () => update(() => due = null),
                  child: Text(t('Retirer l’échéance', 'Remove due date')),
                ),
              DropdownButtonFormField<int>(
                initialValue: minutes,
                decoration: InputDecoration(
                  labelText: t('Rappel avant échéance', 'Reminder before due'),
                ),
                items: ({0, 15, 60, 1440, minutes}.toList()..sort())
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value min'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => update(() => minutes = value ?? 60),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('Annuler', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'assigneeUserId': assignee,
                'dueAt': due?.toUtc().toIso8601String(),
                'reminderMinutesBefore': minutes,
                'expectedUpdatedAt': entry.updatedAt.toUtc().toIso8601String(),
              }),
              child: Text(t('Enregistrer', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (input != null) {
      await _run(() async {
        await widget.api.assignWorkflowEntry(entry.id, input);
      });
    }
  }

  Widget _entry(BrainyEntry entry) {
    final selected = format!;
    final flow = selected.workflow!;
    final state =
        entry.values[flow['stateFieldId']] ?? flow['initialState'] as String;
    final role = owner
        ? BrainyCollectionRole.owner
        : collection.members
                  .where((member) => member.userId == widget.userId)
                  .firstOrNull
                  ?.role ??
              BrainyCollectionRole.reader;
    final transitions = (flow['transitions'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where(
          (item) =>
              item['from'] == state &&
              (role == BrainyCollectionRole.owner ||
                  role == BrainyCollectionRole.editor &&
                      item['minimumRole'] == 'EDITOR'),
        )
        .toList();
    final titleId = selected.fields
        .where((field) => field.kind == BrainyFieldKind.title)
        .firstOrNull
        ?.id;
    final history = (entry.workflow?['history'] as List<dynamic>?) ?? [];
    return Card(
      child: ExpansionTile(
        title: Text(entry.values[titleId] ?? selected.name),
        subtitle: Text(
          '$state${entry.workflow?['dueAt'] == null ? '' : ' · ${dateLabel(entry.workflow!['dueAt'] as String?)}'}',
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          if (transitions.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final item in transitions)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _run(() async {
                            await widget.api.transitionWorkflowEntry(
                              entry.id,
                              item['to'] as String,
                              entry.updatedAt,
                            );
                          }),
                    child: Text('${item['to']}'),
                  ),
              ],
            ),
          if (role != BrainyCollectionRole.reader)
            TextButton.icon(
              onPressed: busy ? null : () => _assign(entry),
              icon: const Icon(Icons.person_outline),
              label: Text(
                t('Assignation et échéance', 'Assignment and due date'),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t('Historique', 'History'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (history.isEmpty)
            Text(t('Aucune transition', 'No transition yet')),
          for (final event in history.cast<Map<String, dynamic>>())
            ListTile(
              dense: true,
              title: Text('${event['from']} → ${event['to']}'),
              subtitle: Text(
                '${dateLabel(event['at'] as String?)} · ${event['actorUserId'] == collection.ownerId ? t('Propriétaire', 'Owner') : collection.members.where((member) => member.userId == event['actorUserId']).firstOrNull?.name ?? event['actorUserId']}',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = format;
    final free = brainyFormatColors.any(
      (color) => !collection.formats.any((item) => item.color == color),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(t('États et validations', 'States and approvals')),
        leading: IconButton(
          onPressed: () => Navigator.pop(context, changed),
          icon: const Icon(Icons.arrow_back),
          tooltip: t('Retour', 'Back'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t(
                'Assignez des entrées, fixez une échéance et suivez les états autorisés.',
                'Assign entries, set a due date and follow allowed states.',
              ),
            ),
            if (owner)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FilledButton.icon(
                  onPressed: busy || !free || collection.formats.length >= 24
                      ? null
                      : _addTemplate,
                  icon: const Icon(Icons.add),
                  label: Text(
                    t('Commencer avec un modèle', 'Start with a model'),
                  ),
                ),
              ),
            if (collection.formats.isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey(formatId),
                initialValue: formatId,
                decoration: InputDecoration(
                  labelText: t('Format de données', 'Data format'),
                ),
                items: [
                  for (final item in collection.formats)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) {
                  setState(() {
                    formatId = value;
                    currentAfter = null;
                    previousCursors.clear();
                  });
                  _load();
                },
              ),
            if (selected != null && owner)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: OutlinedButton(
                  onPressed: busy ? null : _configure,
                  child: Text(
                    t('Configurer le flux d’états', 'Configure state flow'),
                  ),
                ),
              ),
            if (selected?.workflow != null) ...[
              Text(
                t('Entrées', 'Entries'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final entry in page?.entries ?? <BrainyEntry>[])
                _entry(entry),
              if (previousCursors.isNotEmpty)
                TextButton(
                  onPressed: () {
                    currentAfter = previousCursors.removeLast();
                    _load(after: currentAfter);
                  },
                  child: Text(t('Page précédente', 'Previous page')),
                ),
              if (page?.hasMore == true)
                TextButton(
                  onPressed: () {
                    previousCursors.add(currentAfter);
                    currentAfter = page?.nextCursor;
                    _load(after: currentAfter);
                  },
                  child: Text(t('Page suivante', 'Next page')),
                ),
            ],
            if (notices.any(
              (item) => item['collectionId'] == collection.id,
            )) ...[
              Text(
                t('Assignations pour vous', 'Assignments for you'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final notice in notices.where(
                (item) => item['collectionId'] == collection.id,
              ))
                ListTile(
                  title: Text(t('Assigné', 'Assigned')),
                  subtitle: Text(dateLabel(notice['createdAt'] as String?)),
                  trailing: notice['readAt'] == null
                      ? TextButton(
                          onPressed: () => _run(() async {
                            await widget.api.readWorkflowNotification(
                              notice['id'] as String,
                            );
                          }),
                          child: Text(t('Marquer comme lu', 'Mark read')),
                        )
                      : null,
                ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
