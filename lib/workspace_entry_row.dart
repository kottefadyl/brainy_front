import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data_format_colors.dart';
import 'design_tokens.dart';
import 'workspace_hover_surface.dart';

class WorkspaceEntryRow extends StatelessWidget {
  const WorkspaceEntryRow({
    super.key,
    required this.color,
    required this.title,
    required this.formatName,
    required this.created,
    required this.onDetails,
    required this.onAction,
    this.preview,
    this.edited,
    this.appendOnly = false,
    this.reminders = true,
    this.canWrite = true,
    this.attachment,
    this.authors,
  });

  /// T53: creator and last editor, top left (shared collections only).
  final Widget? authors;
  final String color, title, formatName, created;
  /// Extra content under the values, such as a saved link preview (T48).
  final Widget? attachment;
  final String? preview, edited;
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WorkspaceHoverSurface(
        color: DataFormatColors.surface(color, dark),
        marker: marker,
        padding: const EdgeInsets.fromLTRB(12, 5, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (authors != null) Padding(padding: const EdgeInsets.only(top: 7), child: authors!),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onDetails,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(0, 48),
                      padding: EdgeInsets.zero,
                      foregroundColor: ink,
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
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
                    PopupMenuItem(
                      value: 'copy',
                      child: Text(copy.text('Copy entry')),
                    ),
                    if (canWrite) PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        appendOnly
                            ? copy.isFrench
                                  ? 'Ouvrir le registre'
                                  : 'Open register'
                            : copy.text('Edit'),
                      ),
                    ),
                    if (reminders) PopupMenuItem(
                      value: 'reminder',
                      child: Text(copy.isFrench ? 'Rappels' : 'Reminders'),
                    ),
                    if (canWrite) PopupMenuItem(
                      value: 'links',
                      child: Text(
                        copy.isFrench ? 'Liens entre entrées' : 'Entry links',
                      ),
                    ),
                    if (!appendOnly && canWrite)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          copy.text('Delete'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  preview!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ),
            ?attachment,
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: marker,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 6, height: 6),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        formatName,
                        style: TextStyle(color: ink, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${copy.text('Created')} $created',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                if (edited != null)
                  Text(
                    '${copy.text('Edited')} $edited',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
