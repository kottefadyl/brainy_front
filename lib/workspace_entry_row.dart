import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data_format_colors.dart';
import 'design_tokens.dart';
import 'workspace_hover_surface.dart';

/// One entry in the list, slim: one line on wide screens (title, key values, then data format, date
/// and actions), two short lines on phones. A double-click / double-tap opens the details, as does the
/// title or the eye button; the ⋯ menu holds the other actions. Same meaning as the web's `entry-card.tsx`.
class WorkspaceEntryRow extends StatelessWidget {
  const WorkspaceEntryRow({
    super.key,
    required this.color,
    required this.title,
    required this.formatName,
    required this.created,
    required this.onDetails,
    required this.onAction,
    this.facts = const [],
    this.hiddenFacts = 0,
    this.edited,
    this.appendOnly = false,
    this.reminders = true,
    this.canWrite = true,
    this.attachment,
    this.authors,
  });

  /// T53: creator and last editor (shared collections only).
  final Widget? authors;
  final String color, title, formatName, created;

  /// Up to three labelled values shown after the title; [hiddenFacts] more are left for the details.
  final List<({String label, String value})> facts;
  final int hiddenFacts;

  /// A compact saved link preview (T48), shown next to the title.
  final Widget? attachment;
  final String? edited;
  final bool appendOnly;

  /// False when reminders are paused on this hosting.
  final bool reminders;

  /// T52/3: false in a collection shared with me in read only.
  final bool canWrite;
  final VoidCallback onDetails;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? BrainyColors.darkInk : BrainyColors.lightInk;
    final muted = dark ? BrainyColors.darkMuted : BrainyColors.lightMuted;
    final marker = DataFormatColors.marker(color, dark);

    final titleButton = Tooltip(
      message: copy.isFrench ? 'Double-cliquez pour voir les détails' : 'Double-click to see the details',
      waitDuration: const Duration(milliseconds: 800),
      child: TextButton(
        onPressed: onDetails,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size(0, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: ink,
        ),
        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      ),
    );
    final factsLine = facts.isEmpty
        ? null
        : Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 13, color: ink),
              children: [
                for (final (index, fact) in facts.indexed) ...[
                  if (index > 0) const TextSpan(text: '    '),
                  TextSpan(text: '${fact.label} ', style: TextStyle(color: muted)),
                  TextSpan(text: fact.value),
                ],
                if (hiddenFacts > 0) TextSpan(text: '    +$hiddenFacts', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    final formatChip = Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 8, 2),
      decoration: BoxDecoration(color: Color.lerp(DataFormatColors.surface(color, dark), marker, .12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(decoration: BoxDecoration(color: marker, shape: BoxShape.circle), child: const SizedBox(width: 7, height: 7)),
          const SizedBox(width: 6),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(formatName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    final date = Semantics(
      label: '${copy.text('Created')} $created${edited != null ? ', ${copy.text('Edited')} $edited' : ''}',
      excludeSemantics: true,
      child: Tooltip(
        message: '${copy.text('Created')} $created${edited != null ? '\n${copy.text('Edited')} $edited' : ''}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 13, color: dark ? BrainyColors.darkAccent : BrainyColors.lightAccent),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${copy.text('Created')} $created${edited != null ? ' · ${copy.text('Edited')} $edited' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onDetails,
          tooltip: copy.isFrench ? 'Voir les détails' : 'View details',
          icon: Icon(Icons.visibility_outlined, size: 19, color: ink),
        ),
        PopupMenuButton<String>(
          tooltip: copy.text('Entry actions'),
          icon: Icon(Icons.more_horiz_rounded, color: ink),
          onSelected: onAction,
          itemBuilder: (_) => [
            PopupMenuItem(value: 'copy', child: Text(copy.text('Copy entry'))),
            if (canWrite)
              PopupMenuItem(value: 'edit', child: Text(appendOnly ? (copy.isFrench ? 'Ouvrir le registre' : 'Open register') : copy.text('Edit'))),
            if (reminders) PopupMenuItem(value: 'reminder', child: Text(copy.isFrench ? 'Rappels' : 'Reminders')),
            if (canWrite) PopupMenuItem(value: 'links', child: Text(copy.isFrench ? 'Liens entre entrées' : 'Entry links')),
            if (!appendOnly && canWrite)
              PopupMenuItem(value: 'delete', child: Text(copy.text('Delete'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: WorkspaceHoverSurface(
        color: DataFormatColors.surface(color, dark),
        marker: marker,
        padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 640;
            final content = wide
                ? Row(
                    children: [
                      Flexible(flex: 3, child: titleButton),
                      if (attachment != null) ...[const SizedBox(width: 12), Flexible(flex: 3, child: attachment!)],
                      if (factsLine != null) ...[const SizedBox(width: 14), Expanded(flex: 4, child: factsLine)] else const Spacer(),
                      const SizedBox(width: 12),
                      Flexible(flex: 2, child: formatChip),
                      const SizedBox(width: 10),
                      Flexible(flex: 2, child: date),
                      if (authors != null) ...[const SizedBox(width: 8), authors!],
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleButton,
                        if (attachment != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: attachment!),
                        ?factsLine,
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [formatChip, date, ?authors],
                        ),
                      ],
                    ),
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Double-click (mouse) or double-tap (touch) on the row opens the details.
                    Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onDoubleTap: onDetails, child: content)),
                    actions,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
