import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'collections_api.dart';

Future<bool> showClassificationScreen(BuildContext context, CollectionsApi api, BrainyCollection collection, List<BrainyCollection> targets, {required bool french}) async {
  await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ClassificationScreen(api: api, collection: collection, targets: targets, french: french)));
  return true;
}

class ClassificationScreen extends StatefulWidget {
  const ClassificationScreen({super.key, required this.api, required this.collection, required this.targets, required this.french});
  final CollectionsApi api;
  final BrainyCollection collection;
  final List<BrainyCollection> targets;
  final bool french;
  @override State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  late BrainyCollection collection = widget.collection;
  String? listId;
  final name = TextEditingController();
  List<Map<String, dynamic>> codes = [];
  bool busy = false;
  bool changed = false;
  String? error;
  String? notice;
  String t(String french, String english) => widget.french ? french : english;
  Map<String, dynamic>? get selected { for (final item in collection.codeLists) { if (item['id'] == listId) return item; } return null; }

  @override void dispose() { name.dispose(); super.dispose(); }

  void choose(Map<String, dynamic>? item) => setState(() {
    listId = item?['id'] as String?;
    name.text = item?['name'] as String? ?? '';
    codes = (item?['codes'] as List<dynamic>? ?? []).map((entry) => Map<String, dynamic>.from(entry as Map<String, dynamic>)).toList();
    error = null; notice = null;
  });

  Future<void> save() async {
    setState(() { busy = true; error = null; });
    try {
      final updated = await widget.api.saveClassification(collection.id, name.text, codes, listId: listId, expectedVersion: selected?['version'] as int?);
      if (!mounted) return;
      setState(() { collection = updated; changed = true; notice = t('Liste enregistrée', 'List saved'); busy = false; });
      if (listId == null) choose(updated.codeLists.firstWhere((item) => item['name'] == name.text));
    } catch (cause) { if (mounted) setState(() { error = '$cause'; busy = false; }); }
  }

