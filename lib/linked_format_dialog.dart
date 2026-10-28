import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';

Future<bool> showLinkedFormatUpdate(
  BuildContext context, {
  required CollectionsApi api,
  required BrainyCollection collection,
  required BrainyFormat format,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) =>
          _LinkedFormatDialog(api: api, collection: collection, format: format),
    ) ??
    false;

class _LinkedFormatDialog extends StatefulWidget {
  const _LinkedFormatDialog({
    required this.api,
    required this.collection,
    required this.format,
  });
  final CollectionsApi api;
  final BrainyCollection collection;
  final BrainyFormat format;

  @override
  State<_LinkedFormatDialog> createState() => _LinkedFormatDialogState();
}

class _LinkedFormatDialogState extends State<_LinkedFormatDialog> {
  Map<String, dynamic>? _preview;
  String? _error;
  bool _busy = false;
  bool get _fr => AppStrings.of(context).isFrench;

  @override
  void initState() {
    super.initState();
    widget.api
        .linkedDataFormatUpdatePreview(widget.collection.id, widget.format.id)
        .then((value) {
          if (mounted) setState(() => _preview = value);
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() => _error = AppStrings.of(context).error(error));
          }
        });
  }

  Future<void> _act(bool detach) async {
    if (!detach && _preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (detach) {
        await widget.api.detachLinkedDataFormat(
          widget.collection.id,
          widget.format.id,
        );
      } else {
        await widget.api.acceptLinkedDataFormatVersion(
          widget.collection.id,
          widget.format.id,
          (_preview!['sourceVersion'] as num).toInt(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppStrings.of(context).error(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _fr
          ? 'Mise à jour du format de données lié'
          : 'Linked data format update',
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.format.name),
            if (_preview != null) ...[
              const SizedBox(height: 12),
              Text(
                '${_fr ? 'Version acceptée' : 'Accepted version'}: ${_preview!['acceptedVersion']} · ${_fr ? 'Version source' : 'Source version'}: ${_preview!['sourceVersion']}',
              ),
              for (final label in [
                ('addedFields', _fr ? 'Champs ajoutés' : 'Added fields'),
                ('changedFields', _fr ? 'Champs modifiés' : 'Changed fields'),
                ('removedFields', _fr ? 'Champs supprimés' : 'Removed fields'),
              ])
                if ((_preview![label.$1] as List<dynamic>).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${label.$2}: ${(_preview![label.$1] as List<dynamic>).join(', ')}',
                    ),
                  ),
              for (final conflict in _preview!['conflicts'] as List<dynamic>)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    conflict as String,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(_fr ? 'Annuler' : 'Cancel'),
      ),
      TextButton(
        onPressed: _busy ? null : () => _act(true),
        child: Text(_fr ? 'Détacher' : 'Detach'),
      ),
      FilledButton(
        onPressed: _busy || _preview?['allowed'] != true
            ? null
            : () => _act(false),
        child: Text(_fr ? 'Accepter la version' : 'Accept version'),
      ),
    ],
  );
}
