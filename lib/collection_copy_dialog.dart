import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';

Future<bool> showCopyToCollection(
  BuildContext context, {
  required CollectionsApi api,
  required BrainyCollection source,
  String? objectId,
  String? formatId,
  bool move = false,
  bool link = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _CopyToCollectionDialog(
        api: api,
        source: source,
        objectId: objectId,
        formatId: formatId,
        move: move,
        link: link,
      ),
    ) ??
    false;

class _CopyToCollectionDialog extends StatefulWidget {
  const _CopyToCollectionDialog({
    required this.api,
    required this.source,
    this.objectId,
    this.formatId,
    required this.move,
    required this.link,
  });
  final CollectionsApi api;
  final BrainyCollection source;
  final String? objectId;
  final String? formatId;
  final bool move;
  final bool link;
  @override
  State<_CopyToCollectionDialog> createState() =>
      _CopyToCollectionDialogState();
}

class _CopyToCollectionDialogState extends State<_CopyToCollectionDialog> {
  List<BrainyCollection> _targets = const [];
  String? _targetId;
  bool _withEntries = false;
  bool _busy = false;
  Map<String, dynamic>? _preview;
  String? _error;
  bool get _fr => AppStrings.of(context).isFrench;

  @override
  void initState() {
    super.initState();
    widget.api
        .collections()
        .then((items) {
          if (mounted) {
            setState(
              () => _targets = items
                  .where((item) => item.id != widget.source.id)
                  .toList(),
            );
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() => _error = AppStrings.of(context).error(error));
          }
        });
  }

  Future<void> _loadPreview() async {
    final target = _targetId;
    if (target == null) return;
    setState(() {
      _preview = null;
      _error = null;
    });
    try {
      final preview = widget.objectId != null
          ? widget.move
                ? await widget.api.objectMovePreview(widget.objectId!, target)
                : await widget.api.objectCopyPreview(widget.objectId!, target)
          : await widget.api.dataFormatCopyPreview(
              widget.formatId!,
              target,
              _withEntries && !widget.link,
            );
      if (mounted && _targetId == target) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    }
  }

  Future<void> _copy() async {
    if (_targetId == null || _preview?['allowed'] != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.objectId != null) {
        if (widget.move) {
          await widget.api.moveObject(widget.objectId!, _targetId!);
        } else {
          await widget.api.copyObject(widget.objectId!, _targetId!);
        }
      } else if (widget.link) {
        await widget.api.linkDataFormat(widget.formatId!, _targetId!);
      } else {
        await widget.api.copyDataFormat(
          widget.formatId!,
          _targetId!,
          _withEntries,
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
      widget.link
          ? (_fr ? 'Lier un format de données' : 'Link a data format')
          : widget.move
          ? (_fr ? 'Déplacer vers une collection' : 'Move to a collection')
          : (_fr ? 'Copier vers une collection' : 'Copy to a collection'),
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.source.name),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _targetId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _fr ? 'Collection cible' : 'Target collection',
              ),
              items: [
                for (final target in _targets)
                  DropdownMenuItem(value: target.id, child: Text(target.name)),
              ],
              onChanged: (value) {
                setState(() => _targetId = value);
                _loadPreview();
              },
            ),
            if (widget.formatId != null && !widget.link)
              CheckboxListTile(
                value: _withEntries,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _fr
                      ? 'Copier aussi les entrées et objets référencés'
                      : 'Also copy entries and referenced objects',
                ),
                onChanged: (value) {
                  setState(() => _withEntries = value ?? false);
                  _loadPreview();
                },
              ),
            if (widget.link)
              Text(
                _fr
                    ? 'La cible garde sa version et choisit quand accepter les changements de la source.'
                    : 'The target keeps its version and chooses when to accept source changes.',
              ),
            if (_preview != null) ...[
              Text(
                '${_preview!['entries']} ${_fr ? 'entrée(s), dont' : 'entries, including'} ${_preview!['objects']} ${_fr ? 'objet(s)' : 'objects'}',
              ),
              Text(
                '${_fr ? 'Formats de données' : 'Data formats'}: ${(_preview!['dataFormats'] as List<dynamic>).join(', ')}',
              ),
              if ((_preview!['units'] as List<dynamic>).isNotEmpty)
                Text(
                  '${_fr ? 'Unités' : 'Units'}: ${(_preview!['units'] as List<dynamic>).join(', ')}',
                ),
              if ((_preview!['formulas'] as List<dynamic>).isNotEmpty)
                Text(
                  '${_fr ? 'Formules copiées' : 'Copied formulas'}: ${(_preview!['formulas'] as List<dynamic>).join(', ')}',
                ),
              if ((_preview!['stockMovementCount'] as num? ?? 0) > 0)
                Text(_fr ? '${_preview!['stockMovementCount']} mouvement(s) de stock restent dans la collection source. La copie ne crée aucun stock dans la cible.' : '${_preview!['stockMovementCount']} stock movements remain in the source collection. Copying creates no stock in the target.'),
              for (final conflict in _preview!['conflicts'] as List<dynamic>)
                Text(
                  conflict as String,
                  style: const TextStyle(color: Colors.red),
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
      FilledButton(
        onPressed: _busy || _preview?['allowed'] != true ? null : _copy,
        child: Text(
          widget.link
              ? (_fr ? 'Lier' : 'Link')
              : widget.move
              ? (_fr ? 'Déplacer' : 'Move')
              : (_fr ? 'Copier' : 'Copy'),
        ),
      ),
    ],
  );
}
