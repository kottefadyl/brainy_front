import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'app_strings.dart';

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i',
  'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

/// Lower-case, accent-free form used to compare suggestions with typed text.
String foldSuggestion(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().trim().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Ranks suggestions matching [query] in either language; labels use the
/// interface language. Already chosen values are left out.
List<String> searchProfileSuggestions(
  List<(String, String)> suggestions,
  String query, {
  required bool french,
  Iterable<String> exclude = const [],
  int limit = 8,
}) {
  final needle = foldSuggestion(query);
  if (needle.isEmpty) return const [];
  final excluded = exclude.map(foldSuggestion).toSet();
  final ranked = <(String, int)>[];
  for (final (en, fr) in suggestions) {
    final label = french ? fr : en;
    if (excluded.contains(foldSuggestion(label))) continue;
    var rank = 3;
    for (final text in [foldSuggestion(en), foldSuggestion(fr)]) {
      if (text.startsWith(needle)) {
        rank = math.min(rank, 0);
      } else if (text.split(RegExp(r'[\s/’\x27-]+')).any((word) => word.startsWith(needle))) {
        rank = math.min(rank, 1);
      } else if (text.contains(needle)) {
        rank = math.min(rank, 2);
      }
    }
    if (rank < 3) ranked.add((label, rank));
  }
  ranked.sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
  return ranked.take(limit).map((item) => item.$1).toList();
}

class _Option {
  const _Option(this.value, this.label, {this.typed = false});
  final String value;
  final String label;
  final bool typed;
}

Widget _optionsView(
  BuildContext context,
  AutocompleteOnSelected<_Option> onSelected,
  Iterable<_Option> options,
  double width,
) {
  final scheme = Theme.of(context).colorScheme;
  final highlighted = AutocompleteHighlightedOption.of(context);
  final items = options.toList();
  return Align(
    alignment: Alignment.topLeft,
    child: Material(
      elevation: 6,
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 300, maxWidth: width),
        child: ListView.builder(
          padding: const EdgeInsets.all(6),
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final option = items[index];
            final active = index == highlighted;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelected(option),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? scheme.primary.withValues(alpha: .12) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: option.typed ? scheme.primary : scheme.onSurface,
                    fontWeight: option.typed ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

InputDecoration _decoration(BuildContext context, String label, String hint, {bool optional = false, String? placeholder}) {
  final copy = AppStrings.of(context);
  return InputDecoration(
    labelText: optional ? '$label · ${copy.text('Optional')}' : label,
    helperText: hint,
    helperMaxLines: 3,
    hintText: placeholder,
    border: const OutlineInputBorder(),
  );
}

/// One free-text value with suggestions (profession, current job).
class SuggestTextField extends StatefulWidget {
  const SuggestTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.suggestions,
    this.optional = false,
    this.maxLength = 100,
  });

  final String label;
  final TextEditingController controller;
  final List<(String, String)> suggestions;
  final bool optional;
  final int maxLength;

  @override
  State<SuggestTextField> createState() => _SuggestTextFieldState();
}

class _SuggestTextFieldState extends State<SuggestTextField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<_Option>(
        textEditingController: widget.controller,
        focusNode: _focus,
        displayStringForOption: (option) => option.value,
        optionsBuilder: (value) => searchProfileSuggestions(widget.suggestions, value.text, french: copy.isFrench)
            .where((item) => foldSuggestion(item) != foldSuggestion(value.text))
            .map((item) => _Option(item, item)),
        optionsViewBuilder: (context, onSelected, options) => _optionsView(context, onSelected, options, constraints.maxWidth),
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: widget.maxLength,
          buildCounter: quietFormCounter,
          onSubmitted: (_) => onSubmitted(),
          decoration: _decoration(context, widget.label, copy.text('Choose from the list or type your own.'), optional: widget.optional),
        ),
      ),
    );
  }
}

/// Several free-text values shown as removable chips, with suggestions
/// (interests, hobbies). A comma adds exactly what was typed.
class SuggestTagsField extends StatefulWidget {
  const SuggestTagsField({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    required this.suggestions,
    this.maxItems = 12,
    this.maxLength = 60,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final List<(String, String)> suggestions;
  final int maxItems;
  final int maxLength;

  @override
  State<SuggestTagsField> createState() => _SuggestTagsFieldState();
}

class _SuggestTagsFieldState extends State<SuggestTagsField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _controller.text.trim().isNotEmpty) _add([_controller.text]);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _full => widget.values.length >= widget.maxItems;

  void _add(List<String> raw) {
    final next = [...widget.values];
    for (final text in raw) {
      final item = text.trim();
      final cut = item.length > widget.maxLength ? item.substring(0, widget.maxLength) : item;
      if (cut.isNotEmpty && next.length < widget.maxItems &&
          !next.any((value) => foldSuggestion(value) == foldSuggestion(cut))) {
        next.add(cut);
      }
    }
    _controller.clear();
    if (next.length != widget.values.length) widget.onChanged(next);
  }

  void _typed(String text) {
    final parts = text.split(RegExp(r'[,;\n]'));
    if (parts.length < 2) return;
    final rest = parts.last;
    _add(parts.sublist(0, parts.length - 1));
    _controller.value = TextEditingValue(text: rest, selection: TextSelection.collapsed(offset: rest.length));
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final hint = _full
        ? copy.text('Keep up to 12 interests or hobbies, with 60 characters per item.')
        : copy.text('Choose from the list or type your own. A comma adds exactly what you typed.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => RawAutocomplete<_Option>(
            textEditingController: _controller,
            focusNode: _focus,
            displayStringForOption: (option) => '',
            optionsBuilder: (value) {
              final typed = value.text.trim();
              if (_full || typed.isEmpty) return const [];
              final matches = searchProfileSuggestions(widget.suggestions, typed, french: copy.isFrench, exclude: widget.values)
                  .map((item) => _Option(item, item))
                  .toList();
              final exact = matches.any((item) => foldSuggestion(item.value) == foldSuggestion(typed)) ||
                  widget.values.any((item) => foldSuggestion(item) == foldSuggestion(typed));
              return [
                ...matches,
                if (!exact) _Option(typed, copy.text('Add “{value}”').replaceAll('{value}', typed), typed: true),
              ];
            },
            onSelected: (option) => _add([option.value]),
            optionsViewBuilder: (context, onSelected, options) => _optionsView(context, onSelected, options, constraints.maxWidth),
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !_full,
              maxLength: widget.maxLength,
              buildCounter: quietFormCounter,
              onChanged: _typed,
              onSubmitted: (_) {
                onSubmitted();
                if (controller.text.trim().isNotEmpty) _add([controller.text]);
                focusNode.requestFocus();
              },
              decoration: _decoration(context, widget.label, hint, placeholder: copy.text('Search or type…')),
            ),
          ),
        ),
        if (widget.values.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in widget.values)
                  InputChip(
                    label: Text(item, overflow: TextOverflow.ellipsis),
                    onDeleted: () => widget.onChanged(widget.values.where((value) => value != item).toList()),
                    deleteButtonTooltipMessage: copy.text('Remove {item}').replaceAll('{item}', item),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
