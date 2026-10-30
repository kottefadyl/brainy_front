import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';

class WorkspaceBackupPanel extends StatefulWidget {
  const WorkspaceBackupPanel({super.key, required this.api, required this.onRestored});
  final CollectionsApi api;
  final VoidCallback onRestored;
  @override
  State<WorkspaceBackupPanel> createState() => _WorkspaceBackupPanelState();
}

class _WorkspaceBackupPanelState extends State<WorkspaceBackupPanel> {
  String? archive, error, notice;
  Map<String, dynamic>? preview;
  bool busy = false;
  bool includeSensitive = false;

  Future<void> run(Future<void> Function() action) async {
    setState(() { busy = true; error = null; notice = null; });
    try { await action(); }
    catch (cause) { if (mounted) setState(() => error = cause.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    return Card(child: ExpansionTile(title: Text(fr ? 'Sauvegarde de l’espace' : 'Workspace backup'), childrenPadding: const EdgeInsets.all(12), children: [
      Text(fr ? 'Le fichier contient vos collections, entrées, liens, historiques et mouvements. Gardez-le dans un lieu privé.' : 'The file contains your collections, entries, links, history, and movements. Keep it private.'),
      CheckboxListTile(value: includeSensitive, title: Text(fr ? 'Inclure explicitement les données personnelles et sensibles' : 'Explicitly include personal and sensitive data'), onChanged: busy ? null : (value) => setState(() => includeSensitive = value ?? false)),
      const SizedBox(height: 8), OutlinedButton(onPressed: busy ? null : () => run(() async { final data = await widget.api.workspaceBackup(includeSensitive: includeSensitive); final saved = await FilePicker.saveFile(fileName: 'brainy-workspace-${DateTime.now().toIso8601String().substring(0, 10)}.json', bytes: Uint8List.fromList(utf8.encode(data))); if (saved != null && mounted) { setState(() => notice = fr ? 'Fichier enregistré' : 'File saved'); } }), child: Text(fr ? 'Télécharger la sauvegarde' : 'Download backup')),
      OutlinedButton(onPressed: busy ? null : () => run(() async { final selected = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']); if (selected == null) return; final bytes = await selected.readAsBytes(); if (bytes.length > 50_000_000) throw const FormatException('Backup file exceeds 50 MB'); final content = utf8.decode(bytes); final result = await widget.api.restoreWorkspaceBackup(content, dryRun: true); if (mounted) setState(() { archive = content; preview = result; }); }), child: Text(fr ? 'Choisir un fichier à restaurer' : 'Choose a file to restore')),
      if (preview != null) ...[Text('${preview!['collections']} ${fr ? 'collections' : 'collections'} · ${preview!['entries']} ${fr ? 'entrées' : 'entries'} · ${preview!['relations']} ${fr ? 'relations' : 'relations'} · ${preview!['stockMovements']} ${fr ? 'mouvements' : 'movements'}'), for (final conflict in (preview!['conflicts'] as List<dynamic>)) Text(conflict.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)), if (preview!['allowed'] == true) FilledButton(onPressed: busy ? null : () => run(() async { final result = await widget.api.restoreWorkspaceBackup(archive!, dryRun: false); if (result['restored'] == true) { if (mounted) { setState(() { archive = null; preview = null; notice = fr ? 'Espace restauré' : 'Workspace restored'; }); } widget.onRestored(); } else if (mounted) { setState(() => preview = result); } }), child: Text(fr ? 'Confirmer la restauration' : 'Confirm restore'))],
      if (notice != null) Text(notice!),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]));
  }
}
