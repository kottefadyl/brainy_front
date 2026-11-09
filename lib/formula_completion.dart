import 'package:flutter/material.dart';

import 'collections_api.dart';
import 'formula_language.dart';

/// Port of the web's `lib/formula-completion.ts`.
class FormulaCompletion {
  const FormulaCompletion({
    required this.id,
    required this.label,
    required this.detail,
    required this.icon,
    required this.insert,
  });
  final String id, label, detail, insert;
  final IconData icon;
}

class FormulaCompletionResult {
  const FormulaCompletionResult(this.from, this.to, this.items);
  final int from, to;
  final List<FormulaCompletion> items;
}

const _maxItems = 40;

IconData? _iconFor(BrainyFieldKind kind) => switch (kind) {
  BrainyFieldKind.number => Icons.tag_rounded,
  BrainyFieldKind.date || BrainyFieldKind.datetime => Icons.calendar_today_outlined,
  BrainyFieldKind.duration => Icons.schedule_rounded,
  BrainyFieldKind.text || BrainyFieldKind.title || BrainyFieldKind.code || BrainyFieldKind.link => Icons.title_rounded,
  BrainyFieldKind.objectRef => Icons.link_rounded,
  _ => null,
};

String _kindLabel(BrainyField field, FormulaContext context) {
  final fr = context.french;
  final unitId = field.unit;
  final unit = unitId != null && unitId.isNotEmpty
      ? ' · ${context.collection.units.where((item) => item.id == unitId).firstOrNull?.symbol ?? unitId}'
      : '';
  final name = switch (field.kind) {
    BrainyFieldKind.number => fr ? 'Nombre' : 'Number',
    BrainyFieldKind.date => 'Date',
    BrainyFieldKind.datetime => fr ? 'Date et heure' : 'Date and time',
    BrainyFieldKind.duration => fr ? 'Durée' : 'Duration',
    BrainyFieldKind.text => fr ? 'Texte' : 'Text',
    BrainyFieldKind.title => fr ? 'Titre' : 'Title',
    BrainyFieldKind.code => 'Code',
    BrainyFieldKind.link => fr ? 'Lien web' : 'Web link',
    BrainyFieldKind.objectRef => fr ? 'Référence : tapez . ensuite' : 'Reference: type . next',
    _ => '',
  };
  return '$name$unit';
}

List<FormulaCompletion> _fieldItems(BrainyFormat format, FormulaContext context, String partial, bool numberOrTextOnly) {
  final wanted = foldFormulaName(partial);
  return [
    for (final field in format.fields)
      if (_iconFor(field.kind) != null &&
          foldFormulaName(field.name).contains(wanted) &&
          // Dates and durations of a linked object are not readable by formulas.
          (!numberOrTextOnly ||
              !const [BrainyFieldKind.date, BrainyFieldKind.datetime, BrainyFieldKind.duration].contains(field.kind)))
        FormulaCompletion(
          id: 'field:${field.id}',
          label: field.name,
          detail: _kindLabel(field, context),
          icon: _iconFor(field.kind)!,
          insert: '[${formulaEscapeName(field.name)}]',
        ),
  ];
}

List<FormulaCompletion> _formulaItems(FormulaContext context, String partial) {
  final wanted = foldFormulaName(partial.replaceFirst(RegExp('^='), ''));
  return [
    for (final item in context.collection.formulas)
      if (item['formatId'] == context.format.id && foldFormulaName(item['name'] as String).contains(wanted))
        FormulaCompletion(
          id: 'formula:${item['id']}',
          label: item['name'] as String,
          detail: context.french ? 'Formule enregistrée' : 'Saved formula',
          icon: Icons.functions_rounded,
          insert: '[=${formulaEscapeName(item['name'] as String)}]',
        ),
  ];
}

/// Resolves [A].[B]. to the data format its last reference points to.
BrainyFormat? _formatAfterPath(List<String> names, FormulaContext context) {
  BrainyFormat? format = context.format;
  for (final name in names) {
    final field = format?.fields
        .where((item) => item.name.toLowerCase() == name.toLowerCase() && item.kind == BrainyFieldKind.objectRef)
        .firstOrNull;
    if (field == null) return null;
    format = context.collection.formats.where((item) => item.id == field.targetObjectFormatId).firstOrNull;
  }
  return format;
}

