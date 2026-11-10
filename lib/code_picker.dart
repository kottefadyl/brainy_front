import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'code_tree.dart';
import 'referentials_api.dart';
import 'remote_code_browser.dart';

const _emptyChoice = '';

/// A physical keyboard is expected: focus the search box without covering the tree.
bool get _isDesktop => const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);

/// Search box and expandable tree. Without [onSelect] the tree can only be read.
class CodeBrowser extends StatefulWidget {
  const CodeBrowser({
    super.key,
    required this.codes,
    required this.french,
    this.value = '',
    this.onSelect,
    this.canSelect,
    this.autofocus = false,
  });

  final List<Map<String, dynamic>> codes;
  final bool french;
  final String value;
  final ValueChanged<String>? onSelect;
  final bool Function(CodeNode)? canSelect;
  final bool autofocus;

  @override
  State<CodeBrowser> createState() => _CodeBrowserState();
}

class _CodeBrowserState extends State<CodeBrowser> {
  late final CodeTree _tree = CodeTree.build(widget.codes, widget.french);
  late final Set<String> _reachable = _tree.reachable(_selectable);
  late final Set<String> _expanded = _openPath();
  final _activeRow = GlobalKey();
  List<(CodeNode, int)> _rows = const [];
  String _query = '';
  int _active = 0;
  bool _usingKeys = false;

  String t(String french, String english) => widget.french ? french : english;
  bool _selectable(CodeNode node) => widget.canSelect?.call(node) ?? true;

  Set<String> _openPath() {
    final open = <String>{};
    var parent = _tree.nodes[widget.value]?.parent;
    while (parent != null && open.add(parent)) {
      parent = _tree.nodes[parent]?.parent;
    }
    return open;
  }

  bool _hasChildren(CodeNode node) => node.children.any(_reachable.contains);

  void _toggle(CodeNode node) => setState(() {
    if (!_expanded.remove(node.code)) _expanded.add(node.code);
  });

