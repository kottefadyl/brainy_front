import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';
import 'data_format_colors.dart';
import 'design_tokens.dart';
import 'number_units.dart';
import 'workspace_hover_surface.dart';

class WorkspaceFormatCards extends StatelessWidget {
  const WorkspaceFormatCards({
    super.key,
    required this.collection,
    required this.entryCounts,
    required this.partialCounts,
    required this.onAdd,
    required this.onAddEntry,
    required this.onEdit,
    required this.onColor,
    required this.onCopy,
    required this.onLink,
    required this.onReview,
  });
  final BrainyCollection collection;
  final Map<String, int> entryCounts;
  final bool partialCounts;
  final VoidCallback onAdd;
  final ValueChanged<BrainyFormat> onAddEntry,
      onEdit,
      onColor,
      onCopy,
      onLink,
      onReview;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.layers_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                copy.text('Collection data formats'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 680 ? 2 : 1;
            final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final format in collection.formats)
                  SizedBox(
                    width: width,
                    child: _FormatCard(
                      key: ValueKey(format.id),
                      format: format,
                      count: entryCounts[format.id] ?? 0,
                      partial: partialCounts,
                      onAddEntry: () => onAddEntry(format),
                      onEdit: () => onEdit(format),
                      onColor: () => onColor(format),
                      onCopy: () => onCopy(format),
                      onLink: () => onLink(format),
                      onReview: () => onReview(format),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: collection.formats.length >= brainyFormatColors.length
              ? null
              : onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(copy.text('Add data format')),
        ),
        if (collection.formats.length >= brainyFormatColors.length)
          Text(
            copy.isFrench
                ? 'Les 24 couleurs sont utilisées. Vous pouvez modifier les formats de données existants.'
                : 'All 24 colors are in use. You can edit existing data formats.',
          ),
      ],
    );
  }
}

class _FormatCard extends StatefulWidget {
  const _FormatCard({
    super.key,
    required this.format,
    required this.count,
    required this.partial,
    required this.onAddEntry,
    required this.onEdit,
    required this.onColor,
    required this.onCopy,
    required this.onLink,
    required this.onReview,
  });
  final BrainyFormat format;
  final int count;
  final bool partial;
  final VoidCallback onAddEntry, onEdit, onColor, onCopy, onLink, onReview;
  @override
  State<_FormatCard> createState() => _FormatCardState();
}

class _FormatCardState extends State<_FormatCard> {
  bool _expanded = false;
  Widget _revealFields(BuildContext context, Widget child) =>
      MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topLeft,
          child: child,
        );
  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final format = widget.format;
    final surface = DataFormatColors.surface(format.color, dark);
    final marker = DataFormatColors.marker(format.color, dark);
    final ink = dark ? BrainyColors.darkInk : BrainyColors.lightInk;
    final muted = dark ? BrainyColors.darkMuted : BrainyColors.lightMuted;
    final name = format.id.startsWith('legacy-') && format.name == 'General'
        ? copy.text('General')
        : format.name;
    final fields =
        '${format.fields.length} ${fr
            ? format.fields.length == 1
                  ? 'champ'
                  : 'champs'
            : format.fields.length == 1
            ? 'field'
            : 'fields'}';
    final entries =
        '${widget.count} ${fr
            ? widget.count == 1
                  ? 'entrée'
                  : 'entrées'
            : widget.count == 1
            ? 'entry'
            : 'entries'}${widget.partial
            ? fr
                  ? widget.count == 1
                        ? ' affichée'
                        : ' affichées'
                  : ' shown'
            : ''}';
    return WorkspaceHoverSurface(
      color: surface,
      marker: marker,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color.lerp(surface, marker, .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.layers_outlined, size: 18, color: marker),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$fields · $entries',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (format.linkedSource != null)
            TextButton.icon(
              onPressed: widget.onReview,
              icon: const Icon(Icons.sync_outlined, size: 17),
              label: Text(
                '${copy.text('Review updates')} · ${format.linkedSource!['acceptedVersion']}',
              ),
            ),
          const SizedBox(height: 14),
          _revealFields(
            context,
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final field in format.fields.take(
                  _expanded ? format.fields.length : 3,
                ))
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: field.name,
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' · ${copy.text(field.kind.label)}${field.unit == null ? '' : ' · ${numberUnit(field.unit)?.symbol ?? field.unit}'}',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
              ],
            ),
          ),
          if (format.fields.length > 3)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: muted,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _expanded
                    ? fr
                          ? 'Réduire'
                          : 'Show less'
                    : fr
                    ? '${format.fields.length - 3} ${format.fields.length == 4 ? 'autre champ' : 'autres champs'}'
                    : '${format.fields.length - 3} more ${format.fields.length == 4 ? 'field' : 'fields'}',
              ),
            ),
          const SizedBox(height: 12),
          Divider(height: 1, color: marker.withValues(alpha: .12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onAddEntry,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(fr ? 'Ajouter une entrée' : 'Add entry'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: dark
                          ? BrainyColors.darkAccent
                          : BrainyColors.blue,
                      backgroundColor: Color.lerp(
                        surface,
                        dark
                            ? BrainyColors.darkSurface
                            : BrainyColors.lightSurface,
                        .65,
                      ),
                      side: BorderSide(
                        color: dark
                            ? Color.lerp(BrainyColors.darkControl, marker, .2)!
                            : BrainyColors.lightControl,
                      ),
                      textStyle: const TextStyle(fontFamily: 'Inter', 
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: fr
                    ? 'Actions du format de données'
                    : 'Data format actions',
                icon: Icon(Icons.more_horiz_rounded, color: ink),
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      widget.onEdit();
                    case 'color':
                      widget.onColor();
                    case 'copy':
                      widget.onCopy();
                    case 'link':
                      widget.onLink();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(copy.text('Edit data format')),
                  ),
                  PopupMenuItem(
                    value: 'color',
                    child: Text(copy.text('Change color')),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: Text(copy.text('Copy to collection')),
                  ),
                  PopupMenuItem(
                    value: 'link',
                    child: Text(copy.text('Share by link')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
