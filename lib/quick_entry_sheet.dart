import 'dart:convert';

import 'boolean_field_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'adaptive_form.dart';
import 'collections_api.dart';

Future<BrainyEntry?> showQuickEntrySheet(BuildContext context, {required CollectionsApi api, required BrainyCollection collection, required String userId, required bool french}) => showDialog<BrainyEntry>(context: context, barrierDismissible: false, builder: (_) => _QuickEntryDialog(api: api, collection: collection, userId: userId, french: french));

class _QuickEntryDialog extends StatefulWidget {
  const _QuickEntryDialog({required this.api, required this.collection, required this.userId, required this.french});
  final CollectionsApi api;
  final BrainyCollection collection;
  final String userId;
  final bool french;
  @override State<_QuickEntryDialog> createState() => _QuickEntryDialogState();
}

class _QuickEntryDialogState extends State<_QuickEntryDialog> {
  static const storage = FlutterSecureStorage();
  String? formatId;
  final values = <String, TextEditingController>{};
  final hidden = <String>{}, datesToday = <String>{};
  List<BrainyEntry> recent = [];
  int loadGeneration = 0;
  bool busy = false;
  String? error;
  bool get fr => widget.french;
  BrainyFormat? get format { for (final item in widget.collection.formats) { if (item.id == formatId) return item; } return null; }
  List<BrainyField> get fields => format?.fields.where((field) => [BrainyFieldKind.title, BrainyFieldKind.text, BrainyFieldKind.longText, BrainyFieldKind.number, BrainyFieldKind.date, BrainyFieldKind.datetime, BrainyFieldKind.boolean, BrainyFieldKind.select].contains(field.kind)).toList() ?? [];
  String get key => 'brainy:quick-entry:${widget.userId}:$formatId';
  @override void initState() { super.initState(); formatId = widget.collection.formats.where((item) => !item.objectModel).firstOrNull?.id; _load(); }
  @override void dispose() { for (final controller in values.values) { controller.dispose(); } super.dispose(); }
  String _today(BrainyField field) { final now = DateTime.now(); final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'; return field.kind == BrainyFieldKind.date ? date : '${date}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'; }
  Future<void> _load() async {
    final generation = ++loadGeneration;
    for (final controller in values.values) { controller.dispose(); }
    values.clear(); hidden.clear(); datesToday.clear(); recent = [];
    for (final field in fields) { values[field.id] = TextEditingController(); }
    try {
      final saved = await storage.read(key: key);
      if (generation != loadGeneration || !mounted) return;
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        for (final pair in (data['values'] as Map<String, dynamic>? ?? {}).entries) { if (values.containsKey(pair.key)) values[pair.key]!.text = pair.value as String; }
        hidden.addAll((data['hidden'] as List<dynamic>? ?? []).cast<String>());
        datesToday.addAll((data['today'] as List<dynamic>? ?? []).cast<String>());
      }
    } catch (_) {}
    if (mounted) setState(() {});
    try { final page = await widget.api.entriesPage(widget.collection.id, formatId: formatId); if (mounted && generation == loadGeneration) setState(() => recent = page.entries); } catch (_) {}
  }
  Future<void> _remember() async { try { await storage.write(key: key, value: jsonEncode({'values': {for (final item in values.entries) item.key: item.value.text}, 'hidden': hidden.toList(), 'today': datesToday.toList()})); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fr ? 'Modèle de saisie enregistré' : 'Entry template saved'))); } catch (cause) { if (mounted) setState(() => error = '$cause'); } }
  void _duplicate() { final last = recent.firstOrNull; if (last == null) return; for (final field in fields) { values[field.id]?.text = last.values[field.id] ?? ''; } setState(() {}); }
  Future<void> _save() async {
    if (formatId == null) return;
    setState(() { busy = true; error = null; });
    try {
      final payload = <String, String>{};
      for (final field in fields) {
        var value = datesToday.contains(field.id) ? _today(field) : values[field.id]?.text.trim() ?? '';
        if (field.kind == BrainyFieldKind.number) value = value.replaceAll(',', '.');
        if (field.kind == BrainyFieldKind.datetime && value.isNotEmpty) value = DateTime.parse(value).toUtc().toIso8601String();
        if (value.isNotEmpty) payload[field.id] = value;
      }
      if (payload.isEmpty) throw StateError(fr ? 'Renseignez au moins un champ.' : 'Fill in at least one field.');
      final entry = await widget.api.saveEntry(widget.collection.id, payload, formatId: formatId);
      if (mounted) Navigator.pop(context, entry);
    } catch (cause) { if (mounted) setState(() => error = fr ? 'Enregistrement impossible : $cause. Les valeurs sont conservées.' : 'Could not save: $cause. Values are kept.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _pickDate(BrainyField field) async {
    final controller = values[field.id]!;
    DateTime? initial;
    try { initial = DateTime.parse(controller.text); } catch (_) {}
    if (!mounted) return;
    final day = await showDatePicker(context: context, initialDate: initial ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (day == null || !mounted) return;
    final date = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    if (field.kind == BrainyFieldKind.date) { controller.text = date; return; }
    final time = await showTimePicker(context: context, initialTime: initial == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    controller.text = '${date}T${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  Widget _field(BrainyField field) {
    final controller = values[field.id]!;
    final suggestions = recent.map((entry) => entry.values[field.id]).whereType<String>().where((item) => item.isNotEmpty).toSet().take(3).toList();
    if (field.kind == BrainyFieldKind.boolean) return StatefulBuilder(builder: (context, setLocal) => BooleanFieldInput(label: field.name, value: controller.text, french: fr, onChanged: (next) => setLocal(() => controller.text = next)));
    final input = field.kind == BrainyFieldKind.select || field.kind == BrainyFieldKind.boolean
      ? DropdownButtonFormField<String>(isExpanded: true, key: ValueKey('${field.id}:${controller.text}'), initialValue: controller.text.isEmpty ? null : controller.text, hint: Text(fr ? 'Choisissez une valeur' : 'Choose a value', maxLines: 1, overflow: TextOverflow.ellipsis), decoration: InputDecoration(labelText: field.name), items: (field.kind == BrainyFieldKind.boolean ? ['true', 'false'] : field.options).map((item) => DropdownMenuItem(value: item, child: Text(item == 'true' ? fr ? 'Oui' : 'Yes' : item == 'false' ? fr ? 'Non' : 'No' : item, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) => controller.text = value ?? '')
      : [BrainyFieldKind.date, BrainyFieldKind.datetime].contains(field.kind) ? LocalizedDateField(controller: controller, kind: field.kind == BrainyFieldKind.date ? StoredDateKind.date : StoredDateKind.dateTime, label: field.name, enabled: !datesToday.contains(field.id), hint: datesToday.contains(field.id) ? localizedStoredDate(context, _today(field), field.kind == BrainyFieldKind.date ? StoredDateKind.date : StoredDateKind.dateTime) : null, onPick: () => _pickDate(field))
      : TextField(controller: controller, enabled: !datesToday.contains(field.id), readOnly: [BrainyFieldKind.date, BrainyFieldKind.datetime].contains(field.kind), onTap: [BrainyFieldKind.date, BrainyFieldKind.datetime].contains(field.kind) ? () => _pickDate(field) : null, keyboardType: field.kind == BrainyFieldKind.number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, maxLines: field.kind == BrainyFieldKind.longText ? 3 : 1, decoration: InputDecoration(labelText: field.name, hintText: datesToday.contains(field.id) ? _today(field) : null, suffixIcon: [BrainyFieldKind.date, BrainyFieldKind.datetime].contains(field.kind) ? const Icon(Icons.calendar_today_outlined) : null));
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [input, if (suggestions.isNotEmpty && [BrainyFieldKind.text, BrainyFieldKind.title, BrainyFieldKind.number].contains(field.kind)) Padding(padding: const EdgeInsets.only(top: 5), child: Wrap(spacing: 5, runSpacing: 4, children: suggestions.map((item) => ActionChip(label: Text(item, overflow: TextOverflow.ellipsis), onPressed: () { controller.text = item; setState(() {}); })).toList())), if ([BrainyFieldKind.date, BrainyFieldKind.datetime].contains(field.kind)) CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: datesToday.contains(field.id), title: Text(fr ? 'Date du jour' : 'Today'), onChanged: (value) => setState(() { value == true ? datesToday.add(field.id) : datesToday.remove(field.id); }))]));
  }
  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(fr ? 'Saisie rapide' : 'Quick entry'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fr ? 'Remplissez au moins un champ.' : 'Fill in at least one field.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(key: ValueKey(formatId), initialValue: formatId, isExpanded: true, decoration: InputDecoration(labelText: fr ? 'Format de données' : 'Data format'), items: widget.collection.formats.where((item) => !item.objectModel).map((item) => DropdownMenuItem(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { setState(() => formatId = value); _load(); }),
      if (recent.isNotEmpty) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _duplicate, icon: const Icon(Icons.content_copy_outlined), label: Text(fr ? 'Reprendre la dernière entrée' : 'Use last entry'))),
      const SizedBox(height: 14),
      if (formatId != null && fields.isEmpty) Text(fr ? 'Ce format de données utilise des champs avancés. Utilisez « Nouvelle entrée ».' : 'This data format uses advanced fields. Use New entry.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      for (final field in fields.where((item) => !hidden.contains(item.id))) _field(field),
      if (fields.any((item) => hidden.contains(item.id))) ExpansionTile(title: Text(fr ? 'Autres champs' : 'More fields'), tilePadding: EdgeInsets.zero, children: [for (final field in fields.where((item) => hidden.contains(item.id))) _field(field)]),
      ExpansionTile(title: Text(fr ? 'Personnaliser la saisie' : 'Customize entry form'), tilePadding: EdgeInsets.zero, children: [
        for (final field in fields) CheckboxListTile(dense: true, value: !hidden.contains(field.id), title: Text(field.name), onChanged: (value) => setState(() { value == true ? hidden.remove(field.id) : hidden.add(field.id); })),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _remember, icon: const Icon(Icons.bookmark_add_outlined), label: Text(fr ? 'Mémoriser les valeurs' : 'Remember values'))),
      ]),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(fr ? 'Annuler' : 'Cancel')), FilledButton(onPressed: busy || formatId == null || fields.isEmpty ? null : _save, child: Text(busy ? fr ? 'Enregistrement…' : 'Saving…' : fr ? 'Enregistrer l’entrée' : 'Save entry'))],
  );
}
