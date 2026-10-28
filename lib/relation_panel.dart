import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';

class RelationPanel extends StatefulWidget {
  const RelationPanel({super.key, required this.api, required this.collection, required this.entry, required this.entries, required this.onOpenEntry});
  final CollectionsApi api;
  final BrainyCollection collection;
  final BrainyEntry entry;
  final List<BrainyEntry> entries;
  final ValueChanged<BrainyEntry> onOpenEntry;

  @override
  State<RelationPanel> createState() => _RelationPanelState();
}

class _RelationPanelState extends State<RelationPanel> {
  final quantity = TextEditingController(text: '1');
  final label = TextEditingController();
  List<Map<String, dynamic>> relations = [];
  List<BrainyUnit> units = [];
  String kind = 'ASSOCIATION', unit = 'item';
  String? targetId, fieldName, replacementId, total, error;
  String? snapshotFieldId;
  Map<String, dynamic>? impact;
  bool busy = false;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { quantity.dispose(); label.dispose(); super.dispose(); }

  String title(BrainyEntry entry) {
    final field = widget.collection.formatFor(entry).fields.where((item) => item.kind == BrainyFieldKind.title).firstOrNull;
    return field == null ? entry.id.substring(entry.id.length - 8) : entry.values[field.id] ?? entry.id.substring(entry.id.length - 8);
  }

