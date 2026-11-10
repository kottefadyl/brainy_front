import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'referentials_api.dart';

/// Reads a chosen file; tests replace it.
typedef ReferentialFileReader = Future<({String name, List<int> bytes})?> Function();

Future<({String name, List<int> bytes})?> _pickReferentialFile() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv', 'json', 'txt']);
  if (file == null) return null;
  return (name: file.name, bytes: await file.readAsBytes());
}

/// Import of a standard referential (T39/1): CSV or JSON, previewed before
/// saving. Up to 5,000 codes the list stays editable as before; beyond, up
/// to 50,000, it is stored apart and searched on the server (T39/3).
class ReferentialImport extends StatefulWidget {
  const ReferentialImport({
    super.key,
    required this.french,
    required this.preview,
    required this.save,
    this.list,
    this.readFile = _pickReferentialFile,
  });

  final bool french;
  final Map<String, dynamic>? list;
  final Future<ReferentialPreview> Function(String format, String content) preview;
  final Future<void> Function(String name, String format, String content) save;
  final ReferentialFileReader readFile;

  @override
  State<ReferentialImport> createState() => _ReferentialImportState();
}

class _ReferentialImportState extends State<ReferentialImport> {
  late final _name = TextEditingController(text: widget.list?['name'] as String? ?? '');
  ({String name, String format, String content})? _file;
  ReferentialPreview? _preview;
  bool _busy = false;
  String? _error;
  String? _notice;

  String t(String french, String english) => widget.french ? french : english;
  String _count(int value) {
    final digits = value.toString();
    final out = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) out.write(widget.french ? ' ' : ',');
      out.write(digits[index]);
    }
    return out.toString();
  }

  String _summary(ReferentialPreview preview) {
    final codes = preview.codeCount == 1 ? '1 code' : '${_count(preview.codeCount)} codes';
    final levels = preview.levels == 1 ? t('1 niveau', '1 level') : t('${preview.levels} niveaux', '${preview.levels} levels');
    return t('$codes sur $levels', '$codes on $levels');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() { _error = null; _notice = null; _preview = null; _file = null; });
    final chosen = await widget.readFile();
    if (chosen == null || !mounted) return;
    if (chosen.bytes.length > maxReferentialBytes) {
      setState(() => _error = t('Fichier trop lourd : 4 Mo au plus.', 'File too large: 4 MB at most.'));
      return;
    }
    final String content;
    try {
      content = utf8.decode(chosen.bytes);
    } on FormatException {
      setState(() => _error = t('Le fichier doit être encodé en UTF-8.', 'The file must be UTF-8 encoded.'));
      return;
    }
    final format = referentialFormatOf(chosen.name, content);
    setState(() {
      _file = (name: chosen.name, format: format, content: content);
      if (_name.text.trim().isEmpty) {
        final base = chosen.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        _name.text = base.length > 80 ? base.substring(0, 80) : base;
      }
      _busy = true;
    });
    try {
      final preview = await widget.preview(format, content);
      if (mounted) setState(() => _preview = preview);
    } catch (cause) {
      if (mounted) setState(() => _error = '$cause');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final file = _file, preview = _preview;
    if (file == null || preview == null || preview.errors.isNotEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.save(_name.text.trim(), file.format, file.content);
      if (!mounted) return;
      setState(() {
        _notice = preview.codeCount == 1 ? t('1 code importé.', '1 code imported.') : t('${_count(preview.codeCount)} codes importés.', '${_count(preview.codeCount)} codes imported.');
        _file = null;
        _preview = null;
      });
    } catch (cause) {
      if (mounted) setState(() => _error = '$cause');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(color: colors.onSurfaceVariant);
    final preview = _preview;
    final ready = !_busy && _file != null && preview != null && preview.errors.isEmpty && _name.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('CSV (virgules ou points-virgules) avec les colonnes code et label, ou label_en et label_fr, et parent_code facultatif ; ou JSON, plat ou imbriqué avec children. Jusqu’à 50 000 codes sur 8 niveaux.',
            'CSV (commas or semicolons) with code and label, or label_en and label_fr, columns and an optional parent_code; or JSON, flat or nested with children. Up to 50,000 codes on 8 levels.'),
          style: muted,
        ),
        if (widget.list != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(t('Le fichier remplace la liste : chaque code existant doit y rester (marquez-le inactif plutôt que de le retirer).',
              'The file replaces the list: every existing code must stay in it (mark it inactive instead of removing it).')),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('referential-name'),
          controller: _name,
          maxLength: 80,
          buildCounter: quietFormCounter,
          decoration: InputDecoration(labelText: t('Nom de la liste', 'List name'), border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('referential-file'),
              onPressed: _busy ? null : _choose,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(_file == null ? t('Choisir un fichier', 'Choose a file') : _file!.name, overflow: TextOverflow.ellipsis),
            ),
            FilledButton(
              key: const ValueKey('referential-save'),
              onPressed: ready ? _save : null,
              child: Text(widget.list != null ? t('Remplacer la liste', 'Replace the list') : t('Importer la liste', 'Import the list')),
            ),
          ],
        ),
        if (_busy) Padding(padding: const EdgeInsets.only(top: 8), child: Semantics(liveRegion: true, child: Text(t('Lecture du fichier…', 'Reading the file…'), style: muted))),
        if (preview != null) _previewBlock(context, preview),
        if (_file == null && _notice == null && _error == null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(t('Choisissez un fichier et un nom pour continuer.', 'Choose a file and a name to continue.'), style: muted)),
        if (_notice != null) Padding(padding: const EdgeInsets.only(top: 8), child: Semantics(liveRegion: true, child: Text(_notice!, style: TextStyle(color: colors.primary)))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: colors.error)))),
      ],
    );
  }

  Widget _previewBlock(BuildContext context, ReferentialPreview preview) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const ValueKey('referential-preview'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_summary(preview), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (preview.large)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t('Grande liste : recherche côté serveur, modifiable seulement par un nouvel import.', 'Large list: searched on the server, changed only by a new import.'), style: TextStyle(color: colors.onSurfaceVariant)),
              ),
            const SizedBox(height: 6),
            if (preview.errors.isNotEmpty)
              for (final item in preview.errors.take(10))
                Text('${item.row > 0 ? t('Ligne ${item.row} : ', 'Row ${item.row}: ') : ''}${item.message}', style: TextStyle(color: colors.error))
            else
              for (final item in preview.sample.take(5))
                Text('${item['code']}  ${item[widget.french ? 'labelFr' : 'labelEn'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
