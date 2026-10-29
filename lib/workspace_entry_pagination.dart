part of 'workspace_screen.dart';

extension _WorkspaceEntryPagination on _WorkspaceScreenState {
  Future<void> _loadEntries() async {
    final id = _selectedId;
    final request = ++_entryRequest;
    if (id == null) {
      if (mounted) {
        _mutate(() {
          _entries = [];
          _pageCursor = null;
          _pageAfter = null;
          _previousPages.clear();
        });
      }
      return;
    }
    _mutate(() {
      _loadingEntries = true;
      _pageCursor = null;
      _pageAfter = null;
      _previousPages.clear();
      _error = null;
    });
    try {
      final page = await _api.entriesPage(
        id,
        search: _search,
        formatId: _filterFormatId,
        fieldId: _filterFieldId,
        operatorName: _filterOperator,
        filterValue: _filterValue,
        viewId: _selectedViewId,
      );
      if (mounted && _selectedId == id && request == _entryRequest) {
        _mutate(() {
          _entries = page.entries;
          _pageCursor = page.nextCursor;
          _loadingEntries = false;
        });
      }
    } catch (error) {
      if (mounted && _selectedId == id && request == _entryRequest) {
        _mutate(() {
          _loadingEntries = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _loadMoreEntries() async {
    final id = _selectedId;
    final cursor = _pageCursor;
    if (id == null || cursor == null || _loadingMore) return;
    final request = _entryRequest;
    _mutate(() => _loadingMore = true);
    try {
      final page = await _api.entriesPage(
        id,
        after: cursor,
        search: _search,
        formatId: _filterFormatId,
        fieldId: _filterFieldId,
        operatorName: _filterOperator,
        filterValue: _filterValue,
        viewId: _selectedViewId,
      );
      if (mounted && id == _selectedId && request == _entryRequest) {
        _mutate(() {
          _previousPages.add(_pageAfter);
          _pageAfter = cursor;
          _entries = page.entries;
          _pageCursor = page.nextCursor;
        });
      }
    } catch (error) {
      if (mounted) _mutate(() => _error = error.toString());
    } finally {
      if (mounted) _mutate(() => _loadingMore = false);
    }
  }

  Future<void> _loadPreviousEntries() async {
    final id = _selectedId;
    if (id == null || _previousPages.isEmpty || _loadingMore) return;
    final after = _previousPages.last;
    final request = _entryRequest;
    _mutate(() => _loadingMore = true);
    try {
      final page = await _api.entriesPage(
        id,
        after: after,
        search: _search,
        formatId: _filterFormatId,
        fieldId: _filterFieldId,
        operatorName: _filterOperator,
        filterValue: _filterValue,
        viewId: _selectedViewId,
      );
      if (mounted && id == _selectedId && request == _entryRequest) {
        _mutate(() {
          _previousPages.removeLast();
          _pageAfter = after;
          _entries = page.entries;
          _pageCursor = page.nextCursor;
        });
      }
    } catch (error) {
      if (mounted) _mutate(() => _error = error.toString());
    } finally {
      if (mounted) _mutate(() => _loadingMore = false);
    }
  }

}
