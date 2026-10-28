import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  Widget _field(BrainyField field) {
    final controller = values[field.id]!;
    final suggestions = recent.map((entry) => entry.values[field.id]).whereType<String>().where((item) => item.isNotEmpty).toSet().take(8).toList();
    final input = field.kind == BrainyFieldKind.select || field.kind == BrainyFieldKind.boolean
      ? DropdownButtonFormField<String>(initialValue: controller.text.isEmpty ? null : controller.text, decoration: InputDecoration(labelText: field.name), items: (field.kind == BrainyFieldKind.boolean ? ['true', 'false'] : field.options).map((item) => DropdownMenuItem(value: item, child: Text(item == 'true' ? fr ? 'Oui' : 'Yes' : item == 'false' ? fr ? 'Non' : 'No' : item))).toList(), onChanged: (value) => controller.text = value ?? '')
      : TextField(controller: controller, enabled: !datesToday.contains(field.id), keyboardType: field.kind == BrainyFieldKind.number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: field.name, hintText: datesToday.contains(field.id) ? _today(field) : null));
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [input, if (suggestions.isNotEmpty && [BrainyFieldKind.text, BrainyFieldKind.title, BrainyFieldKind.number].contains(field.kind)) Wrap(spacing: 4, children: suggestions.map((item) => ActionChip(label: Text(item), onPressed: () { controller.text = item; setState(() {}); })).toList()), if ([BrainyFieldKind.date, BrainyFieldKind.datetime].contains(field.kind)) CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: datesToday.contains(field.id), title: Text(fr ? 'Date du jour automatique' : 'Automatic current date'), onChanged: (value) => setState(() { value == true ? datesToday.add(field.id) : datesToday.remove(field.id); })), CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: hidden.contains(field.id), title: Text(fr ? 'Replier ce champ' : 'Fold this field'), onChanged: (value) => setState(() { value == true ? hidden.add(field.id) : hidden.remove(field.id); }))]));
  }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(fr ? 'Saisie rapide' : 'Quick entry'), content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: formatId, decoration: InputDecoration(labelText: fr ? 'Format de données' : 'Data format'), items: widget.collection.formats.where((item) => !item.objectModel).map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(), onChanged: (value) { setState(() => formatId = value); _load(); }), const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: recent.isEmpty ? null : _duplicate, child: Text(fr ? 'Dupliquer la dernière entrée' : 'Duplicate last entry'))), for (final field in fields) hidden.contains(field.id) ? ExpansionTile(key: ValueKey(field.id), title: Text(field.name), children: [_field(field)]) : _field(field), if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))]))), actions: [TextButton(onPressed: _remember, child: Text(fr ? 'Mémoriser les valeurs' : 'Remember values')), TextButton(onPressed: () => Navigator.pop(context), child: Text(fr ? 'Annuler' : 'Cancel')), FilledButton(onPressed: busy ? null : _save, child: Text(fr ? 'Enregistrer' : 'Save'))]);
}
