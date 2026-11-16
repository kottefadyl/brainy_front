import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_strings.dart';
import 'collections_api.dart';
import 'entry_authors.dart';
import 'entry_clipboard.dart';
import 'link_preview_card.dart';

Future<bool> showEntryDetailsDialog(
  BuildContext context, {
  required BrainyCollection collection,
  required BrainyEntry entry,
  required String formatName,
  required String created,
  String? edited,
  required AppStrings copy,
  required VoidCallback onCopy,
  required void Function(BrainyField) onReference,
  required void Function(BrainyField) onAttachment,
  required void Function(String) onLink,
  bool canEdit = true,
  /// Shows a rich preview (image, title, description, site) above each web address, as in a chat app.
  CollectionsApi? api,
}) async {
  final format = collection.formatFor(entry);
  final fields = format.fields
      .where((field) => entry.values[field.id]?.trim().isNotEmpty ?? false)
      .toList();
  final titleField = fields
      .where((field) => field.kind == BrainyFieldKind.title)
      .firstOrNull;
  final title = titleField == null ? formatName : entry.values[titleField.id]!;
  final colors = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatName,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              // Who created the entry and, once it was changed, who changed it last, in every collection.
              if (entry.createdBy != null) ...[
                const SizedBox(height: 6),
                EntryDetailsPerson(
                  label: copy.isFrench ? 'Créée par' : 'Created by',
                  icon: Icons.event_outlined,
                  person: entry.createdBy!,
                  when: created,
                ),
                if (edited != null && entry.updatedBy != null) ...[
                  const SizedBox(height: 10),
                  EntryDetailsPerson(
                    label: copy.isFrench ? 'Dernière modification par' : 'Last modified by',
                    icon: Icons.edit_outlined,
                    person: entry.updatedBy!,
                    when: edited,
                  ),
                ],
              ] else ...[
                Text(
                  '${copy.isFrench ? 'Créée' : 'Created'} $created',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
                if (edited != null)
                  Text(
                    '${copy.isFrench ? 'Modifiée' : 'Edited'} $edited',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
              ],
              const SizedBox(height: 14),
              for (final field in fields) ...[
                Divider(color: colors.outlineVariant),
                Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (field.kind == BrainyFieldKind.objectRef)
                        TextButton(
                          onPressed: () => onReference(field),
                          child: Text(
                            displayEntryValue(
                              field,
                              entry.values[field.id]!,
                              copy,
                            ),
                          ),
                        )
                      else if (field.kind == BrainyFieldKind.attachment)
                        TextButton(
                          onPressed: () => onAttachment(field),
                          child: Text(entry.values[field.id]!),
                        )
                      else if (field.kind == BrainyFieldKind.link) ...[
                        if (api != null && previewableUrl(entry.values[field.id]) != null)
                          LinkPreviewCard(
                            key: ValueKey('detail-preview-${field.id}'),
                            api: api,
                            url: previewableUrl(entry.values[field.id])!,
                            french: copy.isFrench,
                          ),
                        _LinkValue(
                          url: entry.values[field.id]!,
                          copy: copy,
                          onOpen: onLink,
                        ),
                      ] else
                        SelectableText(
                          displayEntryValue(
                            field,
                            entry.values[field.id]!,
                            copy,
                            snapshot: entry.unitSnapshots[field.id],
                            collection: collection,
                          ),
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(copy.isFrench ? 'Fermer' : 'Close'),
        ),
        TextButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.content_copy_rounded, size: 17),
          label: Text(copy.isFrench ? 'Copier l’entrée' : 'Copy entry'),
        ),
        if (canEdit) FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            entry.ledgerHash != null
                ? copy.isFrench
                      ? 'Ouvrir le registre'
                      : 'Open register'
                : copy.isFrench
                ? 'Modifier'
                : 'Edit',
          ),
        ),
      ],
    ),
  );
  return result == true;
}

class _LinkValue extends StatelessWidget {
  const _LinkValue({required this.url, required this.copy, required this.onOpen});

  final String url;
  final AppStrings copy;
  final void Function(String) onOpen;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: copy.isFrench ? 'Ouvrir le lien' : 'Open link',
            child: TextButton(
              onPressed: () => onOpen(url),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              child: Text(url),
            ),
          ),
        ),
        IconButton(
          tooltip: copy.isFrench ? 'Copier le lien' : 'Copy link',
          icon: const Icon(Icons.link_rounded, size: 19),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            messenger?.showSnackBar(
              SnackBar(
                content: Text(copy.isFrench ? 'Lien copié' : 'Link copied'),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// One line of the entry details: "Created by" or "Last modified by", with photo, name and date.
class EntryDetailsPerson extends StatelessWidget {
  const EntryDetailsPerson({super.key, required this.label, required this.icon, required this.person, required this.when});
  final String label, when;
  final IconData icon;
  final BrainyPerson person;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$label ${person.name}, $when',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          PersonAvatar(person, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: '  $when', style: TextStyle(color: muted, fontSize: 12)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}