  void _choose(CodeNode node) {
    if (widget.onSelect != null && _selectable(node)) {
      widget.onSelect!(node.code);
    } else if (_hasChildren(node)) {
      _toggle(node);
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

  /// Same keys as the web client; focus stays in the search box.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _rows.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final current = _active.clamp(0, _rows.length - 1);
    final row = _rows[current].$1;
    final searching = _query.trim().isNotEmpty;
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
    if (searching) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowRight && _hasChildren(row)) {
      if (_expanded.contains(row.code)) {
        _move(current + 1, ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      } else {
        _toggle(row);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_expanded.contains(row.code)) {
        _toggle(row);
      } else if (row.parent != null) {
        _move(_rows.indexWhere((item) => item.$1.code == row.parent), ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<(CodeNode, int)> _treeRows() {
    final rows = <(CodeNode, int)>[];
    void visit(List<String> codes, int indent) {
      for (final code in codes) {
        if (!_reachable.contains(code)) continue;
        final node = _tree.nodes[code]!;
        rows.add((node, indent));
        if (_expanded.contains(code)) visit(node.children, indent + 1);
      }
    }

    visit(_tree.roots, 0);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final found = _tree.search(_query, _selectable);
    final rows = searching ? [for (final node in found.results) (node, 0)] : _treeRows();
    _rows = rows;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: TextField(
            key: const ValueKey('code-search'),
            autofocus: widget.autofocus,
            autocorrect: false,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: t('Mot-clé ou code', 'Keyword or code'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() {
              _query = value;
              _active = 0;
            }),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(searching ? t('Aucun code ne correspond.', 'No matching code.') : t('Aucun code.', 'No codes.'), style: TextStyle(color: muted)),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) => _row(context, rows[index].$1, rows[index].$2, searching, muted, index),
                ),
        ),
        if (searching && found.total > found.results.length)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t('${found.results.length} premiers résultats sur ${found.total}. Précisez la recherche.', 'First ${found.results.length} of ${found.total} results. Refine your search.'),
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, CodeNode node, int indent, bool searching, Color muted, int index) {
    final enabled = widget.onSelect == null || _selectable(node);
    final parent = _hasChildren(node);
    final open = _expanded.contains(node.code);
    final colors = Theme.of(context).colorScheme;
    final highlighted = _usingKeys && index == _active.clamp(0, _rows.length - 1);
    return Semantics(
      selected: node.code == widget.value,
      enabled: enabled,
      child: InkWell(
        key: ValueKey('code-row-${node.code}'),
        borderRadius: BorderRadius.circular(8),
        // Arrows move through the rows from the search box, so Tab does not stop on each one.
        canRequestFocus: false,
        onTap: enabled || parent ? () => _choose(node) : null,
        child: Container(
          key: highlighted ? _activeRow : null,
          constraints: const BoxConstraints(minHeight: 48),
          color: highlighted ? colors.surfaceContainerHighest : null,
          padding: EdgeInsetsDirectional.only(start: 4.0 + indent * 16, end: 8),
          foregroundDecoration: node.code == widget.value
              ? BoxDecoration(border: BorderDirectional(start: BorderSide(color: colors.primary, width: 3)))
              : null,
          child: Row(
            children: [
              if (!searching)
                SizedBox(
                  width: 40,
                  child: parent
                      ? ExcludeFocus(
                          child: IconButton(
                            tooltip: open ? t('Replier ${node.label}', 'Collapse ${node.label}') : t('Déplier ${node.label}', 'Expand ${node.label}'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _toggle(node),
                            icon: Icon(open ? Icons.expand_more : Icons.chevron_right, size: 20),
                          ),
                        )
                      : null,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (searching && node.path.isNotEmpty) Text(node.path.join(' › '), style: TextStyle(color: muted, fontSize: 13)),
                      Text('${node.label}${node.active ? '' : ' · ${t('obsolète', 'obsolete')}'}', style: TextStyle(color: enabled ? colors.onSurface : muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 88),
                child: Text(node.code, textAlign: TextAlign.end, style: TextStyle(color: muted, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A form control showing the chosen code; opens the browser in a sheet or a dialog.
class CodePickerField extends StatelessWidget {
  const CodePickerField({
    super.key,
    required this.label,
    required this.codes,
    required this.french,
    required this.value,
    required this.onChanged,
    this.canSelect,
    this.emptyLabel,
    this.remote,
  });

  final String label;
  final List<Map<String, dynamic>> codes;
  final bool french;
  final String value;
  final ValueChanged<String> onChanged;
  final bool Function(CodeNode)? canSelect;
  final String? emptyLabel;

  /// A large list (T39/3): codes are searched on the server instead of [codes].
  final RemoteCodeSource? remote;

  String t(String french_, String english) => french ? french_ : english;

  Future<void> _open(BuildContext context) async {
    Widget content(BuildContext sheetContext) => remote != null
        ? RemoteCodeBrowser(source: remote!, french: french, value: value, autofocus: _isDesktop, onSelect: (code) => Navigator.pop(sheetContext, code))
        : CodeBrowser(
      codes: codes,
      french: french,
      value: value,
      canSelect: canSelect,
      autofocus: _isDesktop,
      onSelect: (code) => Navigator.pop(sheetContext, code),
    );
    Widget body(BuildContext sheetContext, double height) => SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: Theme.of(sheetContext).textTheme.titleMedium)),
                if (value.isNotEmpty && emptyLabel != null) TextButton(onPressed: () => Navigator.pop(sheetContext, _emptyChoice), child: Text(emptyLabel!)),
                IconButton(tooltip: t('Fermer', 'Close'), onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
              ],
            ),
            Expanded(child: content(sheetContext)),
          ],
        ),
      ),
    );
    final size = MediaQuery.sizeOf(context);
    final picked = size.width >= 600
        ? await showDialog<String>(
            context: context,
            builder: (dialogContext) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: body(dialogContext, size.height * 0.7),
              ),
            ),
          )
        : await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (sheetContext) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
              child: body(sheetContext, size.height * 0.75),
            ),
          );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (remote == null) return _display(context, codes);
    return RemoteCodeValue(source: remote!, value: value, builder: (context, code) => _display(context, code == null ? const [] : [code]));
  }

  Widget _display(BuildContext context, List<Map<String, dynamic>> codes) {
    final node = CodeTree.build(codes, french).nodes[value];
    final colors = Theme.of(context).colorScheme;
    final shown = node == null ? (value.isEmpty ? t('Choisir un code', 'Choose a code') : value) : '${node.label} (${node.code})${node.active ? '' : ' · ${t('obsolète', 'obsolete')}'}';
    return Semantics(
      button: true,
      label: '$label: $shown',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.expand_more)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (node != null && node.path.isNotEmpty) Text(node.path.join(' › '), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
              Text(shown, style: TextStyle(color: value.isEmpty ? colors.onSurfaceVariant : colors.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
