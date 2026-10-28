import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';
import 'collection_copy_dialog.dart';
import 'collection_share_dialog.dart';

typedef ObjectEditorRequest = ({String formatId, BrainyEntry? entry});

class ObjectDialog extends StatefulWidget {
  const ObjectDialog({
    super.key,
    required this.collection,
    required this.api,
    required this.onCollection,
    required this.onEntriesChanged,
  });
  final BrainyCollection collection;
  final CollectionsApi api;
  final ValueChanged<BrainyCollection> onCollection;
  final VoidCallback onEntriesChanged;

  @override
  State<ObjectDialog> createState() => _ObjectDialogState();
}

class _ObjectDialogState extends State<ObjectDialog> {
  late BrainyCollection _collection = widget.collection;
  final _templateName = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _templates = [];
  List<BrainyEntry> _objects = [];
  String? _templateId;
  String? _existingId;
  String? _formatId;
  String? _cursor;
  String? _target;
  Map<String, dynamic>? _detail;
  String? _error;
  bool _busy = false;
  bool _started = false;

  String _t(String text) => AppStrings.of(context).text(text);
  bool get _fr => AppStrings.of(context).isFrench;
  List<BrainyFormat> get _models =>
      _collection.formats.where((format) => format.objectModel).toList();

  @override
  void initState() {
    super.initState();
    _formatId = _models.firstOrNull?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadTemplates();
      _load();
    });
  }

  @override
  void dispose() {
    _templateName.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await widget.api.objectTemplates(_fr ? 'fr' : 'en');
      if (mounted) setState(() => _templates = templates);
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    }
  }

  Future<void> _revoke(String grantId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.revokeObjectShare(_collection.id, grantId);
      final collections = await widget.api.collections();
      final updated = collections.firstWhere(
        (item) => item.id == _collection.id,
      );
      if (mounted) {
        setState(() => _collection = updated);
        widget.onCollection(updated);
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load({bool more = false}) async {
    final formatId = _formatId;
    if (formatId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.api.objectsPage(
        _collection.id,
        formatId,
        after: more ? _cursor : null,
        search: _search.text.trim(),
      );
      if (mounted && formatId == _formatId) {
        setState(() {
          _objects = more ? [..._objects, ...page.entries] : page.entries;
          _cursor = page.nextCursor;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createTemplate() async {
    final template = _templateId;
    final name = _templateName.text.trim();
    final color = brainyFormatColors
        .where(
          (color) =>
              !_collection.formats.any((format) => format.color == color),
        )
        .firstOrNull;
    if (template == null || name.isEmpty || color == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.api.addObjectTemplate(
        _collection.id,
        template,
        name,
        color,
        _fr ? 'fr' : 'en',
      );
      widget.onCollection(updated);
      setState(() {
        _collection = updated;
        _formatId = updated.formats.last.id;
        _templateId = null;
        _templateName.clear();
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markExisting() async {
    final format = _collection.formats
        .where((item) => item.id == _existingId)
        .firstOrNull;
    if (format == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final impact = await widget.api.formatImpact(_collection.id, format.id);
      if (!mounted) return;
      if (impact.entryCount > 0) {
        setState(() => _busy = false);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_fr ? 'Convertir en objets ?' : 'Convert to objects?'),
            content: Text(
              _fr
                  ? 'Les ${impact.entryCount} entrées de ce format de données deviendront des objets. Leurs valeurs seront conservées.'
                  : 'All ${impact.entryCount} entries in this data format will become objects. Their values will be kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_t('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_fr ? 'Confirmer' : 'Confirm'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
        setState(() => _busy = true);
      }
      final updated = await widget.api.setObjectModel(
        _collection.id,
        format,
        true,
        expectedEntryCount: impact.entryCount > 0 ? impact.entryCount : null,
      );
      widget.onCollection(updated);
      setState(() {
        _collection = updated;
        _formatId = format.id;
        _existingId = null;
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDetail(BrainyEntry entry) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await widget.api.objectDetail(entry.id);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _duplicate() async {
    if (_detail == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.duplicateObject(_detail!['id'] as String);
      widget.onEntriesChanged();
      setState(() => _detail = null);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useInEntry() async {
    if (_detail == null || _target == null) return;
    final parts = _target!.split('|');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.useObject(_detail!['id'] as String, parts[0], parts[1]);
      widget.onEntriesChanged();
      if (mounted) setState(() => _detail = null);
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _models.where((format) => format.id == _formatId).firstOrNull;
    final title = model?.fields
        .where((field) => field.kind == BrainyFieldKind.title)
        .firstOrNull;
    final detail = _detail == null ? null : BrainyEntry.fromJson(_detail!);
    final targets = [
      for (final format in _collection.formats)
        if (!format.objectModel)
          for (final field in format.fields)
            if ([
              BrainyFieldKind.title,
              BrainyFieldKind.text,
              BrainyFieldKind.longText,
            ].contains(field.kind))
              (format: format, field: field),
    ];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fr ? 'Objets de la collection' : 'Collection objects',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _fr
                    ? 'Un objet est une entrée nommée de cette collection.'
                    : 'An object is a named entry in this collection.',
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                initiallyExpanded: _models.isEmpty,
                title: Text(
                  _fr ? 'Ajouter un modèle d’objets' : 'Add an object model',
                ),
                leading: const Icon(Icons.category_outlined),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _templateId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _fr ? 'Modèle de départ' : 'Starter model',
                    ),
                    items: [
                      for (final item in _templates)
                        DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text(
                            item['name'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _templateId = value;
                      _templateName.text =
                          _templates
                                  .where((item) => item['id'] == value)
                                  .firstOrNull?['name']
                              as String? ??
                          '';
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _templateName,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: _t('Data format name'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed:
                        _busy ||
                            _templateId == null ||
                            _collection.formats.length >= 24
                        ? null
                        : _createTemplate,
                    child: Text(
                      _fr ? 'Copier le modèle ici' : 'Copy model here',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _existingId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _fr
                          ? 'Format de données existant'
                          : 'Existing data format',
                    ),
                    items: [
                      for (final format in _collection.formats)
                        if (!format.objectModel &&
                            format.fields.any(
                              (field) => field.kind == BrainyFieldKind.title,
                            ))
                          DropdownMenuItem(
                            value: format.id,
                            child: Text(
                              format.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: (value) => setState(() => _existingId = value),
                  ),
                  OutlinedButton(
                    onPressed: _busy || _existingId == null
                        ? null
                        : _markExisting,
                    child: Text(
                      _fr ? 'Utiliser pour des objets' : 'Use for objects',
                    ),
                  ),
                ],
              ),
              if (_models.isNotEmpty) ...[
                const Divider(height: 30),
                DropdownButtonFormField<String>(
                  initialValue: _formatId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _fr ? 'Modèle d’objet' : 'Object model',
                  ),
                  items: [
                    for (final format in _models)
                      DropdownMenuItem(
                        value: format.id,
                        child: Text(
                          format.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _formatId = value;
                      _detail = null;
                    });
                    _load();
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    labelText: _fr ? 'Rechercher des objets' : 'Search objects',
                    suffixIcon: IconButton(
                      onPressed: () => _load(),
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _formatId == null
                      ? null
                      : () => Navigator.pop(
                          context,
                          (formatId: _formatId!, entry: null)
                              as ObjectEditorRequest,
                        ),
                  icon: const Icon(Icons.add),
                  label: Text(_fr ? 'Créer un objet' : 'Create object'),
                ),
                for (final entry in _objects)
                  ListTile(
                    title: Text(entry.values[title?.id] ?? '—'),
                    subtitle: Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(entry.updatedAt.toLocal()),
                    ),
                    onTap: () => _showDetail(entry),
                  ),
                if (_cursor != null)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: Text(_t('Load more entries')),
                  ),
              ],
              if (detail != null && model != null) ...[
                const Divider(height: 30),
                Text(
                  detail.values[title?.id] ?? '—',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${_t('Created')} ${MaterialLocalizations.of(context).formatMediumDate(detail.createdAt.toLocal())}',
                ),
                for (final field in model.fields)
                  if (detail.values[field.id] case final value?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${field.name}: $value${field.unit == null ? '' : ' ${field.unit}'}',
                      ),
                    ),
                Text(
                  '${_fr ? 'Versions précédentes' : 'Previous versions'}: ${(_detail!['revisions'] as List<dynamic>?)?.length ?? 0}',
                ),
                for (final revision
                    in (_detail!['revisions'] as List<dynamic>? ?? const []))
                  ExpansionTile(
                    title: Text(
                      MaterialLocalizations.of(context).formatMediumDate(
                        DateTime.parse(
                          (revision as Map<String, dynamic>)['at'] as String,
                        ).toLocal(),
                      ),
                    ),
                    children: [
                      for (final value in (revision['values'] as List<dynamic>))
                        if (model.fields
                                .where(
                                  (field) =>
                                      field.id ==
                                      (value
                                          as Map<String, dynamic>)['fieldId'],
                                )
                                .firstOrNull
                            case final field?)
                          ListTile(
                            title: Text(field.name),
                            subtitle: Text(value['value'] as String),
                          ),
                    ],
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        (formatId: model.id, entry: detail)
                            as ObjectEditorRequest,
                      ),
                      child: Text(_t('Edit')),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _duplicate,
                      child: Text(_fr ? 'Dupliquer' : 'Duplicate'),
                    ),
                    OutlinedButton(
                      onPressed: () => showCopyToCollection(
                        context,
                        api: widget.api,
                        source: _collection,
                        objectId: detail.id,
                      ),
                      child: Text(_fr ? 'Copier vers…' : 'Copy to…'),
                    ),
                    OutlinedButton(
                      onPressed: () => showShareToCollection(
                        context,
                        api: widget.api,
                        source: _collection,
                        format: model,
                        objectId: detail.id,
                      ),
                      child: Text(
                        _fr ? 'Partager par lien…' : 'Share by link…',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final moved = await showCopyToCollection(
                          context,
                          api: widget.api,
                          source: _collection,
                          objectId: detail.id,
                          move: true,
                        );
                        if (moved && mounted) {
                          setState(() => _detail = null);
                          await _load();
                          widget.onEntriesChanged();
                        }
                      },
                      child: Text(_fr ? 'Déplacer vers…' : 'Move to…'),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: _target,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _fr
                        ? 'Champ de destination'
                        : 'Destination field',
                  ),
                  items: [
                    for (final item in targets)
                      DropdownMenuItem(
                        value: '${item.format.id}|${item.field.id}',
                        child: Text(
                          '${item.format.name} · ${item.field.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _target = value),
                ),
                OutlinedButton(
                  onPressed: _busy || _target == null ? null : _useInEntry,
                  child: Text(
                    _fr ? 'Utiliser dans une entrée' : 'Use in an entry',
                  ),
                ),
                Text(
                  _fr
                      ? 'Cette action crée une entrée avec un résumé figé de l’objet.'
                      : "This creates an entry with a snapshot of the object's details.",
                ),
              ],
              if (_collection.sharedObjects.isNotEmpty) ...[
                const Divider(height: 28),
                Text(
                  _fr
                      ? 'Objets liés à cette collection'
                      : 'Objects linked to this collection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final grant in _collection.sharedObjects)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${grant['sourceName']} · ${grant['objectName']}',
                    ),
                    subtitle: Text(
                      grant['revokedAt'] != null
                          ? (_fr ? 'Révoqué' : 'Revoked')
                          : grant['mode'] == 'CURRENT'
                          ? (_fr ? 'Valeurs actuelles' : 'Current values')
                          : (_fr ? 'Instantané' : 'Snapshot'),
                    ),
                    trailing: grant['revokedAt'] == null
                        ? TextButton(
                            onPressed: _busy
                                ? null
                                : () => _revoke(grant['id'] as String),
                            child: Text(_fr ? 'Révoquer' : 'Revoke'),
                          )
                        : null,
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
