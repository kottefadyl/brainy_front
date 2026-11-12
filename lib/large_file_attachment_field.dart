// Attachment field of the entry editor. Up to 2 MiB the file travels with the entry;
// above, it is uploaded as a large file by reference (T44) with progress, pause and resume.
import 'media_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'collections_api.dart';
import 'large_file_api.dart';
import 'platform_capabilities.dart';

String largeFileStateLabel(String state, bool fr) => switch (state) {
  'AVAILABLE' => fr ? 'Vérifié : intact' : 'Verified: intact',
  'MISSING' => fr ? 'Absent du stockage' : 'Missing from storage',
  'CORRUPTED' =>
    fr ? 'Altéré : empreinte différente' : 'Altered: fingerprint differs',
  _ => state,
};

String formatFileSize(int size, bool fr) {
  final units = fr ? ['o', 'Kio', 'Mio', 'Gio'] : ['B', 'KiB', 'MiB', 'GiB'];
  var value = size.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '${fr ? text.replaceAll('.', ',') : text} ${units[unit]}';
}

class LargeFileAttachmentField extends StatefulWidget {
  const LargeFileAttachmentField({
    super.key,
    required this.api,
    required this.field,
    required this.collectionId,
    required this.controller,
    required this.french,
    required this.ink,
    required this.onSmallFile,
    required this.onLargeFile,
    required this.onClear,
    required this.onUploadingChanged,
    required this.onError,
    this.entry,
    this.largeFileId,
  });
  final CollectionsApi api;
  final BrainyField field;
  final String collectionId;
  final TextEditingController controller;
  final bool french;
  final Color ink;
  final BrainyEntry? entry;
  final String? largeFileId;
  final void Function(String name, Uint8List bytes) onSmallFile;
  final void Function(String largeFileId, String name) onLargeFile;
  final VoidCallback onClear;
  final ValueChanged<bool> onUploadingChanged;
  final ValueChanged<String> onError;

  @override
  State<LargeFileAttachmentField> createState() =>
      _LargeFileAttachmentFieldState();
}

class _LargeFileAttachmentFieldState extends State<LargeFileAttachmentField> {
  late final LargeFileApi _api = LargeFileApi(widget.api);
  PlatformFile? _pending;
  int _sent = 0;
  int _total = 0;
  bool _resumed = false;
  bool _uploading = false;
  bool _cancel = false;
  String? _failure;
  String? _status;
  int? _uploadedSize;

  bool get fr => widget.french;
  String _t(String en, String frText) => fr ? frText : en;

  int? get _savedSize {
    final entry = widget.entry;
    if (entry == null || widget.largeFileId != null) return null;
    if (entry.values[widget.field.id] != widget.controller.text) return null;
    return entry.largeFiles[widget.field.id];
  }

