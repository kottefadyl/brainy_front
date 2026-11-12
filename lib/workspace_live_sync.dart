part of 'workspace_screen.dart';

/// Real-time data synchronisation: another person changed these collections. The list and the open
/// first page reload quietly (no spinner); a collection I lost access to disappears.
extension _WorkspaceLiveSync on _WorkspaceScreenState {
  Future<void> _liveSync(Set<String> collectionIds) async {
    try {
      final collections = await _api.collections();
      if (!mounted) return;
      final lost = _selectedId != null && !collections.any((item) => item.id == _selectedId);
      _mutate(() {
        _collections = collections;
        if (lost) _selectedId = collections.firstOrNull?.id;
      });
      if (lost) { await _loadEntries(); return; }
      final id = _selectedId;
      if (id == null || !collectionIds.contains(id) || _pageAfter != null) return;
      final request = ++_entryRequest;
      final page = await _api.entriesPage(id, search: _search, formatId: _filterFormatId, fieldId: _filterFieldId, operatorName: _filterOperator, filterValue: _filterValue, viewId: _selectedViewId);
      if (mounted && _selectedId == id && request == _entryRequest) {
        _mutate(() {
          _entries = page.entries;
          _pageCursor = page.nextCursor;
        });
      }
    } catch (_) {
      // The next load shows the change.
    }
  }
}
