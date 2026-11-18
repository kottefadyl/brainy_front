import 'package:flutter/material.dart';

import 'collections_api.dart';

const _maxCards = 6;

/// New entry: the collection's data formats as small colored cards; a tap chooses one.
/// At most 6 cards (the chosen one always among them); with more, a list gives every data format.
class FormatChoiceCards extends StatelessWidget {
  const FormatChoiceCards({
    super.key,
    required this.formats,
    required this.selectedId,
    required this.label,
    required this.isFrench,
    required this.tintOf,
    required this.nameOf,
    required this.onChanged,
  });

  final List<BrainyFormat> formats;
  final String selectedId;
  final String label;
  final bool isFrench;
  final Color Function(BrainyFormat format) tintOf;
  final String Function(BrainyFormat format) nameOf;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    var shown = formats.take(_maxCards).toList();
    final chosen = formats.where((format) => format.id == selectedId).firstOrNull;
    if (chosen != null && !shown.contains(chosen)) shown = [...shown.take(_maxCards - 1), chosen];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : (constraints.maxWidth / 170).floor().clamp(2, 4);
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final format in shown) SizedBox(width: width, child: _card(context, format, dark)),
        ]);
      }),
      if (formats.length > _maxCards) ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('all-formats-$selectedId'),
          initialValue: selectedId,
          isExpanded: true,
          decoration: InputDecoration(labelText: isFrench ? 'Tous les formats de données (${formats.length})' : 'All data formats (${formats.length})', border: const OutlineInputBorder()),
          items: [
            for (final format in formats)
              DropdownMenuItem(
                value: format.id,
                child: Row(children: [
                  Container(width: 16, height: 16, decoration: BoxDecoration(color: tintOf(format), borderRadius: BorderRadius.circular(5))),
                  const SizedBox(width: 9),
                  Expanded(child: Text(nameOf(format), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    ]);
  }

  Widget _card(BuildContext context, BrainyFormat format, bool dark) {
    final tint = tintOf(format);
    final selected = format.id == selectedId;
    final background = dark ? Color.alphaBlend(tint.withValues(alpha: 0.24), const Color(0xFF232327)) : tint;
    final marker = dark ? tint : Color.alphaBlend(Colors.black.withValues(alpha: 0.45), tint);
    final ink = dark ? const Color(0xFFF2F3F5) : const Color(0xFF20242C);
    final count = format.fields.length;
    final names = format.fields.take(3).map((field) => field.name).join(' · ') + (count > 3 ? ' +${count - 3}' : '');
    final countLabel = isFrench ? '$count champ${count > 1 ? 's' : ''}' : '$count field${count > 1 ? 's' : ''}';
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: nameOf(format),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? marker : Colors.transparent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(format.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: 74),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: marker, width: 4))),
            padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nameOf(format), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  if (names.isNotEmpty) Text(names, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink.withValues(alpha: 0.75), fontSize: 12)),
                  Text(countLabel, style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 11.5)),
                ]),
              ),
              if (selected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: marker, shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 14, color: dark ? const Color(0xFF232327) : Colors.white),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