  Future<void> _pick() async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null || !mounted) return;
      final size = await file.length() ?? 0;
      if (size == 0) {
        widget.onError(_t('This file is empty.', 'Ce fichier est vide.'));
        return;
      }
      if (BrainyPlatform.isFrozen('mediaFiles') && isMediaFileName(file.name)) {
        widget.onError(mediaRefusedText(widget.french));
        return;
      }
      if (size <= largeFileThreshold) {
        setState(() => _pending = null);
        widget.onSmallFile(file.name, await file.readAsBytes());
        return;
      }
      // Large files need storage and uploads this hosting does not offer.
      if (BrainyPlatform.isFrozen('largeFiles')) {
        widget.onError(_t('Choose a file smaller than 2 MB.', 'Choisissez un fichier de moins de 2 Mo.'));
        return;
      }
      await _upload(file);
    } catch (error) {
      if (mounted) widget.onError(error.toString());
    }
  }

  Future<void> _upload(PlatformFile file) async {
    setState(() {
      _pending = file;
      _uploading = true;
      _cancel = false;
      _failure = null;
      _status = null;
      _sent = 0;
    });
    widget.onUploadingChanged(true);
    try {
      final id = await _api.upload(
        widget.collectionId,
        file.name,
        await file.length() ?? 0,
        file.readAsByteStream(),
        onProgress: (sent, total, resumed) {
          if (mounted) {
            setState(() {
              _sent = sent;
              _total = total;
              _resumed = resumed;
            });
          }
        },
        isCancelled: () => _cancel || !mounted,
      );
      if (!mounted) return;
      setState(() {
        _pending = null;
        _uploadedSize = _total;
      });
      widget.onLargeFile(id, file.name);
    } on LargeFileUploadCancelled {
      if (mounted) {
        setState(
          () => _failure = _t(
            'Upload paused. Resume to send the remaining parts.',
            'Envoi en pause. Reprenez pour envoyer les morceaux restants.',
          ),
        );
      }
    } catch (error) {
      final message = error.toString();
      if (mounted) {
        setState(
          () => _failure = fr && message.contains('Large files are limited')
              ? 'Ce fichier dépasse la taille maximale des fichiers volumineux.'
              : fr && message.contains('not configured')
              ? 'Le stockage des fichiers volumineux n’est pas configuré sur ce serveur.'
              : _t(
                  'Upload interrupted: $message. Resume to continue.',
                  'Envoi interrompu : $message. Reprenez pour continuer.',
                ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
      widget.onUploadingChanged(false);
    }
  }

  Future<void> _download() async {
    try {
      final uri = await _api.link(widget.entry!.id, widget.field.id);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      widget.onError(
        fr && error.toString().contains('missing from storage')
            ? 'Le fichier volumineux est absent du stockage.'
            : error.toString(),
      );
    }
  }

  Future<void> _verify() async {
    try {
      final state = await _api.verify(widget.entry!.id, widget.field.id);
      if (mounted) setState(() => _status = largeFileStateLabel(state, fr));
    } catch (error) {
      widget.onError(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final name = widget.controller.text;
    final savedSize = _savedSize;
    final size =
        savedSize ?? (widget.largeFileId != null ? _uploadedSize : null);
    final large = savedSize != null || widget.largeFileId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.field.name,
            style: TextStyle(fontWeight: FontWeight.w700, color: widget.ink),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pick,
            icon: const Icon(Icons.attach_file),
            label: Text(_t('Choose a file', 'Choisir un fichier')),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              'Files above 2 MiB are stored separately and sent in parts; if the connection drops, choose the same file again to resume.',
              'Au-delà de 2 Mio, le fichier est stocké à part et envoyé par morceaux ; en cas de coupure, rechoisissez le même fichier pour reprendre.',
            ),
            style: muted,
          ),
          if (_pending != null && (_uploading || _sent > 0)) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _total == 0 ? null : _sent / _total,
              semanticsLabel: _t(
                'Sending ${_pending!.name}',
                'Envoi de ${_pending!.name}',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_pending!.name} · ${formatFileSize(_sent, fr)} / ${formatFileSize(_total, fr)}${_resumed ? _t(' · resumed', ' · repris') : ''}',
              style: muted,
            ),
          ],
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _failure!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_uploading)
                TextButton(
                  onPressed: () => setState(() => _cancel = true),
                  child: Text(_t('Pause', 'Mettre en pause')),
                ),
              if (!_uploading && _pending != null)
                TextButton(
                  onPressed: () => _upload(_pending!),
                  child: Text(_t('Resume upload', 'Reprendre l’envoi')),
                ),
              if (!_uploading && _pending == null && name.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    '$name${size != null && size > 0 ? ' · ${formatFileSize(size, fr)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (large)
                  Chip(
                    label: Text(_t('large file', 'fichier volumineux')),
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  tooltip: _t('Remove file', 'Retirer le fichier'),
                  onPressed: () {
                    setState(() {
                      _status = null;
                      _uploadedSize = null;
                    });
                    widget.onClear();
                  },
                  icon: const Icon(Icons.close),
                ),
                if (savedSize != null) ...[
                  TextButton(
                    onPressed: _download,
                    child: Text(_t('Download', 'Télécharger')),
                  ),
                  TextButton(
                    onPressed: _verify,
                    child: Text(_t('Check integrity', 'Vérifier l’intégrité')),
                  ),
                ],
              ],
            ],
          ),
          if (_status != null)
            Semantics(liveRegion: true, child: Text(_status!)),
        ],
      ),
    );
  }
}
