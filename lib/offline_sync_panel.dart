import 'dart:async';

import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';
import 'offline_entry_queue.dart';

class OfflineSyncPanel extends StatefulWidget {
  const OfflineSyncPanel({super.key, required this.api, required this.userId, required this.collections, required this.onSynced});
  final CollectionsApi api;
  final String userId;
  final List<BrainyCollection> collections;
  final VoidCallback onSynced;
  @override
  State<OfflineSyncPanel> createState() => _OfflineSyncPanelState();
}

class _OfflineSyncPanelState extends State<OfflineSyncPanel> {
  late OfflineEntryQueue queue = OfflineEntryQueue(widget.userId);
  List<Map<String, dynamic>> rows = [];
  Timer? timer;
  String? message;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    OfflineEntryQueue.changed.addListener(load);
    load().then((_) => sync());
    timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
  }
  @override
  void didUpdateWidget(covariant OfflineSyncPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) queue = OfflineEntryQueue(widget.userId);
    if (oldWidget.userId != widget.userId) load();
  }
  @override
  void dispose() { timer?.cancel(); OfflineEntryQueue.changed.removeListener(load); super.dispose(); }

  Future<void> load() async {
    try { final all = await queue.read(); if (mounted) setState(() => rows = all); }
    catch (error) { if (mounted) setState(() => message = error.toString()); }
  }

  Future<void> sync() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await queue.sync(widget.api);
      await load();
      if (result.synced > 0) widget.onSynced();
      if (mounted) setState(() => message = result.stopped);
    } catch (error) { if (mounted) setState(() => message = error.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> resolve(Map<String, dynamic> row, {required bool keepServer}) async {
    setState(() => busy = true);
    try {
      if (!keepServer) await widget.api.saveEntry(row['collectionId'] as String, (row['values'] as Map<String, dynamic>).cast<String, String>(), formatId: row['formatId'] as String, clientMutationId: '${row['id']}-copy');
      await queue.discard(row['id'] as String);
      await load(); widget.onSynced();
    } catch (error) { if (mounted) setState(() => message = error.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> compare(Map<String, dynamic> row) async {
    final french = AppStrings.of(context).isFrench;
    String server = '—';
    String showValues(Map<String, String> values) {
      final collection = widget.collections.where((item) => item.id == row['collectionId']).firstOrNull;
      final format = collection?.formats.where((item) => item.id == row['formatId']).firstOrNull;
      return values.entries.map((value) => '${format?.fields.where((field) => field.id == value.key).map((field) => field.name).firstOrNull ?? value.key}: ${value.value}').join(' · ');
    }
    try { if (row['entryId'] != null) { final entry = await widget.api.entry(row['collectionId'] as String, row['entryId'] as String); server = showValues(entry.values); } }
    catch (_) { /* The server entry may have been removed. */ }
    if (!mounted) return;
    final local = showValues((row['values'] as Map<String, dynamic>).cast<String, String>());
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text(french ? 'Comparer les valeurs' : 'Compare values'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${french ? 'Sur cet appareil' : 'On this device'}: $local'), const SizedBox(height: 12), Text('${french ? 'Sur le serveur' : 'On server'}: $server')]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(french ? 'Fermer' : 'Close'))]));
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && message == null) return const SizedBox.shrink();
    final fr = AppStrings.of(context).isFrench;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${fr ? 'Modifications en attente' : 'Pending changes'} · ${rows.length}', style: Theme.of(context).textTheme.titleMedium),
      Text(fr ? 'Conservées sur cet appareil jusqu’à la synchronisation.' : 'Kept on this device until synced.'),
      OutlinedButton(onPressed: busy || rows.isEmpty ? null : sync, child: Text(busy ? fr ? 'Synchronisation…' : 'Syncing…' : fr ? 'Synchroniser' : 'Sync now')),
      for (final row in rows) ListTile(contentPadding: EdgeInsets.zero, title: Text('${widget.collections.where((item) => item.id == row['collectionId']).map((item) => item.name).firstOrNull ?? row['collectionId']} · ${row['entryId'] == null ? fr ? 'Nouvelle entrée' : 'New entry' : fr ? 'Modification' : 'Edit'}'), subtitle: row['status'] == 'conflict' ? Text('${fr ? 'Conflit' : 'Conflict'}: ${row['error']}', style: TextStyle(color: Theme.of(context).colorScheme.error)) : null, trailing: row['status'] == 'conflict' ? PopupMenuButton<String>(tooltip: fr ? 'Résoudre le conflit' : 'Resolve conflict', onSelected: (value) { if (value == 'compare') compare(row); if (value == 'server') resolve(row, keepServer: true); if (value == 'copy') resolve(row, keepServer: false); }, itemBuilder: (context) => [PopupMenuItem(value: 'compare', child: Text(fr ? 'Comparer les valeurs' : 'Compare values')), PopupMenuItem(value: 'server', child: Text(fr ? 'Garder le serveur' : 'Keep server')), PopupMenuItem(value: 'copy', child: Text(fr ? 'Créer une nouvelle entrée' : 'Create a new entry'))]) : null),
      if (message != null) Text(message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ])));
  }
}
