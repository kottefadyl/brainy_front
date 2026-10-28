import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';
import 'push_registration.dart';

Future<void> showEntryReminderDialog(
  BuildContext context, {
  required CollectionsApi api,
  required BrainyCollection collection,
  required BrainyEntry entry,
  required PushRegistration push,
  Map<String, dynamic>? view,
}) => showDialog<void>(
  context: context,
  builder: (context) => _ReminderDialog(
    api: api,
    collection: collection,
    entry: entry,
    push: push,
    view: view,
  ),
);

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({
    required this.api,
    required this.collection,
    required this.entry,
    required this.push,
    this.view,
  });
  final CollectionsApi api;
  final BrainyCollection collection;
  final BrainyEntry entry;
  final PushRegistration push;
  final Map<String, dynamic>? view;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late final List<BrainyField> _fields = widget.collection
      .formatFor(widget.entry)
      .fields
      .where(
        (field) =>
            (field.kind == BrainyFieldKind.date ||
                field.kind == BrainyFieldKind.datetime) &&
            widget.entry.values[field.id]?.isNotEmpty == true,
      )
      .toList();
  String? _fieldId;
  String? _editingId;
  late final _zone = TextEditingController(
    text:
        widget.entry.recurrence?['timeZone'] as String? ??
        widget.view?['calendarTimeZone'] as String? ??
        'UTC',
  );
  final _clock = TextEditingController(text: '09:00');
  int _advance = 0;
  bool _email = false;
  bool _device = false;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  Map<String, bool> _capabilities = {};
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _devices = [];
  bool get _fr => AppStrings.of(context).isFrench;
  String t(String fr, String en) => _fr ? fr : en;

  @override
  void initState() {
    super.initState();
    _fieldId = _fields.firstOrNull?.id;
    _load();
  }

  @override
  void dispose() {
    _zone.dispose();
    _clock.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final capabilities = await widget.api.reminderCapabilities();
      final reminders = await widget.api.entryReminders(widget.entry.id);
      final devices = await widget.api.pushDevices();
      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        _reminders = reminders;
        _devices = devices;
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = AppStrings.of(context).error(error);
        });
      }
    }
  }

  void _edit(Map<String, dynamic> reminder) {
    setState(() {
      _editingId = reminder['id'] as String;
      _fieldId = reminder['fieldId'] as String;
      _zone.text = reminder['timeZone'] as String;
      _clock.text = reminder['timeOfDay'] as String? ?? '09:00';
      _advance = reminder['minutesBefore'] as int;
      final channels = (reminder['channels'] as List<dynamic>).cast<String>();
      _email = channels.contains('EMAIL');
      _device = channels.contains('PUSH');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final field = _fields.where((item) => item.id == _fieldId).firstOrNull;
    if (field == null) {
      throw StateError(t('Choisissez une date.', 'Choose a date.'));
    }
    final channels = [if (_email) 'EMAIL', if (_device) 'PUSH'];
    if (channels.isEmpty) {
      throw StateError(t('Choisissez un canal.', 'Choose a channel.'));
    }
    await widget.api.saveEntryReminder(widget.entry.id, {
      'fieldId': field.id,
      'minutesBefore': _advance,
      'channels': channels,
      'timeZone': _zone.text.trim(),
      if (field.kind == BrainyFieldKind.date) 'timeOfDay': _clock.text.trim(),
      if (widget.view?['layout'] == 'CALENDAR' &&
          widget.view?['calendarStartFieldId'] == field.id)
        'viewId': widget.view!['id'],
    }, reminderId: _editingId);
    _editingId = null;
  });

  @override
  Widget build(BuildContext context) {
    final selected = _fields.where((field) => field.id == _fieldId).firstOrNull;
    return AlertDialog(
      title: Text(t('Rappels', 'Reminders')),
      content: SizedBox(
        width: 470,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    if (_reminders.isNotEmpty) ...[
                      Text(
                        t(
                          'Rappels de cette entrée',
                          'Reminders for this entry',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      for (final reminder in _reminders)
                        ListTile(
                          dense: true,
                          title: Text(
                            '${_fields.where((f) => f.id == reminder['fieldId']).firstOrNull?.name ?? reminder['fieldId']} · ${reminder['state']}',
                          ),
                          subtitle: Text(
                            '${reminder['nextAt'] ?? '—'} · ${(reminder['channels'] as List<dynamic>).join(' + ')}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                onPressed: _busy ? null : () => _edit(reminder),
                                tooltip: t('Modifier', 'Edit'),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        () => widget.api.cancelEntryReminder(
                                          reminder['id'] as String,
                                        ),
                                      ),
                                tooltip: t('Annuler', 'Cancel'),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                    ],
                    if (_fields.isEmpty)
                      Text(
                        t(
                          'Renseignez un champ date ou date et heure dans cette entrée.',
                          'Fill in a date or date and time field in this entry.',
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _fieldId,
                        decoration: InputDecoration(
                          labelText: t('Champ de date', 'Date field'),
                        ),
                        items: [
                          for (final field in _fields)
                            DropdownMenuItem(
                              value: field.id,
                              child: Text(field.name),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _fieldId = value),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _zone,
                        decoration: InputDecoration(
                          labelText: t('Fuseau horaire IANA', 'IANA time zone'),
                          hintText: 'Africa/Lagos',
                        ),
                      ),
                      if (selected?.kind == BrainyFieldKind.date)
                        TextField(
                          controller: _clock,
                          decoration: InputDecoration(
                            labelText: t(
                              'Heure locale (HH:mm)',
                              'Local time (HH:mm)',
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: [0, 5, 15, 30, 60, 1440].contains(_advance)
                            ? _advance
                            : null,
                        decoration: InputDecoration(
                          labelText: t('Avant échéance', 'Before due time'),
                        ),
                        items: [
                          for (final minutes in [0, 5, 15, 30, 60, 1440])
                            DropdownMenuItem(
                              value: minutes,
                              child: Text(
                                minutes == 0
                                    ? t('À l’heure', 'At the time')
                                    : minutes == 1440
                                    ? t('Un jour avant', 'One day before')
                                    : '$minutes min',
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _advance = value ?? 0),
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(t('E-mail', 'Email')),
                        subtitle: _capabilities['email'] == true
                            ? null
                            : Text(
                                t(
                                  'SMTP non configuré',
                                  'SMTP is not configured',
                                ),
                              ),
                        value: _email,
                        onChanged: _capabilities['email'] == true && !_busy
                            ? (value) => setState(() => _email = value ?? false)
                            : null,
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t('Notification push', 'Push notification'),
                        ),
                        subtitle: _capabilities['push'] != true
                            ? Text(
                                t(
                                  'Firebase serveur non configuré',
                                  'Firebase server is not configured',
                                ),
                              )
                            : !PushRegistration.supported
                            ? Text(
                                t(
                                  'Push indisponible sur cet appareil',
                                  'Push is unavailable on this device',
                                ),
                              )
                            : _devices.isEmpty
                            ? Text(
                                t('Activez cet appareil', 'Enable this device'),
                              )
                            : null,
                        value: _device,
                        onChanged:
                            _capabilities['push'] == true &&
                                _devices.isNotEmpty &&
                                !_busy
                            ? (value) =>
                                  setState(() => _device = value ?? false)
                            : null,
                      ),
                      if (_capabilities['push'] == true &&
                          PushRegistration.supported)
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(() => widget.push.enable()),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(
                            t(
                              'Activer les notifications sur cet appareil',
                              'Enable notifications on this device',
                            ),
                          ),
                        ),
                      if (_devices.isNotEmpty) ...[
                        Text(t('Appareils enregistrés', 'Registered devices')),
                        for (final device in _devices)
                          ListTile(
                            dense: true,
                            title: Text(device['label'] as String),
                            subtitle: Text(device['platform'] as String),
                            trailing: IconButton(
                              tooltip: t(
                                'Retirer cet appareil',
                                'Remove this device',
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      () => widget.api.unregisterPushDevice(
                                        device['id'] as String,
                                      ),
                                    ),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(t('Fermer', 'Close')),
        ),
        if (_fields.isNotEmpty)
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              _editingId == null
                  ? t('Créer le rappel', 'Create reminder')
                  : t('Enregistrer', 'Save'),
            ),
          ),
      ],
    );
  }
}
