part of 'workspace_screen.dart';

/// Real-time data synchronisation: another person changed these collections. The list and the open
/// first page reload quietly (no spinner); a collection I lost access to disappears.
extension _WorkspaceLiveSync on _WorkspaceScreenState {
  Future<void> _liveSync(Set<String> collectionIds) async {
    try {
      // Only the collections that changed travel: the full list carries every format, field and code.
      final fresh = await _api.collectionsById(collectionIds);
      if (!mounted) return;
      final collections = mergeChangedCollections(_collections, collectionIds, fresh);
      final lost = _selectedId != null && !collections.any((item) => item.id == _selectedId);
      _mutate(() {
        _collections = collections;
        if (lost) _selectedId = collections.firstOrNull?.id;
      });
      if (lost) { await _loadEntries(); return; }
      final id = _selectedId;
      if (id == null || !collectionIds.contains(id)) return;
      final request = ++_entryRequest;
      final page = await _entryPage(id, offset: _pageOffset);
      if (mounted && _selectedId == id && request == _entryRequest) {
        _mutate(() {
          _entries = page.entries;
          _pageCursor = page.nextCursor;
          _totalCount = page.totalCount ?? _totalCount;
        });
      }
    } catch (_) {
      // The next load shows the change.
    }
  }
}

/// The list after a live update: a changed collection is replaced in place, a new one (just shared
/// with me) comes first, and one missing from the answer (access ended, deleted) leaves.
List<BrainyCollection> mergeChangedCollections(List<BrainyCollection> current, Set<String> changedIds, List<BrainyCollection> fresh) {
  final byId = {for (final item in fresh) item.id: item};
  final known = current.map((item) => item.id).toSet();
  return [
    ...fresh.where((item) => !known.contains(item.id)),
    for (final item in current)
      if (!changedIds.contains(item.id)) item else ?byId[item.id],
  ];
}
