import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';

enum WorkspaceCollectionTab { entries, formats, tools }

/// Desktop sections of a collection, with the web's animated underline.
class WorkspaceCollectionTabs extends StatelessWidget {
  const WorkspaceCollectionTabs({
    super.key,
    required this.value,
    required this.onChanged,
    this.showFormats = true,
  });

  final WorkspaceCollectionTab value;
  final ValueChanged<WorkspaceCollectionTab> onChanged;

  /// T52/3: data formats are the owner's structure; collaborators do not see this tab.
  final bool showFormats;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final labels = {
      WorkspaceCollectionTab.entries: copy.text('Entries'),
      if (showFormats) WorkspaceCollectionTab.formats: copy.text('Data formats'),
      WorkspaceCollectionTab.tools: copy.isFrench ? 'Outils' : 'Tools',
    };
    return Semantics(
      container: true,
      label: copy.isFrench ? 'Sections de la collection' : 'Collection sections',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in labels.entries)
              _Tab(
                label: entry.value,
                selected: entry.key == value,
                onTap: () => onChanged(entry.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? BrainyColors.darkInk : BrainyColors.lightInk;
    final muted = dark ? BrainyColors.darkMuted : BrainyColors.lightMuted;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 52,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? ink : muted,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 2,
                height: 3,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: Duration(milliseconds: animate ? 180 : 0),
                  curve: Curves.easeOutCubic,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF2454E6),
                          Color(0xFF3B82F6),
                          Color(0xFF16A34A),
                        ],
                        stops: [0, .6, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title block of the entries section, with its count and quick action.
class WorkspaceEntriesHeading extends StatelessWidget {
  const WorkspaceEntriesHeading({
    super.key,
    required this.count,
    required this.partial,
    required this.onQuickEntry,
  });

  final int count;
  final bool partial;

  /// Null in a collection shared with me in read only (T52).
  final VoidCallback? onQuickEntry;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? BrainyColors.darkInk : BrainyColors.lightInk;
    final muted = dark ? BrainyColors.darkMuted : BrainyColors.lightMuted;
    final accent = dark ? BrainyColors.darkAccent : BrainyColors.lightAccent;
    final soft = dark ? BrainyColors.darkAccentSoft : BrainyColors.lightAccentSoft;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      copy.text('Saved entries').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(
                    copy.text('Entries'),
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count${partial ? '+' : ''} ${copy.text(count == 1 ? 'entry' : 'entries').toLowerCase()}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onQuickEntry != null) ...[
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: onQuickEntry,
          style: OutlinedButton.styleFrom(
            backgroundColor: soft,
            foregroundColor: accent,
            side: BorderSide(
              color: dark ? BrainyColors.darkLineStrong : const Color(0xFFC9D8F5),
            ),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: const TextStyle(fontFamily: 'Inter', 
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(copy.isFrench ? 'Saisie rapide' : 'Quick entry'),
        ),
        ],
      ],
    );
  }
}
