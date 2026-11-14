part of 'workspace_screen.dart';

/// Large lists: pages are asked by position (or by date), so any page is one step away, and the
/// chosen collection, view and page size are remembered on this device.
extension _WorkspaceEntryPagination on _WorkspaceScreenState {
  Future<BrainyEntryPage> _entryPage(String id, {int offset = 0, String? atDate}) => _api.entriesPage(
    id,
    search: _search,
    formatId: _filterFormatId,
    fieldId: _filterFieldId,
    operatorName: _filterOperator,
    filterValue: _filterValue,
    viewId: _selectedViewId,
    first: _pageSize,
    offset: atDate == null ? offset : null,
    atDate: atDate,
  );

  Future<void> _loadEntries() async {
    final id = _selectedId;
    final request = ++_entryRequest;
    if (id == null) {
      if (mounted) {
        _mutate(() {
          _entries = [];
          _pageCursor = null;
          _pageOffset = 0;
          _totalCount = null;
        });
      }
      return;
    }
    _viewMemory.remember(collectionId: id, viewId: _selectedViewId);
    _mutate(() {
      _loadingEntries = true;
      _pageCursor = null;
      _pageOffset = 0;
      _error = null;
    });
    try {
      final page = await _entryPage(id);
      if (mounted && _selectedId == id && request == _entryRequest) {
        _mutate(() {
          _entries = page.entries;
          _pageCursor = page.nextCursor;
          _pageOffset = page.offset ?? 0;
          _totalCount = page.totalCount;
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

  /// Opens the page at a position, or the page holding a day.
  Future<void> _goToEntries({int offset = 0, DateTime? date}) async {
    final id = _selectedId;
    if (id == null || _loadingMore) return;
    final request = ++_entryRequest;
    _mutate(() => _loadingMore = true);
    final day = date == null ? null : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final page = await _entryPage(id, offset: offset, atDate: day);
      if (mounted && id == _selectedId && request == _entryRequest) {
        _mutate(() {
          _entries = page.entries;
          _pageCursor = page.nextCursor;
          _pageOffset = page.offset ?? offset;
          _totalCount = page.totalCount ?? _totalCount;
        });
        _scrollToEntries();
      }
    } catch (error) {
      if (mounted) _mutate(() => _error = error.toString());
    } finally {
      if (mounted) _mutate(() => _loadingMore = false);
    }
  }

  void _choosePageSize(int size) {
    if (size == _pageSize) return;
    _viewMemory.rememberPageSize(size);
    _mutate(() => _pageSize = size);
    _loadEntries();
  }

  /// Back to the top of the list after a page change, without animation when motion is reduced.
  void _scrollToEntries() {
    final target = _entriesTop.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
  }

  Widget _entriesPager(BrainyCollection collection) {
    final view = collection.savedViews.where((item) => item['id'] == _selectedViewId).firstOrNull;
    if (!EntriesPager.needed(offset: _pageOffset, total: _totalCount, shown: _entries.length, hasMore: _pageCursor != null)) return const SizedBox.shrink();
    return EntriesPager(
      offset: _pageOffset,
      pageSize: _pageSize,
      total: _totalCount,
      shown: _entries.length,
      hasMore: _pageCursor != null,
      busy: _loadingMore || _loadingEntries,
      dateJump: view?['sort'] != 'MANUAL',
      onGo: (offset) => _goToEntries(offset: offset),
      onDate: (date) => _goToEntries(date: date),
      onPageSize: _choosePageSize,
    );
  }
}
