import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';

Future<bool> showShareToCollection(
  BuildContext context, {
  required CollectionsApi api,
  required BrainyCollection source,
  required BrainyFormat format,
  required String objectId,
}) async => await showDialog<bool>(
  context: context,
  builder: (context) => _ShareDialog(api: api, source: source, format: format, objectId: objectId),
) ?? false;

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.api, required this.source, required this.format, required this.objectId});
  final CollectionsApi api;
  final BrainyCollection source;
  final BrainyFormat format;
  final String objectId;
  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  List<BrainyCollection> _targets = [];
  String? _targetId;
  late final Set<String> _properties = {widget.format.fields.firstWhere((field) => field.kind == BrainyFieldKind.title).id};
  String _mode = 'CURRENT';
  String? _error;
  bool _busy = false;
  bool get _fr => AppStrings.of(context).isFrench;

  @override
  void initState() {
    super.initState();
    widget.api.collections().then((items) { if (mounted) setState(() => _targets = items.where((item) => item.id != widget.source.id).toList()); }).catchError((Object error) { if (mounted) setState(() => _error = AppStrings.of(context).error(error)); });
  }

  Future<void> _share() async {
    if (_targetId == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.shareObject(widget.objectId, _targetId!, _properties.toList(), _mode);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = AppStrings.of(context).error(error); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleId = widget.format.fields.firstWhere((field) => field.kind == BrainyFieldKind.title).id;
    final target = _targets.where((item) => item.id == _targetId).firstOrNull;
    final conflict = target?.sharedObjects.any((grant) => grant['objectId'] == widget.objectId && grant['revokedAt'] == null) ?? false;
    return AlertDialog(
      title: Text(_fr ? 'Partager un objet par lien' : 'Share an object by link'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.source.name),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _targetId, isExpanded: true, decoration: InputDecoration(labelText: _fr ? 'Collection cible' : 'Target collection'), items: [for (final item in _targets) DropdownMenuItem(value: item.id, child: Text(item.name))], onChanged: (value) => setState(() => _targetId = value)),
        const SizedBox(height: 12),
        Text(_fr ? 'Caractéristiques autorisées' : 'Allowed properties', style: Theme.of(context).textTheme.titleSmall),
        for (final field in widget.format.fields)
          if (field.kind != BrainyFieldKind.objectRef && field.kind != BrainyFieldKind.attachment)
            CheckboxListTile(
              value: _properties.contains(field.id),
              title: Text(field.name),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: field.id == titleId ? null : (value) => setState(() { if (value == true) { _properties.add(field.id); } else { _properties.remove(field.id); } }),
            ),
        DropdownButtonFormField<String>(initialValue: _mode, decoration: InputDecoration(labelText: _fr ? 'Valeurs accessibles' : 'Accessible values'), items: [DropdownMenuItem(value: 'CURRENT', child: Text(_fr ? 'Actuelles jusqu’à révocation' : 'Current until revoked')), DropdownMenuItem(value: 'SNAPSHOT', child: Text(_fr ? 'Figées au partage' : 'Snapshot when shared'))], onChanged: (value) => setState(() => _mode = value ?? 'CURRENT')),
        Text(_fr ? 'Le stock et ses mouvements restent dans la collection source.' : 'Stock and its movements remain in the source collection.'),
        if (conflict) Text(_fr ? 'Cet objet est déjà lié à cette collection.' : 'This object is already linked to this collection.', style: const TextStyle(color: Colors.red)),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_fr ? 'Annuler' : 'Cancel')), FilledButton(onPressed: _busy || _targetId == null || conflict ? null : _share, child: Text(_fr ? 'Partager par lien' : 'Share by link'))],
    );
  }
}
