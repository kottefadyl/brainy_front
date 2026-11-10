import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'referentials_api.dart';

/// Search and level-by-level browsing of a large code list (T39/3): the
/// server returns at most 50 codes at a time, never the whole list. Same
/// look and keys as CodeBrowser; → opens a level, ← goes back up.
class RemoteCodeBrowser extends StatefulWidget {
  const RemoteCodeBrowser({super.key, required this.source, required this.french, this.value = '', this.onSelect, this.autofocus = false});

  final RemoteCodeSource source;
  final bool french;
  final String value;
  final ValueChanged<String>? onSelect;
  final bool autofocus;

  @override
  State<RemoteCodeBrowser> createState() => _RemoteCodeBrowserState();
}

class _RemoteCodeBrowserState extends State<RemoteCodeBrowser> {
  final _activeRow = GlobalKey();
  final List<FoundCode> _trail = [];
  List<FoundCode> _rows = const [];
  String _query = '';
  int _active = 0;
  int _request = 0;
  bool _usingKeys = false;
  String _state = 'loading';
  Timer? _debounce;

  String t(String french, String english) => widget.french ? french : english;
  bool get _searching => _query.trim().isNotEmpty;

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
    setState(() => _state = 'loading');
    try {
      final found = await widget.source.search(_query.trim(), _searching || _trail.isEmpty ? null : _trail.last.code);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = found;
        _active = 0;
        _state = 'ready';
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _state = 'error');
    }
  }

  void _onQuery(String value) {
    _query = value;
    _debounce?.cancel();
    // One request per word typed, none per letter.
    _debounce = Timer(Duration(milliseconds: _searching ? 250 : 0), _load);
  }

  void _open(FoundCode row) {
    _trail.add(row);
    _load();
  }

  void _up() {
    if (_trail.isEmpty) return;
    _trail.removeLast();
    _load();
  }

  void _choose(FoundCode row) {
    if (widget.onSelect != null && row.active) {
      widget.onSelect!(row.code);
    } else if (row.hasChildren && !_searching) {
      _open(row);
    }
  }

  void _move(int index, ScrollPositionAlignmentPolicy policy) {
    setState(() {
      _active = index.clamp(0, _rows.length - 1);
      _usingKeys = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _activeRow.currentContext;
      if (row != null && row.mounted) Scrollable.ensureVisible(row, alignmentPolicy: policy);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (!_searching && _trail.isNotEmpty && key == LogicalKeyboardKey.arrowLeft) {
      _up();
      return KeyEventResult.handled;
    }
    if (_rows.isEmpty) return KeyEventResult.ignored;
    final current = _active.clamp(0, _rows.length - 1);
    final row = _rows[current];
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(current + 1, ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(current - 1, ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _choose(row);
      return KeyEventResult.handled;
    }
    if (!_searching && row.hasChildren && key == LogicalKeyboardKey.arrowRight) {
      _open(row);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: TextField(
            key: const ValueKey('remote-code-search'),
            autofocus: widget.autofocus,
            autocorrect: false,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: t('Mot-clé ou code', 'Keyword or code'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _onQuery,
          ),
        ),
        if (!_searching && _trail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                TextButton.icon(onPressed: _up, icon: const Icon(Icons.subdirectory_arrow_left, size: 18), label: Text(t('Niveau précédent', 'Previous level'))),
                const SizedBox(width: 4),
                Expanded(child: Text(_trail.map((item) => item.label).join(' › '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 13))),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Expanded(child: _list(context, muted)),
        if (_rows.length >= 50)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t('50 premiers résultats. Précisez la recherche.', 'First 50 results. Refine the search.'), style: TextStyle(color: muted, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _list(BuildContext context, Color muted) {
    if (_state == 'error') {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Semantics(liveRegion: true, child: Text(t('Recherche impossible.', 'Search failed.'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
            TextButton(onPressed: _load, child: Text(t('Réessayer', 'Retry'))),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      final text = _state == 'loading' ? t('Chargement…', 'Loading…') : _searching ? t('Aucun code ne correspond.', 'No matching code.') : t('Aucun code.', 'No codes.');
      return Padding(padding: const EdgeInsets.all(12), child: Text(text, style: TextStyle(color: muted)));
    }
    return ListView.builder(itemCount: _rows.length, itemBuilder: (context, index) => _row(context, _rows[index], index, muted));
  }

  Widget _row(BuildContext context, FoundCode row, int index, Color muted) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onSelect == null || row.active;
    final highlighted = _usingKeys && index == _active.clamp(0, _rows.length - 1);
    final showPath = (_searching || _trail.isEmpty) && row.path.isNotEmpty;
    return Semantics(
      selected: row.code == widget.value,
      enabled: enabled,
      child: InkWell(
        key: ValueKey('remote-code-row-${row.code}'),
        borderRadius: BorderRadius.circular(8),
        canRequestFocus: false,
        onTap: enabled || row.hasChildren ? () => _choose(row) : null,
        child: Container(
          key: highlighted ? _activeRow : null,
          constraints: const BoxConstraints(minHeight: 48),
          color: highlighted ? colors.surfaceContainerHighest : null,
          padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
          foregroundDecoration: row.code == widget.value ? BoxDecoration(border: BorderDirectional(start: BorderSide(color: colors.primary, width: 3))) : null,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showPath) Text(row.path.join(' › '), style: TextStyle(color: muted, fontSize: 13)),
                      Text('${row.label}${row.active ? '' : ' · ${t('obsolète', 'obsolete')}'}', style: TextStyle(color: enabled ? colors.onSurface : muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 88),
                child: Text(row.code, textAlign: TextAlign.end, style: TextStyle(color: muted, fontSize: 13)),
              ),
              SizedBox(
                width: 40,
                child: !_searching && row.hasChildren
                    ? ExcludeFocus(
                        child: IconButton(
                          key: ValueKey('remote-code-open-${row.code}'),
                          tooltip: t('Ouvrir ${row.label}', 'Open ${row.label}'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _open(row),
                          icon: const Icon(Icons.chevron_right, size: 20),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fetches the label of a saved code from a large list, then builds with it
/// (null while loading, or when the code is unknown).
class RemoteCodeValue extends StatefulWidget {
  const RemoteCodeValue({super.key, required this.source, required this.value, required this.builder});

  final RemoteCodeSource source;
  final String value;
  final Widget Function(BuildContext context, Map<String, dynamic>? code) builder;

  @override
  State<RemoteCodeValue> createState() => _RemoteCodeValueState();
}

class _RemoteCodeValueState extends State<RemoteCodeValue> {
  final Map<String, Map<String, dynamic>> _known = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(RemoteCodeValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _fetch();
  }

  Future<void> _fetch() async {
    final value = widget.value;
    if (value.isEmpty || _known.containsKey(value)) return;
    try {
      final found = await widget.source.byValue([value]);
      if (!mounted) return;
      setState(() { for (final item in found) { _known[item['code'] as String] = item; } });
    } catch (_) {
      // The code itself stays visible when its label cannot be fetched.
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _known[widget.value]);
}
