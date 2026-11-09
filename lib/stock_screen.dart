import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'entry_editor_pickers.dart';
import 'adaptive_form.dart';
import 'collections_api.dart';
import 'ledger_api.dart';

Future<void> showStockScreen(
  BuildContext context,
  CollectionsApi api,
  BrainyCollection collection,
  String userId,
) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => _StockScreen(api: api, collection: collection, userId: userId),
  ),
);

class _StockScreen extends StatefulWidget {
  const _StockScreen({required this.api, required this.collection, required this.userId});
  final CollectionsApi api;
  final BrainyCollection collection;
  final String userId;
  @override
  State<_StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<_StockScreen> {
  late final LedgerApi ledger = LedgerApi(widget.api);
  Map<String, dynamic>? stockIntegrity;
  late BrainyCollection collection = widget.collection;
  List<BrainyEntry> entries = [];
  List<Map<String, dynamic>> positions = [], movements = [];
  final quantity = TextEditingController(),
      from = TextEditingController(),
      to = TextEditingController(),
      lot = TextEditingController(),
      reason = TextEditingController(),
      packageFactor = TextEditingController(text: '1'),
      priceSnapshot = TextEditingController(),
      occurredAt = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 16));
  String priceUnit = '';
  String? productId;
  String? reversalOf;
  String kind = 'IN';
  Map<String, dynamic>? draft, preview, sourcePreview;
  List<Map<String, dynamic>>? report;
  late bool allowNegative = collection.allowNegativeStock;
  final reportFrom = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final reportTo = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final ruleName = TextEditingController();
  String? ruleFormatId, ruleProductId, ruleQuantityId, ruleDateId, ruleFromId, ruleToId, ruleLotId, ruleReasonId;
  String ruleKind = 'IN';
  BrainyEntry? sourceEntry;
  String? sourceRuleId, error;
  bool busy = false;
  bool get fr => Localizations.localeOf(context).languageCode == 'fr';

  Future<void> checkStock({bool seal = false}) async {
    if (productId == null) return;
    setState(() { busy = true; error = null; });
    try {
      final status = seal ? await ledger.sealStock(collection.id, productId!) : await ledger.verifyStock(collection.id, productId!);
      if (mounted) setState(() => stockIntegrity = status);
    } catch (cause) { if (mounted) setState(() => error = '$cause'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> exportStockProof() async {
    if (productId == null) return;
    setState(() { busy = true; error = null; });
    try {
      final proof = await ledger.stockProof(collection.id, productId!);
      await FilePicker.saveFile(fileName: 'brainy-stock-$productId.json', bytes: Uint8List.fromList(utf8.encode(proof)));
    } catch (cause) { if (mounted) setState(() => error = '$cause'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final field in [
      quantity,
      from,
      to,
      lot,
      reason,
      packageFactor,
      priceSnapshot,
      occurredAt,
      reportFrom,
      reportTo,
      ruleName,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.api.entries(collection.id),
        widget.api.stockPositions(collection.id),
        widget.api.stockMovements(collection.id),
      ]);
      if (mounted) {
        setState(() {
          entries = results[0] as List<BrainyEntry>;
          positions = results[1] as List<Map<String, dynamic>>;
          movements = results[2] as List<Map<String, dynamic>>;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    }
  }

  String name(BrainyEntry entry) {
    final format = collection.formats.firstWhere(
      (item) => item.id == entry.formatId,
    );
    final titles = format.fields.where(
      (field) => field.kind == BrainyFieldKind.title,
    );
    return titles.isEmpty
        ? entry.id
        : entry.values[titles.first.id] ?? entry.id;
  }

  Future<void> previewManual() async {
    if (productId == null || quantity.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final input = <String, dynamic>{
        'kind': kind,
        'productId': productId,
        'quantity': quantity.text.trim().replaceAll(',', '.'),
        'packageFactor': packageFactor.text.trim().replaceAll(',', '.'),
        'fromLocation': from.text.trim(),
        'toLocation': to.text.trim(),
        'lot': lot.text.trim(),
        'reason': reason.text.trim(),
        'occurredAt': DateTime.parse(occurredAt.text).toUtc().toIso8601String(),
        if (priceSnapshot.text.trim().isNotEmpty) 'priceSnapshot': priceSnapshot.text.trim().replaceAll(',', '.'),
        if (priceSnapshot.text.trim().isNotEmpty && priceUnit.isNotEmpty) 'priceUnit': priceUnit,
        'idempotencyKey': 'manual:${DateTime.now().microsecondsSinceEpoch}',
      };
      final effect = await widget.api.previewStock(collection.id, input);
      if (mounted) {
        setState(() {
          draft = input;
          preview = effect;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmManual() async {
    if (draft == null || preview?['allowed'] != true) return;
    setState(() => busy = true);
    try {
      await widget.api.commitStock(collection.id, draft!);
      if (mounted) {
        setState(() {
          draft = null;
          preview = null;
          quantity.clear();
        });
      }
      await load();
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> previewReturn() async {
    if (reversalOf == null || quantity.text.trim().isEmpty) return;
    final original = movements.firstWhere((item) => item['id'] == reversalOf);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final input = <String, dynamic>{
        'kind': 'RETURN',
        'productId': original['productId'],
        'quantity': quantity.text.trim().replaceAll(',', '.'),
        'toLocation': original['fromLocation'],
        'lot': original['lot'],
        'reversalOf': reversalOf,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'idempotencyKey': 'return:${DateTime.now().microsecondsSinceEpoch}',
      };
      final effect = await widget.api.previewStock(collection.id, input);
      if (mounted) {
        setState(() {
          draft = input;
          preview = effect;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadReport() async {
    if (productId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = await widget.api.stockDailyReport(
        collection.id,
        productId!,
        reportFrom.text,
        reportTo.text,
        'UTC',
      );
      if (mounted) setState(() => report = rows);
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> previewSource(BrainyEntry entry, String ruleId) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final effect = await widget.api.previewEntryStock(
        collection.id,
        entry.id,
        ruleId,
      );
      if (mounted) {
        setState(() {
          sourceEntry = entry;
          sourceRuleId = ruleId;
          sourcePreview = effect;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmSource() async {
    if (sourceEntry == null ||
        sourceRuleId == null ||
        sourcePreview?['allowed'] != true) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.api.commitEntryStock(
        collection.id,
        sourceEntry!.id,
        sourceRuleId!,
        sourceEntry!.updatedAt.toUtc().toIso8601String(),
      );
      if (mounted) {
        setState(() {
          sourceEntry = null;
          sourcePreview = null;
        });
      }
      await load();
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveRule() async {
    if (ruleFormatId == null || ruleProductId == null || ruleQuantityId == null || ruleName.text.trim().isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final updated = await widget.api.saveStockRule(collection.id, {'name': ruleName.text.trim(), 'formatId': ruleFormatId, 'productFieldId': ruleProductId, 'quantityFieldId': ruleQuantityId, 'kind': ruleKind, if (ruleDateId != null) 'dateFieldId': ruleDateId, if (ruleFromId != null) 'fromLocationFieldId': ruleFromId, if (ruleToId != null) 'toLocationFieldId': ruleToId, if (ruleLotId != null) 'lotFieldId': ruleLotId, if (ruleReasonId != null) 'reasonFieldId': ruleReasonId});
      if (mounted) setState(() { collection = updated; ruleName.clear(); });
    } catch (cause) { if (mounted) setState(() => error = '$cause'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  String _effectLabel(String value, bool fr) => switch (value) {
    'IN' => fr ? 'Entrée' : 'In',
    'OUT' => fr ? 'Sortie' : 'Out',
    'TRANSFER' => fr ? 'Transfert' : 'Transfer',
    'RETURN' => fr ? 'Retour' : 'Return',
    _ => 'Correction',
  };

  String _reasonLabel(String reason, bool fr) => !fr
      ? reason
      : switch (reason) {
          'Stock would become negative' => 'Le stock deviendrait négatif',
          'The sale movement was not found' => 'La sortie d’origine est introuvable',
          'Return to the sale location and lot' => 'Le retour doit reprendre le lieu et le lot de la sortie',
          'Return quantity exceeds the sale' => 'La quantité retournée dépasse la sortie',
          _ => reason,
        };

  Widget ruleField(String label, String? value, List<BrainyField> fields, void Function(String?) changed) => DropdownButtonFormField<String>(isExpanded: true, 
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [const DropdownMenuItem<String>(value: null, child: Text('—', maxLines: 1, overflow: TextOverflow.ellipsis)), ...fields.map((field) => DropdownMenuItem(value: field.id, child: Text(field.name, maxLines: 1, overflow: TextOverflow.ellipsis)))],
    onChanged: changed,
  );

  Widget effect(Map<String, dynamic> value, VoidCallback confirm) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${value['productName']} · ${_effectLabel('${value['kind']}', fr)} · ${value['baseQuantity']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${fr ? 'Source' : 'From'}: ${value['beforeFrom']} → ${value['afterFrom']}',
          ),
          Text(
            '${fr ? 'Destination' : 'To'}: ${value['beforeTo']} → ${value['afterTo']}',
          ),
          if (value['reason'] != null)
            Text(
              _reasonLabel('${value['reason']}', fr),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed:
                busy ||
                    value['allowed'] != true ||
                    value['existingMovementId'] != null
                ? null
                : confirm,
            child: Text(fr ? 'Valider' : 'Confirm'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final rules = collection.stockRules;
    final productFormats = collection.formats
        .where(
          (format) =>
              format.objectModel &&
              (rules.isEmpty ||
                  rules.any(
                    (rule) => collection.formats.any(
                      (item) =>
                          item.id == rule['formatId'] &&
                          item.fields.any(
                            (field) =>
                                field.id == rule['productFieldId'] &&
                                field.targetObjectFormatId == format.id,
                          ),
                    ),
                  )),
        )
        .map((format) => format.id)
        .toSet();
    final products = entries
        .where((entry) => productFormats.contains(entry.formatId))
        .toList();
    final ruleFormat = collection.formats.where((item) => item.id == ruleFormatId).firstOrNull;
    final ruleFields = ruleFormat?.fields ?? <BrainyField>[];
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Stock' : 'Stock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            fr
                ? 'Soldes issus des mouvements validés. Vérifiez chaque effet avant validation.'
                : 'Balances come from confirmed movements. Review each effect before confirming.',
          ),
          ExpansionTile(title: Text(fr ? 'Configurer l’effet d’un format de données' : 'Configure a data format effect'), childrenPadding: const EdgeInsets.all(12), children: [
            Text(fr ? 'Associez un objet, une quantité et un effet. Chaque entrée demande une validation.' : 'Map an object, quantity and effect. Each entry requires confirmation.'),
            const SizedBox(height: 12),
            TextField(controller: ruleName, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: fr ? 'Nom de la règle' : 'Rule name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: ruleFormatId, decoration: InputDecoration(labelText: fr ? 'Format de données' : 'Data format'), items: [const DropdownMenuItem<String>(value: null, child: Text('—', maxLines: 1, overflow: TextOverflow.ellipsis)), ...collection.formats.where((item) => !item.objectModel).map((item) => DropdownMenuItem(value: item.id, child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)))], onChanged: (value) => setState(() { ruleFormatId = value; ruleProductId = null; ruleQuantityId = null; ruleDateId = null; ruleFromId = null; ruleToId = null; ruleLotId = null; ruleReasonId = null; })),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: ruleKind, decoration: InputDecoration(labelText: fr ? 'Effet' : 'Effect'), items: const ['IN', 'OUT', 'TRANSFER', 'CORRECTION'].map((value) => DropdownMenuItem(value: value, child: Text(_effectLabel(value, fr), maxLines: 1, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) => setState(() => ruleKind = value!)),
            const SizedBox(height: 12),
            ruleField(fr ? 'Objet' : 'Object', ruleProductId, ruleFields.where((field) => field.kind == BrainyFieldKind.objectRef && !field.multiple && collection.formats.any((item) => item.id == field.targetObjectFormatId && item.objectModel)).toList(), (value) => setState(() => ruleProductId = value)),
            const SizedBox(height: 12),
            ruleField(fr ? 'Quantité' : 'Quantity', ruleQuantityId, ruleFields.where((field) => field.kind == BrainyFieldKind.number).toList(), (value) => setState(() => ruleQuantityId = value)),
            const SizedBox(height: 12),
            ruleField(fr ? 'Date du fait' : 'Occurred at', ruleDateId, ruleFields.where((field) => field.kind == BrainyFieldKind.date || field.kind == BrainyFieldKind.datetime).toList(), (value) => setState(() => ruleDateId = value)),
            const SizedBox(height: 12),
            ruleField(fr ? 'Lieu source' : 'From location', ruleFromId, ruleFields.where((field) => field.kind == BrainyFieldKind.text || field.kind == BrainyFieldKind.select).toList(), (value) => setState(() => ruleFromId = value)),
            const SizedBox(height: 12),
            ruleField(fr ? 'Lieu destination' : 'To location', ruleToId, ruleFields.where((field) => field.kind == BrainyFieldKind.text || field.kind == BrainyFieldKind.select).toList(), (value) => setState(() => ruleToId = value)),
            const SizedBox(height: 12),
            ruleField(fr ? 'Lot' : 'Lot', ruleLotId, ruleFields.where((field) => field.kind == BrainyFieldKind.text || field.kind == BrainyFieldKind.select).toList(), (value) => setState(() => ruleLotId = value)),
            const SizedBox(height: 12),
            ruleField(fr ? 'Motif' : 'Reason', ruleReasonId, ruleFields.where((field) => [BrainyFieldKind.title, BrainyFieldKind.text, BrainyFieldKind.longText].contains(field.kind)).toList(), (value) => setState(() => ruleReasonId = value)),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: busy || ruleName.text.trim().isEmpty || ruleFormatId == null || ruleProductId == null || ruleQuantityId == null || (ruleKind == 'TRANSFER' && (ruleFromId == null || ruleToId == null)) ? null : saveRule, child: Text(fr ? 'Enregistrer la règle' : 'Save rule')),
            for (final rule in collection.stockRules) ListTile(title: Text('${rule['name']} · ${_effectLabel('${rule['kind']}', fr)}'), trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: fr ? 'Supprimer' : 'Delete', onPressed: busy ? null : () async { try { final updated = await widget.api.deleteStockRule(collection.id, rule['id'] as String); if (mounted) setState(() => collection = updated); } catch (cause) { if (mounted) setState(() => error = '$cause'); } })),
          ]),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          Text(
            fr ? 'Positions' : 'Positions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (positions.isEmpty)
            Text(
              fr ? 'Aucun mouvement validé.' : 'No confirmed movements yet.',
            ),
          for (final item in positions)
            Card(
              child: ListTile(
                title: Text('${item['productName']} · ${item['quantity']}'),
                subtitle: Text(
                  '${item['location'] == '' ? (fr ? 'Lieu par défaut' : 'Default location') : item['location']}${item['lot'] == '' ? '' : ' · ${item['lot']}'}',
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            fr ? 'Nouveau mouvement' : 'New movement',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(isExpanded: true, 
            initialValue: productId,
            decoration: InputDecoration(labelText: fr ? 'Produit' : 'Product'),
            items: products
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.id,
                    child: Text(name(entry), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              productId = value;
              preview = null;
              stockIntegrity = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(isExpanded: true, 
            initialValue: kind,
            decoration: InputDecoration(labelText: fr ? 'Effet' : 'Effect'),
            items: const ['IN', 'OUT', 'TRANSFER', 'CORRECTION']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(_effectLabel(value, fr), maxLines: 1, overflow: TextOverflow.ellipsis)),
                )
                .toList(),
            onChanged: (value) => setState(() {
              kind = value!;
              preview = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: fr ? 'Quantité' : 'Quantity',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: from,
            decoration: InputDecoration(
              labelText: fr ? 'Lieu source' : 'From location',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: to,
            decoration: InputDecoration(
              labelText: fr ? 'Lieu destination' : 'To location',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lot,
            decoration: InputDecoration(labelText: fr ? 'Lot' : 'Lot'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            decoration: InputDecoration(labelText: fr ? 'Motif' : 'Reason'),
          ),
          ExpansionTile(title: Text(fr ? 'Date du fait, conditionnement et prix' : 'Occurred at, package and price'), childrenPadding: const EdgeInsets.all(12), children: [
            LocalizedDateField(controller: occurredAt, kind: StoredDateKind.dateTime, clearable: false, label: fr ? 'Date du fait' : 'Occurred at', onPick: () => pickEntryDateTime(context, occurredAt)),
            const SizedBox(height: 12),
            TextField(controller: packageFactor, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: fr ? 'Unités par conditionnement' : 'Units per package')),
            const SizedBox(height: 12),
            TextField(controller: priceSnapshot, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: fr ? 'Prix instantané' : 'Price snapshot')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: priceUnit, decoration: InputDecoration(labelText: fr ? 'Devise du prix' : 'Price currency'), items: ['', 'EUR', 'USD', 'GBP', 'NGN'].map((value) => DropdownMenuItem(value: value, child: Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) => setState(() => priceUnit = value!)),
          ]),
          FilledButton.tonal(
            onPressed: busy ? null : previewManual,
            child: Text(fr ? 'Voir l’effet' : 'Preview effect'),
          ),
          if (preview != null && draft?['kind'] != 'RETURN') effect(preview!, confirmManual),
          const SizedBox(height: 16),
          Text(fr ? 'Retour de vente' : 'Sale return', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(isExpanded: true, 
            initialValue: reversalOf,
            decoration: InputDecoration(labelText: fr ? 'Sortie d’origine' : 'Original outgoing'),
            items: movements.where((item) => item['kind'] == 'OUT').map((item) => DropdownMenuItem(value: item['id'] as String, child: Text('${item['productName']} · ${item['baseQuantity']}', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) => setState(() { reversalOf = value; preview = null; }),
          ),
          Text(fr ? 'Utilisez la quantité ci-dessus ; le lieu et le lot d’origine sont repris.' : 'Use the quantity above; the original location and lot are reused.'),
          FilledButton.tonal(onPressed: busy || reversalOf == null ? null : previewReturn, child: Text(fr ? 'Voir le retour' : 'Preview return')),
          if (preview != null && draft?['kind'] == 'RETURN') effect(preview!, confirmManual),
          const SizedBox(height: 16),
          Text(fr ? 'Règle de stock négatif' : 'Negative stock policy', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(title: Text(fr ? 'Autoriser un solde négatif' : 'Allow negative balance'), value: allowNegative, onChanged: busy ? null : (value) async { setState(() => busy = true); try { final updated = await widget.api.setStockNegativePolicy(collection.id, value); if (mounted) setState(() => allowNegative = updated.allowNegativeStock); } catch (cause) { if (mounted) setState(() => error = '$cause'); } finally { if (mounted) setState(() => busy = false); } }),
          const SizedBox(height: 16),
          Text(fr ? 'Rapport quotidien (UTC)' : 'Daily report (UTC)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LocalizedDateField(controller: reportFrom, kind: StoredDateKind.date, clearable: false, label: fr ? 'Du' : 'From', onPick: () => pickEntryDate(context, reportFrom)),
          const SizedBox(height: 12),
          LocalizedDateField(controller: reportTo, kind: StoredDateKind.date, clearable: false, label: fr ? 'Au' : 'To', onPick: () => pickEntryDate(context, reportTo)),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: busy || productId == null ? null : loadReport, child: Text(fr ? 'Afficher' : 'Show')),
          if (report != null) for (final row in report!) ListTile(title: Text('${row['date']} · ${row['opening']} + ${row['incoming']} − ${row['outgoing']} = ${row['closing']}'), subtitle: Text((row['movements'] as List<dynamic>).cast<Map<String, dynamic>>().map((item) => '${_effectLabel('${item['kind']}', fr)} ${item['baseQuantity']}').join(' · '))),
          const SizedBox(height: 16),
          if (rules.isNotEmpty)
            Text(
              fr ? 'Entrées avec effet de stock' : 'Entries with stock effect',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          for (final entry in entries)
            for (final rule in rules.where(
              (rule) => rule['formatId'] == entry.formatId,
            ))
              ListTile(
                title: Text(
                  '${rule['name']} · ${entry.createdAt.toLocal().toString().substring(0, 10)}',
                ),
                trailing: TextButton(
                  onPressed:
                      busy ||
                          movements.any(
                            (movement) => movement['sourceEntryId'] == entry.id,
                          )
                      ? null
                      : () => previewSource(entry, rule['id'] as String),
                  child: Text(
                    movements.any(
                          (movement) => movement['sourceEntryId'] == entry.id,
                        )
                        ? (fr ? 'Validé' : 'Confirmed')
                        : (fr ? 'Voir l’effet' : 'Preview effect'),
                  ),
                ),
              ),
          if (sourcePreview != null) effect(sourcePreview!, confirmSource),
          const SizedBox(height: 16),
          Text(
            fr ? 'Historique' : 'History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final movement in movements)
            ListTile(
              title: Text(
                '${movement['productName']} · ${_effectLabel('${movement['kind']}', fr)} · ${movement['baseQuantity']}',
              ),
              subtitle: Text(
                '${movement['occurredAt'].toString().substring(0, 10)} · ${movement['fromLocation']} → ${movement['toLocation']}',
              ),
            ),
          const SizedBox(height: 16),
          Text(fr ? 'Intégrité du stock' : 'Stock integrity', style: Theme.of(context).textTheme.titleLarge),
          Text(fr ? 'Choisissez un produit ci-dessus pour vérifier ses mouvements. Les anciens mouvements peuvent être scellés une fois.' : 'Choose a product above to verify its movements. Older movements can be sealed once.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: busy || productId == null ? null : () => checkStock(), child: Text(fr ? 'Vérifier l’intégrité' : 'Verify integrity')),
            if (collection.ownerId == widget.userId) OutlinedButton(onPressed: busy || productId == null ? null : () => checkStock(seal: true), child: Text(fr ? 'Sceller l’historique' : 'Seal history')),
            OutlinedButton(onPressed: busy || productId == null ? null : exportStockProof, child: Text(fr ? 'Exporter la preuve' : 'Export proof')),
          ]),
          if (stockIntegrity != null) Text(stockIntegrity!['valid'] == true ? (fr ? '${stockIntegrity!['checked']} mouvements vérifiés' : '${stockIntegrity!['checked']} movements verified') : '${stockIntegrity!['problem']}'),
        ],
      ),
    );
  }
}