final _pathBeforeDot = RegExp(r'(?:\[(?:\\.|[^\]\\])*\]\.)+$');
final _pathName = RegExp(r'\[((?:\\.|[^\]\\])*)\]');
final _escaped = RegExp(r'\\(.)');
final _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);
final _trailingWord = RegExp(r'[\p{L}_][\p{L}\p{N}_]*$', unicode: true);
final _endsWithNumber = RegExp(r'\d\s*$');

List<String> _pathNames(String text) {
  final match = _pathBeforeDot.firstMatch(text);
  if (match == null) return const [];
  return [
    for (final item in _pathName.allMatches(match[0]!))
      item[1]!.replaceAllMapped(_escaped, (m) => m[1]!),
  ];
}

enum _ScanState { code, string, ref }

class _Scan {
  const _Scan(this.state, this.refStart, this.calls);
  final _ScanState state;
  final int refStart;
  final List<String> calls;
}

/// Reads the text before the caret: quotes and brackets decide what it is in.
_Scan _scan(String before) {
  var state = _ScanState.code;
  var refStart = -1;
  final calls = <String>[];
  var word = '';
  for (var index = 0; index < before.length; index += 1) {
    final char = before[index];
    if (state != _ScanState.code) {
      if (char == r'\') {
        index += 1;
      } else if ((state == _ScanState.string && char == '"') || (state == _ScanState.ref && char == ']')) {
        state = _ScanState.code;
      }
      continue;
    }
    if (char == '"') {
      state = _ScanState.string;
    } else if (char == '[') {
      state = _ScanState.ref;
      refStart = index;
    } else if (char == '(') {
      calls.add(word);
    } else if (char == ')' && calls.isNotEmpty) {
      calls.removeLast();
    }
    word = _wordChar.hasMatch(char) ? word + char : '';
  }
  return _Scan(state, refStart, calls);
}

List<FormulaCompletion> _capped(List<FormulaCompletion> items) => items.take(_maxItems).toList();

FormulaCompletionResult? formulaCompletionsAt(String text, int caret, FormulaContext context) {
  final before = text.substring(0, caret);
  final position = _scan(before);
  if (position.state == _ScanState.string) return null;
  if (position.state == _ScanState.ref) {
    final partial = before.substring(position.refStart + 1);
    final path = _pathNames(before.substring(0, position.refStart));
    if (path.isNotEmpty) {
      final target = _formatAfterPath(path, context);
      return target == null ? null : FormulaCompletionResult(position.refStart, caret, _capped(_fieldItems(target, context, partial, true)));
    }
    final inside = partial.startsWith('=') ? <FormulaCompletion>[] : _fieldItems(context.format, context, partial, false);
    return FormulaCompletionResult(position.refStart, caret, _capped([...inside, ..._formulaItems(context, partial)]));
  }
  if (before.endsWith('].')) {
    final target = _formatAfterPath(_pathNames(before), context);
    return target == null ? null : FormulaCompletionResult(caret, caret, _capped(_fieldItems(target, context, '', true)));
  }
  final word = _trailingWord.firstMatch(before);
  // A word right after a number is a unit, as in 5 km.
  if (word == null || _endsWithNumber.hasMatch(before.substring(0, word.start))) return null;
  final wanted = foldFormulaName(word[0]!);
  final items = [
    for (final item in formulaFunctions)
      if (item.fr.startsWith(wanted) || item.en.startsWith(wanted))
        FormulaCompletion(
          id: 'function:${item.id}',
          label: item.name(context.french),
          detail: item.help(context.french),
          icon: Icons.calculate_outlined,
          insert: '${item.name(context.french)}(',
        ),
  ];
  return items.isEmpty ? null : FormulaCompletionResult(word.start, caret, _capped(items));
}

/// The innermost function the caret is inside of, to show its parameters.
FormulaFunction? formulaFunctionAt(String text, int caret) {
  final calls = _scan(text.substring(0, caret)).calls;
  for (final name in calls.reversed) {
    final found = name.isEmpty ? null : findFormulaFunction(name);
    if (found != null) return found;
  }
  return null;
}