  Future<void> load() async {
    try {
      final results = await Future.wait<Object>([widget.api.relations(widget.collection.id, widget.entry.id), widget.api.availableUnits(widget.collection.id)]);
      if (mounted) setState(() { relations = results[0] as List<Map<String, dynamic>>; units = results[1] as List<BrainyUnit>; error = null; });
    } catch (cause) { if (mounted) setState(() => error = cause.toString()); }
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() { busy = true; error = null; });
    try { await action(); } catch (cause) { if (mounted) setState(() => error = cause.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final candidates = widget.entries.where((item) => item.id != widget.entry.id).toList();
    final names = widget.collection.formats.expand((format) => format.fields.where((field) => field.kind == BrainyFieldKind.number || field.kind == BrainyFieldKind.measure).map((field) => field.name)).toSet().toList();
    final localIds = widget.collection.units.map((item) => item.id).toSet();
    final targetEntry = candidates.where((item) => item.id == targetId).firstOrNull;
    final snapshotFields = targetEntry == null ? <BrainyField>[] : widget.collection.formatFor(targetEntry).fields.where((field) => field.kind == BrainyFieldKind.number || field.kind == BrainyFieldKind.measure).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 32), Text(fr ? 'Relations structurées' : 'Structured relations', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8), Text(fr ? 'Créez une hiérarchie ou une composition avec quantité.' : 'Build a hierarchy or a composition with quantity.'),
      const SizedBox(height: 8), DropdownButtonFormField<String>(initialValue: kind, decoration: InputDecoration(labelText: fr ? 'Type de relation' : 'Relation type'), items: [DropdownMenuItem(value: 'ASSOCIATION', child: Text(fr ? 'Association' : 'Association')), DropdownMenuItem(value: 'PARENT', child: Text(fr ? 'Cette entrée a un parent' : 'This entry has a parent')), DropdownMenuItem(value: 'COMPONENT', child: Text(fr ? 'Cette entrée contient' : 'This entry contains'))], onChanged: busy ? null : (value) => setState(() => kind = value ?? kind)),
      const SizedBox(height: 8), DropdownButtonFormField<String>(key: ValueKey('relation-target-$targetId'), initialValue: candidates.any((item) => item.id == targetId) ? targetId : null, isExpanded: true, decoration: InputDecoration(labelText: fr ? 'Entrée cible' : 'Target entry'), items: [for (final item in candidates) DropdownMenuItem(value: item.id, child: Text(title(item), overflow: TextOverflow.ellipsis))], onChanged: busy ? null : (value) => setState(() => targetId = value)),
      if (kind == 'COMPONENT') ...[
        const SizedBox(height: 8), TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: fr ? 'Quantité' : 'Quantity')),
        const SizedBox(height: 8), DropdownButtonFormField<String>(initialValue: units.any((item) => item.id == unit) ? unit : null, isExpanded: true, decoration: InputDecoration(labelText: fr ? 'Unité' : 'Unit'), items: [for (final item in units) DropdownMenuItem(value: localIds.contains(item.id) ? 'local:${item.id}' : item.id, child: Text('${item.name} (${item.symbol})'))], onChanged: busy ? null : (value) => setState(() => unit = value ?? unit)),
        const SizedBox(height: 8), DropdownButtonFormField<String>(key: ValueKey('snapshot-$targetId-$snapshotFieldId'), initialValue: snapshotFields.any((field) => field.id == snapshotFieldId) ? snapshotFieldId : '', isExpanded: true, decoration: InputDecoration(labelText: fr ? 'Figer la valeur d’un champ (facultatif)' : 'Freeze a field value (optional)'), items: [DropdownMenuItem(value: '', child: Text(fr ? 'Valeur actuelle' : 'Current value')), for (final field in snapshotFields) DropdownMenuItem(value: field.id, child: Text(field.name))], onChanged: busy ? null : (value) => setState(() => snapshotFieldId = value)),
      ],
      const SizedBox(height: 8), TextField(controller: label, maxLength: 120, decoration: InputDecoration(labelText: fr ? 'Libellé facultatif' : 'Optional label')),
      FilledButton(onPressed: targetId == null || busy ? null : () => run(() async { await widget.api.createRelation(widget.collection.id, widget.entry.id, targetId!, kind, label.text.trim(), quantity: kind == 'COMPONENT' ? quantity.text.trim().replaceAll(',', '.') : null, unit: kind == 'COMPONENT' ? unit : null, snapshotFieldId: kind == 'COMPONENT' && snapshotFieldId?.isNotEmpty == true ? snapshotFieldId : null); targetId = null; label.clear(); await load(); }), child: Text(fr ? 'Ajouter la relation' : 'Add relation')),
      for (final relation in relations) ListTile(contentPadding: EdgeInsets.zero, title: Text(candidates.where((item) => item.id == (relation['fromEntryId'] == widget.entry.id ? relation['toEntryId'] : relation['fromEntryId'])).map(title).firstOrNull ?? '—'), subtitle: Text(relation['kind'] == 'COMPONENT' ? '${relation['quantity']} ${relation['unit']}' : relation['kind'] == 'PARENT' ? (relation['fromEntryId'] == widget.entry.id ? fr ? 'Parent' : 'Parent' : fr ? 'Enfant' : 'Child') : fr ? 'Association' : 'Association'), onTap: () { final other = candidates.where((item) => item.id == (relation['fromEntryId'] == widget.entry.id ? relation['toEntryId'] : relation['fromEntryId'])).firstOrNull; if (other != null) widget.onOpenEntry(other); }, trailing: TextButton(onPressed: busy ? null : () => run(() async { await widget.api.removeRelation(widget.collection.id, relation['id'] as String); await load(); }), child: Text(fr ? 'Retirer' : 'Remove'))),
      if (names.isNotEmpty) ...[
        const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: names.contains(fieldName) ? fieldName : null, isExpanded: true, decoration: InputDecoration(labelText: fr ? 'Champ numérique à totaliser' : 'Numeric field to total'), items: [for (final name in names) DropdownMenuItem(value: name, child: Text(name))], onChanged: (value) => setState(() => fieldName = value)),
        const SizedBox(height: 8), OutlinedButton(onPressed: busy || fieldName == null ? null : () => run(() async { final result = await widget.api.relationTotal(widget.collection.id, widget.entry.id, kind == 'PARENT' ? 'PARENT' : 'COMPONENT', fieldName!); setState(() => total = '${result['value']}${result['unit'] == null ? '' : ' ${result['unit']}'} · ${result['nodes']} ${fr ? 'entrées' : 'entries'}'); }), child: Text(fr ? 'Calculer le total' : 'Calculate total')),
        if (total != null) Text(total!, style: Theme.of(context).textTheme.titleMedium),
      ],
      if (relations.isNotEmpty) ...[
        const Divider(height: 32), Text(fr ? 'Avant de supprimer cette entrée' : 'Before deleting this entry', style: Theme.of(context).textTheme.titleMedium),
        DropdownButtonFormField<String>(key: ValueKey('relation-replacement-$replacementId'), initialValue: replacementId, isExpanded: true, decoration: InputDecoration(labelText: fr ? 'Remplacer par (facultatif)' : 'Replace with (optional)'), items: [DropdownMenuItem(value: '', child: Text(fr ? 'Détacher les relations' : 'Detach relations')), for (final item in candidates) DropdownMenuItem(value: item.id, child: Text(title(item), overflow: TextOverflow.ellipsis))], onChanged: (value) => setState(() { replacementId = value; impact = null; })),
        OutlinedButton(onPressed: busy ? null : () => run(() async { final preview = await widget.api.relationImpact(widget.collection.id, widget.entry.id, replacementId: replacementId?.isEmpty == true ? null : replacementId); setState(() => impact = preview); }), child: Text(fr ? 'Voir l’impact' : 'Preview impact')),
        if (impact != null) ...[Text('${(impact!['relations'] as List).length} ${fr ? 'relations touchées' : 'affected relations'}'), if (replacementId?.isNotEmpty == true && impact!['replacementAllowed'] != true) Text(fr ? 'Ce remplacement n’est pas possible.' : 'This replacement is not possible.') else FilledButton(onPressed: busy ? null : () => run(() async { await widget.api.detachRelations(widget.collection.id, widget.entry.id, replacementId: replacementId?.isEmpty == true ? null : replacementId); setState(() => impact = null); await load(); }), child: Text(fr ? 'Confirmer le détachement' : 'Confirm detachment'))],
      ],
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]);
  }
}
