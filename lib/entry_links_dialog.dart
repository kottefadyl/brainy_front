import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';
import 'relation_panel.dart';

Future<BrainyEntry?> showEntryLinksDialog(BuildContext context, CollectionsApi api, BrainyCollection collection, BrainyEntry entry) => showDialog<BrainyEntry>(context: context, builder: (context) => _EntryLinksDialog(api: api, collection: collection, entry: entry));

class _EntryLinksDialog extends StatefulWidget {
  const _EntryLinksDialog({required this.api, required this.collection, required this.entry});
  final CollectionsApi api;
  final BrainyCollection collection;
  final BrainyEntry entry;
  @override
  State<_EntryLinksDialog> createState() => _EntryLinksDialogState();
}

class _EntryLinksDialogState extends State<_EntryLinksDialog> {
  final search = TextEditingController();
  final label = TextEditingController();
  List<BrainyEntry> entries = [];
  List<Map<String, dynamic>> links = [];
  String? target, error;
  bool busy = false;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); label.dispose(); super.dispose(); }

  String title(BrainyEntry entry) {
    final format = widget.collection.formatFor(entry);
    final field = format.fields.where((item) => item.kind == BrainyFieldKind.title).firstOrNull;
    return field == null ? entry.id.substring(entry.id.length - 8) : entry.values[field.id] ?? entry.id.substring(entry.id.length - 8);
  }

  Future<void> load() async {
    try {
      final values = await Future.wait<Object>([widget.api.entries(widget.collection.id), widget.api.entryLinks(widget.collection.id, widget.entry.id, includeDeleted: true)]);
      if (mounted) setState(() { entries = values[0] as List<BrainyEntry>; links = values[1] as List<Map<String, dynamic>>; });
    } catch (cause) { if (mounted) setState(() => error = cause.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final candidates = entries.where((entry) => entry.id != widget.entry.id && title(entry).toLowerCase().contains(search.text.toLowerCase())).take(80).toList();
    return AlertDialog(title: Text(fr ? 'Liens entre entrées' : 'Entry links'), content: SizedBox(width: 600, height: 470, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fr ? 'Reliez deux entrées de cette collection sans créer d’objet. Les liens retirés restent restaurables.' : 'Link two entries in this collection without creating an object. Removed links can be restored.'), const SizedBox(height: 12),
      TextField(controller: search, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: fr ? 'Rechercher une entrée' : 'Find an entry', border: const OutlineInputBorder())), const SizedBox(height: 8),
      DropdownButtonFormField<String>(key: ValueKey('target-$target-${search.text}'), initialValue: candidates.any((item) => item.id == target) ? target : null, isExpanded: true, decoration: InputDecoration(labelText: fr ? 'Entrée cible' : 'Target entry', border: const OutlineInputBorder()), items: [for (final item in candidates) DropdownMenuItem(value: item.id, child: Text(title(item)))], onChanged: (value) => setState(() => target = value)), const SizedBox(height: 8),
      TextField(controller: label, maxLength: 120, decoration: InputDecoration(labelText: fr ? 'Libellé facultatif' : 'Optional label', border: const OutlineInputBorder())),
      FilledButton(onPressed: target == null || busy ? null : () async { setState(() { busy = true; error = null; }); try { await widget.api.createEntryLink(widget.collection.id, widget.entry.id, target!, label.text.trim()); target = null; label.clear(); await load(); } catch (cause) { if (mounted) setState(() => error = cause.toString()); } finally { if (mounted) setState(() => busy = false); } }, child: Text(fr ? 'Créer le lien' : 'Create link')),
      const Divider(height: 32), Text(fr ? 'Liens de cette entrée' : 'Entry links', style: Theme.of(context).textTheme.titleMedium),
      for (final link in links) ListTile(title: Text(entries.where((item) => item.id == (link['fromEntryId'] == widget.entry.id ? link['toEntryId'] : link['fromEntryId'])).map(title).firstOrNull ?? '—'), subtitle: Text(link['label'] as String? ?? ''), onTap: link['deletedAt'] != null ? null : () { final linked = entries.where((item) => item.id == (link['fromEntryId'] == widget.entry.id ? link['toEntryId'] : link['fromEntryId'])).firstOrNull; if (linked != null) Navigator.pop(context, linked); }, trailing: TextButton(onPressed: () async { try { await widget.api.setEntryLinkActive(widget.collection.id, link['id'] as String, link['deletedAt'] != null); await load(); } catch (cause) { if (mounted) setState(() => error = cause.toString()); } }, child: Text(link['deletedAt'] == null ? fr ? 'Retirer' : 'Remove' : fr ? 'Restaurer' : 'Restore'))),
      RelationPanel(api: widget.api, collection: widget.collection, entry: widget.entry, entries: entries, onOpenEntry: (linked) => Navigator.pop(context, linked)),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(fr ? 'Fermer' : 'Close'))]);
  }
}
