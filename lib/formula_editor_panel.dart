import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_strings.dart';
import 'auth_api.dart';
import 'collections_api.dart';
import 'formula_completion.dart';
import 'formula_language.dart';
import 'number_units.dart';

/// Writes, checks and previews the formulas of a data format, like the web.
class FormulaEditorPanel extends StatefulWidget {
  const FormulaEditorPanel({
    super.key,
    required this.api,
    required this.collection,
    required this.format,
    required this.french,
    required this.onCollectionChanged,
  });

  final CollectionsApi api;
  final BrainyCollection collection;
  final BrainyFormat format;
  final bool french;
  final ValueChanged<BrainyCollection> onCollectionChanged;

  @override
  State<FormulaEditorPanel> createState() => _FormulaEditorPanelState();
}

class _Remote {
  _Remote(this.json, {this.inferred, this.error});
  final String json;
  final Map<String, dynamic>? inferred;
  final String? error;
  Map<String, dynamic>? preview;
  String? previewError;
}

class _FormulaEditorPanelState extends State<FormulaEditorPanel> {
  final _name = TextEditingController();
  final _text = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);

  Timer? _debounce;
  Map<String, dynamic>? _editing;
  _Remote? _remote;
  String? _json, _parseError, _saveError;
  String _checkedText = '';
  int _activeIndex = 0;
  bool _dismissed = false, _busy = false;

  bool get fr => widget.french;
  FormulaContext get _context => FormulaContext(
    collection: widget.collection,
    format: widget.format,
    french: fr,
  );
  int get _caret {
    final offset = _text.selection.baseOffset;
    return offset < 0 || offset > _text.text.length ? _text.text.length : offset;
  }

  FormulaCompletionResult? get _completion => _focus.hasFocus && !_dismissed
      ? formulaCompletionsAt(_text.text, _caret, _context)
      : null;

  @override
  void initState() {
    super.initState();
    _text.addListener(_textChanged);
    _name.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(FormulaEditorPanel old) {
    super.didUpdateWidget(old);
    if (old.collection != widget.collection) _analyse(force: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _textChanged() {
    if (_text.text != _checkedText) {
      _activeIndex = 0;
      _dismissed = false;
      _saveError = null;
      _analyse();
    }
    setState(() {});
  }

  /// Parses locally at once; types and preview come from the API, debounced.
  void _analyse({bool force = false}) {
    final text = _text.text;
    _checkedText = text;
    String? json, error;
    if (text.trim().isNotEmpty) {
      try {
        json = jsonEncode(parseFormula(text, _context));
      } on FormulaSyntaxError catch (cause) {
        error = cause.message;
      }
    }
    final changed = json != _json;
    _json = json;
    _parseError = error;
    if (json == null) {
      _debounce?.cancel();
      return;
    }
    if (!changed && !force) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _check(json!));
  }

  String _message(Object cause) => formulaErrorMessage(
    cause is AuthApiException ? cause.message : cause.toString(),
    widget.collection,
    fr,
  );

  Future<void> _check(String json) async {
    final id = widget.collection.id, formatId = widget.format.id;
    _Remote result;
    try {
      final inferred = await widget.api.inferFormula(id, formatId, json);
      result = _Remote(json, inferred: inferred);
      try {
        result.preview = await widget.api.previewFormula(id, formatId, json);
      } catch (cause) {
        result.previewError = _message(cause);
      }
    } catch (cause) {
      result = _Remote(json, error: _message(cause));
    }
    if (mounted && json == _json) setState(() => _remote = result);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final items = _completion?.items ?? const <FormulaCompletion>[];
    if (items.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _activeIndex = (_safeIndex(items) + 1) % items.length);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _activeIndex = (_safeIndex(items) - 1 + items.length) % items.length);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      _accept(items[_safeIndex(items)]);
    } else if (key == LogicalKeyboardKey.escape) {
      setState(() => _dismissed = true);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  int _safeIndex(List<FormulaCompletion> items) =>
      _activeIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);

  void _replaceRange(int from, int to, String insert) {
    final text = _text.text;
    final value = text.substring(0, from) + insert + text.substring(to);
    _text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: from + insert.length),
    );
    _focus.requestFocus();
  }

  void _accept(FormulaCompletion item) {
    final completion = _completion;
    if (completion != null) _replaceRange(completion.from, completion.to, item.insert);
  }

  void _reset() {
    setState(() {
      _editing = null;
      _name.clear();
      _text.clear();
      _saveError = null;
    });
  }

  void _edit(Map<String, dynamic> formula, String printed) {
    setState(() {
      _editing = formula;
      _name.text = formula['name'] as String;
      _text.value = TextEditingValue(
        text: printed,
        selection: TextSelection.collapsed(offset: printed.length),
      );
      _saveError = null;
    });
    _focus.requestFocus();
  }

  Future<void> _save() async {
    final json = _json;
    if (json == null) return;
    setState(() {
      _busy = true;
      _saveError = null;
    });
    try {
      final updated = await widget.api.saveFormula(
        widget.collection.id,
        _name.text,
        widget.format.id,
        json,
        expectedVersion: _editing?['version'] as int?,
        formulaId: _editing?['id'] as String?,
      );
      if (!mounted) return;
      widget.onCollectionChanged(updated);
      _reset();
    } catch (cause) {
      if (mounted) setState(() => _saveError = _message(cause));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> formula) async {
    setState(() => _saveError = null);
    try {
      final updated = await widget.api.deleteFormula(widget.collection.id, formula['id'] as String);
      if (!mounted) return;
      widget.onCollectionChanged(updated);
      if (_editing?['id'] == formula['id']) _reset();
    } catch (cause) {
      if (mounted) setState(() => _saveError = _message(cause));
    }
  }

  String _unitName(String unit) =>
      widget.collection.units.where((item) => item.id == unit).firstOrNull?.symbol ?? unit;

  String _resultLabel(Map<String, dynamic> inferred) {
    final type = inferred['type'];
    if (type == 'TEXT') return fr ? 'texte' : 'text';
    if (type == 'DATE') return 'date';
    if (type == 'DATETIME') return fr ? 'date et heure' : 'date and time';
    if (type == 'BOOLEAN') return fr ? 'condition' : 'condition';
    if (inferred['unitOpen'] == true) {
      return fr ? 'nombre, unité connue au calcul' : 'number, unit known when calculating';
    }
    final unit = inferred['unit'] as String?;
    if (unit == null || unit.isEmpty) return fr ? 'nombre' : 'number';
    return unit.replaceAllMapped(RegExp(r'[^·²/]+'), (m) => _unitName(m[0]!));
  }

  String _previewText(Map<String, dynamic> preview) {
    final value = preview['value'] as String? ?? '';
    final dimension = preview['dimension'];
    if (dimension == 'TEXT') return value.isEmpty ? (fr ? '(texte vide)' : '(empty text)') : value;
    if (dimension == 'DATE') {
      final hasTime = value.contains('T');
      final date = DateTime.tryParse(hasTime ? value : '${value}T00:00:00Z');
      if (date == null) return value;
      final local = MaterialLocalizations.of(context);
      final shown = hasTime ? date.toLocal() : date;
      final day = local.formatMediumDate(shown);
      return hasTime ? '$day ${local.formatTimeOfDay(TimeOfDay.fromDateTime(shown))}' : day;
    }
    final copy = AppStrings.of(context);
    final unit = preview['unit'] as String?;
    final symbol = widget.collection.units.where((item) => item.id == unit).firstOrNull?.symbol;
    return symbol != null
        ? '${formatFieldNumber(value, null, copy)} $symbol'
        : formatFieldNumber(value, unit, copy);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final text = _text.text;
    final completion = _completion;
    final items = completion?.items ?? const <FormulaCompletion>[];
    final safe = _safeIndex(items);
    final hint = formulaFunctionAt(text, _caret);
    final current = _json != null && _remote?.json == _json ? _remote : null;
    final inferred = current?.inferred;
    final empty = text.trim().isEmpty;

    // While a suggestion is being chosen, the unfinished text is not an error.
    final showParse = _parseError != null && items.isEmpty;
    final String? tone = empty || (_parseError != null && items.isNotEmpty)
        ? null
        : showParse || current?.error != null
        ? 'error'
        : inferred != null
        ? 'valid'
        : 'checking';
    final status = switch (tone) {
      'error' => _parseError ?? current?.error ?? '',
      'valid' => '${fr ? 'Formule valide' : 'Valid formula'} (${fr ? 'Résultat : ' : 'Result: '}${_resultLabel(inferred!)})',
      'checking' => fr ? 'Vérification…' : 'Checking…',
      _ => '',
    };
    final nameEmpty = _name.text.trim().isEmpty;
    final saveHelp = nameEmpty
        ? (fr ? 'Nommez la formule pour continuer.' : 'Name the formula to continue.')
        : empty
        ? (fr ? 'Écrivez la formule pour continuer.' : 'Write the formula to continue.')
        : tone == 'error'
        ? (fr ? "Corrigez la formule pour l'enregistrer." : 'Fix the formula to save it.')
        : '';
    final canSave = !nameEmpty && inferred != null && !_busy;
    final formulas = widget.collection.formulas
        .where((item) => item['formatId'] == widget.format.id)
        .toList();
    const code = TextStyle(fontFamily: 'Consolas', fontFamilyFallback: ['Courier New', 'monospace']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: fr ? 'Nom' : 'Name'),
        ),
        const SizedBox(height: 12),
        Text(
          fr
              ? "Tapez [ pour choisir un champ, un point après une référence pour ses propriétés, ou le début d'une fonction. Exemple : [Prix] * 0.8"
              : 'Type [ to pick a field, a dot after a reference for its properties, or the start of a function. Example: [Price] * 0.8',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          focusNode: _focus,
          minLines: 3,
          maxLines: 6,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.multiline,
          style: code,
          decoration: InputDecoration(labelText: fr ? 'Formule' : 'Formula'),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  // The text field must keep the focus during the choice.
                  canRequestFocus: false,
                  onTap: () => _accept(item),
                  child: Container(
                    color: index == safe ? scheme.primaryContainer : null,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 16, color: muted),
                        const SizedBox(width: 10),
                        Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: hint.signature(fr), style: code),
                TextSpan(text: '  ${hint.help(fr)}', style: TextStyle(color: muted)),
              ],
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
        if (tone != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: _StatusLine(tone: tone, message: status),
          ),
        ],
        if (inferred != null) ...[
          const SizedBox(height: 6),
          _preview(current!, muted),
        ],
        if (saveHelp.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(saveHelp, style: TextStyle(color: muted, fontSize: 13)),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 10),
          _StatusLine(tone: 'error', message: _saveError!),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Flexible(
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: Text(
                  _editing != null
                      ? (fr ? 'Mettre à jour' : 'Update')
                      : (fr ? 'Enregistrer la formule' : 'Save formula'),
                ),
              ),
            ),
            if (_editing != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _reset,
                child: Text(fr ? 'Annuler' : 'Cancel'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(fr ? 'Toutes les fonctions' : 'All functions'),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (category, en, french) in const [
              (FormulaFunctionCategory.logic, 'Conditions', 'Conditions'),
              (FormulaFunctionCategory.number, 'Numbers', 'Nombres'),
              (FormulaFunctionCategory.date, 'Dates and durations', 'Dates et durées'),
              (FormulaFunctionCategory.text, 'Text', 'Textes'),
              (FormulaFunctionCategory.relation, 'Linked objects', 'Objets liés'),
            ]) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(fr ? french : en, style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final item in formulaFunctions.where((item) => item.category == category))
                InkWell(
                  onTap: () => _replaceRange(_caret, _caret, '${item.name(fr)}('),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.signature(fr), style: code.copyWith(fontSize: 13)),
                        Text(item.help(fr), style: TextStyle(color: muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
        for (final formula in formulas) _formulaRow(formula, code, muted),
      ],
    );
  }

  Widget _preview(_Remote current, Color muted) {
    final style = TextStyle(color: muted, fontSize: 13);
    if (current.previewError != null) {
      return Text('${fr ? 'Aperçu impossible : ' : 'Preview unavailable: '}${current.previewError}', style: style);
    }
    final preview = current.preview;
    if (preview == null) {
      return Text(
        fr
            ? 'Ajoutez une entrée à ce format de données pour voir un aperçu.'
            : 'Add an entry to this data format to see a preview.',
        style: style,
      );
    }
    final label = preview['entryLabel'] as String?;
    final missing = preview['missing'] != null;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${fr ? 'Aperçu' : 'Preview'}${label != null && label.isNotEmpty ? ' · $label' : ''}', style: style),
        if (missing)
          Text(
            fr ? 'Valeur absente pour cette entrée' : 'No value for this entry',
            style: style.copyWith(fontStyle: FontStyle.italic),
          )
        else
          Text(_previewText(preview), style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _formulaRow(Map<String, dynamic> formula, TextStyle code, Color muted) {
    final printed = printFormula(formula['expression'] as String, _context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formula['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (printed != null)
                  Text(printed, style: code.copyWith(fontSize: 13, color: muted))
                else
                  Text(
                    fr ? 'Formule avancée (lecture seule)' : 'Advanced formula (read-only)',
                    style: TextStyle(color: muted, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          if (printed != null)
            IconButton(
              tooltip: fr ? 'Modifier' : 'Edit',
              onPressed: () => _edit(formula, printed),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: fr ? 'Supprimer' : 'Delete',
            onPressed: () => _remove(formula),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.tone, required this.message});

  final String tone, message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      'valid' => dark ? const Color(0xFF5EDC8C) : const Color(0xFF157F3B),
      'error' => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tone == 'checking')
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(
            tone == 'valid' ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            size: 16,
            color: color,
          ),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
      ],
    );
  }
}