  Future<void> importCsv() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      final preview = await widget.api.previewClassificationCsv(utf8.decode(bytes));
      final errors = (preview['errors'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        if (errors.isEmpty) { codes = (preview['codes'] as List<dynamic>).map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>)).toList(); notice = t('${codes.length} codes prêts. Vérifiez puis enregistrez.', '${codes.length} codes ready. Review and save.'); }
        else error = errors.map((item) => '${t('Ligne', 'Row')} ${item['row']}: ${item['message']}').join('\n');
      });
    } catch (cause) { if (mounted) setState(() => error = '$cause'); }
  }

  Future<void> copyList() async {
    final list = selected;
    if (list == null) return;
    String? targetId;
    Map<String, dynamic>? preview;
    final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: Text(t('Copier la liste', 'Copy code list')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(decoration: InputDecoration(labelText: t('Collection cible', 'Target collection')), items: [for (final item in widget.targets) if (item.id != collection.id) DropdownMenuItem(value: item.id, child: Text(item.name))], onChanged: (value) => update(() { targetId = value; preview = null; })),
        if (preview != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text('${preview!['sourceName']} → ${preview!['targetName']} · ${preview!['codeCount']} codes\n${(preview!['conflicts'] as List<dynamic>).join('; ')}')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('Annuler', 'Cancel'))), TextButton(onPressed: targetId == null ? null : () async { try { final value = await widget.api.classificationCopyPreview(collection.id, list['id'] as String, targetId!); update(() => preview = value); } catch (cause) { update(() => error = '$cause'); } }, child: Text(t('Aperçu', 'Preview'))), FilledButton(onPressed: preview?['allowed'] == true ? () async { try { await widget.api.copyClassification(collection.id, list['id'] as String, targetId!); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (cause) { update(() => error = '$cause'); } } : null, child: Text(t('Confirmer', 'Confirm')))],
    )));
    if (result == true && mounted) { setState(() => changed = true); Navigator.pop(context, true); }
  }

  Future<void> mergeCodes() async {
    final list = selected;
    if (list == null) return;
    String? source, target;
    Map<String, dynamic>? preview;
    final available = (list['codes'] as List<dynamic>).cast<Map<String, dynamic>>();
    final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: Text(t('Fusionner des codes', 'Merge codes')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(decoration: InputDecoration(labelText: t('Code source', 'Source code')), items: [for (final item in available) DropdownMenuItem(value: item['code'] as String, child: Text(item['code'] as String))], onChanged: (value) => update(() { source = value; preview = null; })),
        DropdownButtonFormField<String>(decoration: InputDecoration(labelText: t('Code cible', 'Target code')), items: [for (final item in available) if (item['active'] == true) DropdownMenuItem(value: item['code'] as String, child: Text(item['code'] as String))], onChanged: (value) => update(() { target = value; preview = null; })),
        if (preview != null) Text('${preview!['affectedEntries']} ${t('entrées affectées', 'affected entries')}'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('Annuler', 'Cancel'))), TextButton(onPressed: source == null || target == null ? null : () async { try { final value = await widget.api.classificationMergePreview(collection.id, list['id'] as String, source!, target!); update(() => preview = value); } catch (cause) { update(() => error = '$cause'); } }, child: Text(t('Aperçu', 'Preview'))), FilledButton(onPressed: preview?['allowed'] == true ? () async { try { collection = await widget.api.mergeClassificationCodes(collection.id, list['id'] as String, source!, target!, list['version'] as int); if (dialogContext.mounted) Navigator.pop(dialogContext, true); } catch (cause) { update(() => error = '$cause'); } } : null, child: Text(t('Confirmer', 'Confirm')))],
    )));
    if (result == true && mounted) { choose(collection.codeLists.firstWhere((item) => item['id'] == listId)); setState(() { changed = true; notice = t('Codes fusionnés', 'Codes merged'); }); }
  }

  @override Widget build(BuildContext context) {
    final list = selected;
    return Scaffold(
      appBar: AppBar(title: Text(t('Classifications', 'Classifications')), leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: t('Retour', 'Back'), onPressed: () => Navigator.pop(context, changed))),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850), child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('Les codes restent stables quand les libellés changent. Créez une liste avant d’ajouter un champ code à un format de données.', 'Codes stay stable when labels change. Create a list before adding a code field to a data format.')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(key: ValueKey(listId), initialValue: listId, decoration: InputDecoration(labelText: t('Liste de codes', 'Code list'), border: const OutlineInputBorder()), items: [for (final item in collection.codeLists) DropdownMenuItem(value: item['id'] as String, child: Text(item['name'] as String))], onChanged: (value) => choose(collection.codeLists.firstWhere((item) => item['id'] == value))),
        const SizedBox(height: 8), Wrap(spacing: 8, children: [OutlinedButton(onPressed: () => choose(null), child: Text(t('Nouvelle liste', 'New list'))), OutlinedButton(onPressed: () { choose(null); name.text = t('Niveaux d’études', 'Education levels'); setState(() => codes = [{'code': 'education', 'labelEn': 'Education', 'labelFr': 'Éducation', 'active': true}, {'code': 'primary', 'labelEn': 'Primary', 'labelFr': 'Primaire', 'parentCode': 'education', 'active': true}, {'code': 'secondary', 'labelEn': 'Secondary', 'labelFr': 'Secondaire', 'parentCode': 'education', 'active': true}, {'code': 'tertiary', 'labelEn': 'Tertiary', 'labelFr': 'Supérieur', 'parentCode': 'education', 'active': true}]); }, child: Text(t('Utiliser un modèle', 'Use starter list'))), OutlinedButton(onPressed: importCsv, child: Text(t('Importer CSV', 'Import CSV')))]),
        const SizedBox(height: 16), TextField(controller: name, maxLength: 80, decoration: InputDecoration(labelText: t('Nom de la liste', 'List name'), border: const OutlineInputBorder())),
        for (var index = 0; index < codes.length; index++) Card(key: ValueKey('code-$index-${codes[index]['code']}'), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          TextFormField(initialValue: codes[index]['code'] as String? ?? '', readOnly: list != null && (list['codes'] as List<dynamic>).any((item) => item['code'] == codes[index]['code']), decoration: InputDecoration(labelText: t('Code stable', 'Stable code')), onChanged: (value) => codes[index]['code'] = value),
          TextFormField(initialValue: codes[index]['labelEn'] as String? ?? '', decoration: const InputDecoration(labelText: 'English'), onChanged: (value) => codes[index]['labelEn'] = value),
          TextFormField(initialValue: codes[index]['labelFr'] as String? ?? '', decoration: const InputDecoration(labelText: 'Français'), onChanged: (value) => codes[index]['labelFr'] = value),
          DropdownButtonFormField<String>(initialValue: codes[index]['parentCode'] as String?, decoration: InputDecoration(labelText: t('Parent', 'Parent')), items: [DropdownMenuItem(value: '', child: Text(t('Aucun', 'None'))), for (final item in codes) if (item['code'] != codes[index]['code'] && (item['code'] as String? ?? '').isNotEmpty) DropdownMenuItem(value: item['code'] as String, child: Text(item['code'] as String))], onChanged: (value) => codes[index]['parentCode'] = value?.isEmpty == true ? null : value),
          SwitchListTile(title: Text(t('Actif', 'Active')), value: codes[index]['active'] as bool? ?? true, onChanged: (value) => setState(() => codes[index]['active'] = value)),
          if (list == null || !(list['codes'] as List<dynamic>).any((item) => item['code'] == codes[index]['code'])) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => codes.removeAt(index)), child: Text(t('Retirer', 'Remove')))),
        ]))),
        Wrap(spacing: 8, children: [OutlinedButton(onPressed: () => setState(() => codes.add({'code': '', 'labelEn': '', 'labelFr': '', 'active': true})), child: Text(t('Ajouter un code', 'Add code'))), FilledButton(onPressed: busy || name.text.trim().isEmpty || codes.isEmpty ? null : save, child: Text(t('Enregistrer', 'Save'))), if (list != null) OutlinedButton(onPressed: busy ? null : copyList, child: Text(t('Copier vers…', 'Copy to…'))), if (list != null) OutlinedButton(onPressed: busy ? null : mergeCodes, child: Text(t('Fusionner des codes', 'Merge codes')))]),
        if (notice != null) Text(notice!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ]))),
    );
  }
}
