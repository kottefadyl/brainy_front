import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'collections_api.dart';
import 'ledger_api.dart';

Future<bool> showLedgerScreen(BuildContext context, CollectionsApi api, BrainyCollection collection, {required bool french, required String userId}) async =>
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _LedgerScreen(api: api, collection: collection, french: french, userId: userId))) ?? false;

class _LedgerScreen extends StatefulWidget {
  const _LedgerScreen({required this.api, required this.collection, required this.french, required this.userId});
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool french;
  final String userId;
  @override
  State<_LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<_LedgerScreen> {
  late final LedgerApi ledger = LedgerApi(widget.api);
  late BrainyCollection collection = widget.collection;
  late String formatId = collection.formats.firstWhere((item) => item.appendOnly, orElse: () => collection.formats.first).id;
  List<BrainyEntry> entries = [];
  Map<String, dynamic>? integrity;
  String? balance;
  String? fieldId;
  String? error;
  bool busy = false, loading = true, changed = false;

  String tr(String en, String fr) => widget.french ? fr : en;
  bool get isOwner => collection.ownerId == widget.userId;
  bool get canEdit => isOwner || collection.members.any((item) => item.userId == widget.userId && item.role != BrainyCollectionRole.reader);
  BrainyFormat get format => collection.formats.firstWhere((item) => item.id == formatId);
  String opposite(String value) => value.startsWith('-') ? value.substring(1) : value == '0' ? '0' : '-$value';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final all = await widget.api.entries(collection.id);
      final check = format.appendOnly ? await ledger.verify(collection.id, formatId) : null;
      if (mounted) setState(() { entries = all.where((item) => item.formatId == formatId).toList(); integrity = check; loading = false; });
    } catch (cause) { if (mounted) setState(() { error = '$cause'; loading = false; }); }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (mounted) setState(() { busy = true; error = null; });
    try { await action(); await _load(); }
    catch (cause) { if (mounted) setState(() => error = '$cause'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _correct(BrainyEntry original) async {
    final draft = <String, String>{for (final item in original.values.entries)
      if (item.value != '[redacted]' && !format.fields.any((field) => field.id == item.key && ['ATTACHMENT', 'OBJECT_REF'].contains(field.kind.wireName)))
        item.key: format.fields.any((field) => field.id == item.key && field.kind.wireName == 'NUMBER') ? opposite(item.value) : item.value};
    final controllers = {for (final item in draft.entries) item.key: TextEditingController(text: item.value)};
    final accepted = await showDialog<bool>(context: context, builder: (context) => AdaptiveFormDialog(
      title: Text(tr('Counter-writing', 'Contre-écriture')),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Number fields must contain the opposite amount.', 'Les champs numériques doivent contenir le montant opposé.')),
        const SizedBox(height: 12),
        for (final field in format.fields.where((item) => controllers.containsKey(item.id))) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controllers[field.id], decoration: InputDecoration(labelText: field.name, border: const OutlineInputBorder()), keyboardType: field.kind.wireName == 'NUMBER' ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancel', 'Annuler'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Add correction', 'Ajouter la correction')))],
    ));
    if (accepted == true) await _run(() async { await ledger.correct(original.id, {for (final item in controllers.entries) item.key: item.value.text}); changed = true; });
    for (final controller in controllers.values) { controller.dispose(); }
  }

  Future<void> _mask(BrainyEntry entry) async {
    final candidates = format.fields.where((field) => !['NUMBER', 'MEASURE'].contains(field.kind.wireName) && entry.values.containsKey(field.id) && entry.values[field.id] != '[redacted]').toList();
    final selected = <String>{};
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AdaptiveFormDialog(
      title: Text(tr('Mask fields', 'Masquer des champs')),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Selected values are erased; amounts remain and a trace is kept.', 'Les valeurs choisies sont effacées ; les montants restent et une trace est conservée.')),
        for (final field in candidates) CheckboxListTile(title: Text(field.name), value: selected.contains(field.id), onChanged: (value) => update(() { if (value == true) { selected.add(field.id); } else { selected.remove(field.id); } })),
        TextField(controller: reason, maxLength: 500, buildCounter: quietFormCounter, onChanged: (_) => update(() {}), decoration: InputDecoration(labelText: tr('Reason', 'Motif'), border: const OutlineInputBorder())),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancel', 'Annuler'))), FilledButton(onPressed: selected.isEmpty || reason.text.trim().isEmpty ? null : () => Navigator.pop(context, true), child: Text(tr('Mask selected fields', 'Masquer les champs choisis')))],
    )));
    if (accepted == true) await _run(() async { await ledger.redact(collection.id, formatId, entry.id, selected.toList(), reason.text.trim()); changed = true; });
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numberFields = format.fields.where((field) => field.kind.wireName == 'NUMBER').toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Register', 'Registre')), leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: tr('Back', 'Retour'), onPressed: () => Navigator.pop(context, changed))),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('Writings are added in order. Corrections remain linked to the original.', 'Les écritures s’ajoutent dans l’ordre. Les corrections restent liées à l’originale.')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(key: ValueKey(formatId), initialValue: formatId, isExpanded: true, decoration: InputDecoration(labelText: tr('Data format', 'Format de données'), border: const OutlineInputBorder()), items: [for (final item in collection.formats) DropdownMenuItem(value: item.id, child: Text('${item.name}${item.appendOnly ? tr(' · register', ' · registre') : ''}', maxLines: 1, overflow: TextOverflow.ellipsis))], onChanged: busy ? null : (value) { if (value != null) { setState(() { formatId = value; fieldId = null; }); _load(); } }),
        if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())) else if (!format.appendOnly) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Turn on the register for an empty data format. This cannot be undone here.', 'Activez le registre pour un format de données vide. Cette action ne peut pas être annulée ici.')),
          const SizedBox(height: 12),
          if (isOwner) FilledButton(onPressed: busy || entries.isNotEmpty || format.objectModel || format.workflow != null ? null : () => _run(() async { collection = await ledger.enable(collection.id, formatId); changed = true; }), child: Text(tr('Enable register', 'Activer le registre'))),
          if (entries.isNotEmpty) Text(tr('This data format already has entries.', 'Ce format de données contient déjà des entrées.')),
        ]))) else ...[
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Integrity', 'Intégrité'), style: Theme.of(context).textTheme.titleLarge),
            Text(integrity?['valid'] == true ? tr('${integrity?['checked']} writings verified', '${integrity?['checked']} écritures vérifiées') : '${integrity?['problem'] ?? tr('Verification needed', 'Vérification nécessaire')}'),
            Wrap(runSpacing: 8, spacing: 8, children: [OutlinedButton(onPressed: busy ? null : () => _run(() async { integrity = await ledger.verify(collection.id, formatId); }), child: Text(tr('Verify integrity', 'Vérifier l’intégrité'))), OutlinedButton(onPressed: busy ? null : () => _run(() async { final proof = await ledger.proof(collection.id, formatId); await FilePicker.saveFile(fileName: 'brainy-register-$formatId.json', bytes: Uint8List.fromList(utf8.encode(proof))); }), child: Text(tr('Export proof', 'Exporter la preuve')))]),
            Text(tr('Integrity evidence only; no accounting, medical or regulatory certification.', 'Preuve d’intégrité uniquement ; aucune certification comptable, médicale ou réglementaire.'), style: Theme.of(context).textTheme.bodySmall),
          ]))),
          if (isOwner && numberFields.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Current balance', 'Solde courant'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(isExpanded: true, key: ValueKey('balance-$formatId'), initialValue: fieldId, decoration: InputDecoration(labelText: tr('Number field', 'Champ numérique')), items: [for (final field in numberFields) DropdownMenuItem(value: field.id, child: Text(field.name, maxLines: 1, overflow: TextOverflow.ellipsis))], onChanged: (value) => setState(() { fieldId = value; balance = null; })),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: busy || fieldId == null ? null : () => _run(() async { balance = await ledger.balance(collection.id, formatId, fieldId!); }), child: Text(tr('Calculate', 'Calculer'))),
            if (balance != null) Text(balance!, style: Theme.of(context).textTheme.headlineSmall),
          ]))),
          const SizedBox(height: 12),
          Text(tr('Writings', 'Écritures'), style: Theme.of(context).textTheme.titleLarge),
          if (entries.isEmpty) Text(tr('No writings yet. Add an entry in this data format to begin.', 'Aucune écriture. Ajoutez une entrée dans ce format de données pour commencer.')),
          for (final entry in entries) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${entry.ledgerSequence} · ${MaterialLocalizations.of(context).formatMediumDate(entry.createdAt.toLocal())}', style: Theme.of(context).textTheme.titleMedium),
            if (entry.correctionOf != null) Text('${tr('Correction of', 'Correction de')} ${entry.correctionOf}'),
            for (final field in format.fields.where((item) => entry.values.containsKey(item.id))) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${field.name}: ${entry.values[field.id] == '[redacted]' ? tr('[masked]', '[masqué]') : entry.values[field.id]}')),
            Wrap(runSpacing: 8, spacing: 8, children: [if (canEdit) TextButton(onPressed: busy ? null : () => _correct(entry), child: Text(tr('Counter-writing', 'Contre-écriture'))), if (isOwner) TextButton(onPressed: busy ? null : () => _mask(entry), child: Text(tr('Mask fields', 'Masquer des champs')))]),
          ]))),
        ],
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ])),
    );
  }
}
