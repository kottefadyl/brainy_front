import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'collections_api.dart';

class QuickCaptureBridge {
  static const _channel = MethodChannel('brainy/quick_capture');

  static Future<Map<String, String>?> takePending() async {
    try {
      final data = await _channel.invokeMapMethod<String, String>('takePending');
      return data;
    } on MissingPluginException { return null; }
  }

  static void install(void Function(Map<String, String>) onIncoming) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'incoming') return;
      final data = Map<String, String>.from(call.arguments as Map);
      await takePending();
      onIncoming(data);
    });
  }

  static void clear() => _channel.setMethodCallHandler(null);
}

Future<BrainyEntry?> showQuickCaptureSheet(
  BuildContext context, {
  required CollectionsApi api,
  required List<BrainyCollection> collections,
  required String userId,
  required bool french,
  Map<String, String>? incoming,
  void Function(BrainyCollection, BrainyEntry)? onOpenExisting,
}) => showDialog<BrainyEntry>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _QuickCaptureDialog(api: api, collections: collections, userId: userId, french: french, incoming: incoming, onOpenExisting: onOpenExisting),
);

class _QuickCaptureDialog extends StatefulWidget {
  const _QuickCaptureDialog({required this.api, required this.collections, required this.userId, required this.french, this.incoming, this.onOpenExisting});
  final CollectionsApi api;
  final List<BrainyCollection> collections;
  final String userId;
  final bool french;
  final Map<String, String>? incoming;
  final void Function(BrainyCollection, BrainyEntry)? onOpenExisting;
  @override State<_QuickCaptureDialog> createState() => _QuickCaptureDialogState();
}

