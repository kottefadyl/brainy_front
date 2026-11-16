// "People with access": who the owner shared a collection with. Searched and paged on the server,
// so a collection shared with thousands of people stays fast.
import 'dart:async';

import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collaborators_api.dart';
import 'collections_api.dart';
import 'entry_authors.dart';

const collectionMembersPageSize = 50;

class CollectionMembersPanel extends StatefulWidget {
  const CollectionMembersPanel({super.key, required this.api, required this.collection, required this.onChanged, required this.onAddPeople});
  final CollaboratorsApi api;
  final BrainyCollection collection;

  /// Called after an access was changed; a null role means the person lost access.
  final void Function(String userId, BrainyCollectionRole? role) onChanged;
  final VoidCallback onAddPeople;

  @override
  State<CollectionMembersPanel> createState() => _CollectionMembersPanelState();
}

class _CollectionMembersPanelState extends State<CollectionMembersPanel> {
  CollectionMembersPage? _page;
  String _search = '';
  int _offset = 0;
  String? _error, _saving;
  Timer? _debounce;
  int _request = 0;

  bool get _fr => AppStrings.of(context).isFrench;
  String _t(String en, String fr) => _fr ? fr : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final page = await widget.api.members(widget.collection.id, search: _search, offset: _offset, limit: collectionMembersPageSize);
      if (mounted && request == _request) setState(() { _page = page; _error = null; });
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = collaboratorError(error, _fr));
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () { _search = value.trim(); _offset = 0; _load(); });
  }

  Future<void> _setRole(BrainyCollectionMemberSummary person, BrainyCollectionRole role) async {
    setState(() { _saving = person.userId; _error = null; });
    try {
      await widget.api.share(widget.collection, person.userId, role);
      widget.onChanged(person.userId, role);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = collaboratorError(error, _fr));
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _remove(BrainyCollectionMemberSummary person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Remove access?', 'Retirer l’accès ?')),
        content: Text(_t('${person.name} will no longer see this collection. Their entries stay in it.', '${person.name} ne verra plus cette collection. Ses entrées y restent.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('Cancel', 'Annuler'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError), onPressed: () => Navigator.pop(context, true), child: Text(_t('Remove access', 'Retirer l’accès'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _saving = person.userId; _error = null; });
    try {
      await widget.api.unshare(widget.collection.id, person.userId);
      widget.onChanged(person.userId, null);
      // Stay on a page that still has people once the last one of a page is removed.
      if ((_page?.items.length ?? 0) == 1 && _offset > 0) _offset = (_offset - collectionMembersPageSize).clamp(0, _offset);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = collaboratorError(error, _fr));
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final page = _page;
    final total = page?.total ?? 0;
    final empty = page != null && _search.isEmpty && total == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
      if (page == null && _error == null) Text(_t('Loading…', 'Chargement…'), style: TextStyle(color: muted)),
      if (empty) ...[
        Text(_t('This collection is not shared yet.', 'Cette collection n’est pas encore partagée.'), style: TextStyle(color: muted)),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: widget.onAddPeople, icon: const Icon(Icons.person_add_alt_1_outlined), label: Text(_t('Add people', 'Ajouter des personnes')))),
      ],
      if (page != null && !empty) ...[
        TextField(
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: _t('Search by name or e-mail…', 'Rechercher par nom ou e-mail…'), isDense: true, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          child: Text(
            _search.isNotEmpty && total == 0
                ? _t('Nobody matches.', 'Personne ne correspond.')
                : _t('${_offset + 1}–${(_offset + collectionMembersPageSize).clamp(0, total)} of $total', '${_offset + 1}–${(_offset + collectionMembersPageSize).clamp(0, total)} sur $total'),
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        for (final person in page.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                PersonAvatar((userId: person.userId, name: person.name, hasPhoto: person.hasPhoto), size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(person.email, style: TextStyle(color: muted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                IconButton(
                  tooltip: _t('Remove access for ${person.name}', 'Retirer l’accès de ${person.name}'),
                  onPressed: _saving == person.userId ? null : () => _remove(person),
                  icon: const Icon(Icons.person_remove_outlined),
                ),
              ]),
              const SizedBox(height: 6),
              DropdownButtonFormField<BrainyCollectionRole>(
                key: ValueKey('member-${person.userId}-${person.role}'),
                isExpanded: true,
                initialValue: person.role,
                decoration: InputDecoration(labelText: _t('Access for ${person.name}', 'Accès de ${person.name}'), isDense: true),
                items: [
                  DropdownMenuItem(value: BrainyCollectionRole.reader, child: Text(_t('Read only', 'Lecture seule'))),
                  DropdownMenuItem(value: BrainyCollectionRole.editor, child: Text(_t('Read and write', 'Lecture et écriture'))),
                ],
                onChanged: _saving == person.userId ? null : (role) { if (role != null && role != person.role) _setRole(person, role); },
              ),
            ]),
          ),
        if (total > collectionMembersPageSize)
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _offset == 0 ? null : () { _offset = (_offset - collectionMembersPageSize).clamp(0, _offset); _load(); }, icon: const Icon(Icons.chevron_left), label: Text(_t('Previous', 'Précédent'))),
            Text(_t('Page ${_offset ~/ collectionMembersPageSize + 1} of ${(total / collectionMembersPageSize).ceil()}', 'Page ${_offset ~/ collectionMembersPageSize + 1} sur ${(total / collectionMembersPageSize).ceil()}'), style: TextStyle(color: muted)),
            OutlinedButton.icon(onPressed: _offset + collectionMembersPageSize >= total ? null : () { _offset += collectionMembersPageSize; _load(); }, icon: const Icon(Icons.chevron_right), label: Text(_t('Next', 'Suivant'))),
          ]),
      ],
    ]);
  }
}