class _QuickCaptureDialogState extends State<_QuickCaptureDialog> {
  static const storage = FlutterSecureStorage();
  late BrainyCollection collection = widget.collections.first;
  String? formatId;
  late final title = TextEditingController(text: widget.incoming?['title'] ?? '');
  late final content = TextEditingController(text: widget.incoming?['text'] ?? '');
  final note = TextEditingController();
  String? fileName;
  Uint8List? fileBytes;
  List<BrainyEntry> duplicates = [];
  bool checked = false, busy = false;
  String? error;
  bool get fr => widget.french;
  String get preferenceKey => 'brainy:capture:${widget.userId}';
  List<BrainyFormat> get formats => collection.formats.where((item) => !item.objectModel && item.fields.any((field) => [BrainyFieldKind.link, BrainyFieldKind.text, BrainyFieldKind.longText, BrainyFieldKind.title, BrainyFieldKind.attachment].contains(field.kind))).toList();
  BrainyFormat? get format { for (final item in formats) { if (item.id == formatId) return item; } return formats.isEmpty ? null : formats.first; }
  BrainyField? field(BrainyFieldKind kind, {String? except}) { for (final item in format?.fields ?? <BrainyField>[]) { if (item.kind == kind && item.id != except) return item; } return null; }
  bool get isUrl => RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(content.text.trim());
  @override void initState() { super.initState(); if (widget.incoming?['fileBase64'] != null) { try { fileBytes = base64Decode(widget.incoming!['fileBase64']!); fileName = widget.incoming!['fileName'] ?? 'shared-file'; } catch (_) { error = fr ? 'Fichier partagé illisible.' : 'Cannot read shared file.'; } } if (widget.incoming?['fileError'] != null) error = widget.incoming!['fileError']; if (isUrl && widget.incoming?['title'] == null) title.text = Uri.tryParse(content.text)?.host ?? ''; final shared = widget.incoming; if (shared != null && shared['url'] != null) { content.text = shared['url']!; if (shared['text'] != null && shared['text'] != shared['url']) note.text = shared['text']!; } _restore(); }
  Future<void> _restore() async { try { final id = await storage.read(key: preferenceKey); if (!mounted) return; for (final item in widget.collections) { if (item.id == id) { setState(() => collection = item); break; } } } catch (_) {} }
  @override void dispose() { title.dispose(); content.dispose(); note.dispose(); super.dispose(); }
  Future<void> _paste() async { try { content.text = (await Clipboard.getData('text/plain'))?.text ?? ''; setState(() { checked = false; duplicates = []; }); } catch (_) { setState(() => error = fr ? 'Presse-papiers indisponible.' : 'Clipboard unavailable.'); } }
  Future<void> _pick() async { final file = await FilePicker.pickFile(); if (file == null) return; final length = await file.length(); if (length == null || length > 2 * 1024 * 1024) { setState(() => error = fr ? 'Fichier limité à 2 Mio.' : 'File limited to 2 MiB.'); return; } final bytes = await file.readAsBytes(); setState(() { fileName = file.name; fileBytes = bytes; }); }
  Future<void> _save([bool allowDuplicate = false]) async {
    final selected = format; if (selected == null) return;
    setState(() { busy = true; error = null; });
    try {
      final link = field(BrainyFieldKind.link);
      final main = isUrl && link != null ? link : field(BrainyFieldKind.text) ?? field(BrainyFieldKind.longText) ?? field(BrainyFieldKind.title);
      final contextField = field(BrainyFieldKind.longText, except: main?.id) ?? field(BrainyFieldKind.text, except: main?.id);
      final titleField = field(BrainyFieldKind.title, except: main?.id);
      final attachment = field(BrainyFieldKind.attachment);
      if (note.text.trim().isNotEmpty && contextField == null) throw StateError(fr ? 'Ajoutez un champ de note à ce format de données.' : 'Add a note field to this data format.');
      if (fileBytes != null && attachment == null) throw StateError(fr ? 'Ajoutez un champ pièce jointe.' : 'Add an attachment field.');
      final sourceField = format?.fields.where((item) => item.kind == BrainyFieldKind.text && item.name.toLowerCase() == 'source' && item.id != main?.id && item.id != contextField?.id).firstOrNull;
      final values = <String, String>{if (main != null && content.text.trim().isNotEmpty) main.id: content.text.trim(), if (titleField != null && title.text.trim().isNotEmpty) titleField.id: title.text.trim(), if (contextField != null && note.text.trim().isNotEmpty) contextField.id: note.text.trim(), if (sourceField != null && widget.incoming != null) sourceField.id: 'Android share', if (attachment != null && fileName != null) attachment.id: fileName!};
      if (values.isEmpty) throw StateError(fr ? 'Ajoutez un lien, du texte ou un fichier.' : 'Add a link, text or file.');
      if (main?.kind == BrainyFieldKind.link && !checked && !allowDuplicate) { final matches = await widget.api.duplicateLinks(collection.id, selected.id, main!.id, content.text.trim()); if (matches.isNotEmpty) { setState(() { duplicates = matches; checked = true; }); return; } }
      final entry = await widget.api.saveEntry(collection.id, values, formatId: selected.id, attachments: attachment != null && fileBytes != null ? {attachment.id: fileBytes!} : {});
      if (mounted) Navigator.pop(context, entry);
    } catch (cause) { if (mounted) setState(() => error = fr ? 'Enregistrement impossible : $cause. Le contenu est conservé.' : 'Could not save: $cause. Your content is kept.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => AlertDialog(
    title: Text(fr ? 'Capture rapide' : 'Quick capture'),
    content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(initialValue: collection.id, decoration: InputDecoration(labelText: fr ? 'Collection' : 'Collection'), items: widget.collections.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(), onChanged: (value) { if (value == null) return; setState(() { collection = widget.collections.firstWhere((item) => item.id == value); formatId = null; checked = false; duplicates = []; }); storage.write(key: preferenceKey, value: value); }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(key: ValueKey(collection.id), initialValue: format?.id, decoration: InputDecoration(labelText: fr ? 'Format de données' : 'Data format'), items: formats.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(), onChanged: (value) => setState(() { formatId = value; checked = false; duplicates = []; })),
      TextField(controller: title, decoration: InputDecoration(labelText: fr ? 'Titre' : 'Title')),
      TextField(controller: content, maxLines: 3, onChanged: (_) => setState(() { checked = false; duplicates = []; }), decoration: InputDecoration(labelText: fr ? 'Lien ou texte' : 'Link or text')),
      TextButton(onPressed: _paste, child: Text(fr ? 'Coller le presse-papiers' : 'Paste clipboard')),
      TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: fr ? 'Note de contexte' : 'Context note')),
      TextButton(onPressed: _pick, child: Text(fileName ?? (fr ? 'Choisir une image ou un fichier' : 'Choose an image or file'))),
      if (duplicates.isNotEmpty) Text(fr ? 'Ce lien existe déjà.' : 'This link already exists.'),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]))),
    actions: [
      if (duplicates.isNotEmpty) TextButton(onPressed: () { Navigator.pop(context); widget.onOpenExisting?.call(collection, duplicates.first); }, child: Text(fr ? "Ouvrir l'existante" : 'Open existing')),
      if (duplicates.isNotEmpty) TextButton(onPressed: busy ? null : () => _save(true), child: Text(fr ? 'Ajouter quand même' : 'Add anyway')),
      TextButton(onPressed: () => Navigator.pop(context), child: Text(fr ? 'Annuler' : 'Cancel')),
      if (duplicates.isEmpty) FilledButton(onPressed: busy ? null : _save, child: Text(fr ? 'Enregistrer' : 'Save')),
    ],
  );
}
