// T53: creator and last editor of an entry (and of a data format), shown only in shared collections.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'auth_api.dart';
import 'collections_api.dart';

/// A collection is shared once it has a member, or when it is shared with me.
bool isSharedCollection(BrainyCollection collection) => collection.sharedBy != null || collection.members.isNotEmpty;

/// Photos are read once per person; set by the workspace when it opens.
class EntryAuthorPhotos {
  static AuthApi? auth;
  static final _cache = <String, Future<Uint8List?>>{};

  static Future<Uint8List?> of(String userId) => _cache.putIfAbsent(userId, () async {
        final api = auth;
        if (api == null) return null;
        try {
          final data = await api.authenticatedRequest('query(\$userId:String!){personPhoto(userId:\$userId)}', {'userId': userId});
          final url = data['personPhoto'] as String?;
          if (url == null || !url.startsWith('data:')) return null;
          return base64Decode(url.substring(url.indexOf(',') + 1));
        } catch (_) {
          return null;
        }
      });
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.person, {this.size = 22});
  final BrainyPerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = Text(person.name.characters.firstOrNull?.toUpperCase() ?? '?', style: TextStyle(fontSize: size * .5, fontWeight: FontWeight.w700, color: scheme.primary));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surface, border: Border.all(color: Theme.of(context).dividerColor)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: !person.hasPhoto
          ? initial
          : FutureBuilder<Uint8List?>(
              future: EntryAuthorPhotos.of(person.userId),
              builder: (context, snapshot) => snapshot.data == null ? initial : Image.memory(snapshot.data!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
            ),
    );
  }
}

class _People extends StatelessWidget {
  const _People({required this.creator, this.editor, required this.label, this.compact = false});
  final BrainyPerson creator;
  final BrainyPerson? editor;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final theme = Theme.of(context);
    final changed = editor != null && editor!.userId != creator.userId ? editor : null;
    // Phone: photos only; names stay in the tooltip and the screen reader label.
    final names = !compact && MediaQuery.sizeOf(context).width >= 560;
    final description = changed == null ? '$label ${creator.name}' : '$label ${creator.name} · ${fr ? 'modifiée par' : 'edited by'} ${changed.name}';
    final nameStyle = theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    return Tooltip(
      message: description,
      child: Semantics(
        label: description,
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _Avatar(creator, size: compact ? 20 : 22),
          if (names) ...[const SizedBox(width: 6), Flexible(child: Text(creator.name, style: nameStyle, overflow: TextOverflow.ellipsis))],
          if (changed != null) ...[
            if (names) Text('  · ${fr ? 'modifié par' : 'edited by'}  ', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)) else const SizedBox(width: 3),
            _Avatar(changed, size: compact ? 20 : 22),
            if (names) ...[const SizedBox(width: 6), Flexible(child: Text(changed.name, style: nameStyle, overflow: TextOverflow.ellipsis))],
          ],
        ]),
      ),
    );
  }
}

/// Creator then last editor of an entry; nothing outside shared collections or for entries kept offline.
class EntryAuthors extends StatelessWidget {
  const EntryAuthors({super.key, required this.entry, required this.collection, this.compact = false});
  final BrainyEntry entry;
  final BrainyCollection collection;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final creator = entry.createdBy;
    if (!isSharedCollection(collection) || creator == null) return const SizedBox.shrink();
    final fr = AppStrings.of(context).isFrench;
    return _People(creator: creator, editor: entry.updatedBy, label: fr ? 'Créée par' : 'Created by', compact: compact);
  }
}

/// Only the owner creates and changes data formats, so the owner is both the creator and the last editor.
class FormatAuthors extends StatelessWidget {
  const FormatAuthors({super.key, required this.collection});
  final BrainyCollection collection;

  @override
  Widget build(BuildContext context) {
    final ownerId = collection.ownerId;
    if (!isSharedCollection(collection) || ownerId == null) return const SizedBox.shrink();
    final fr = AppStrings.of(context).isFrench;
    final owner = (userId: ownerId, name: collection.sharedBy?.name ?? (fr ? 'Vous' : 'You'), hasPhoto: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _People(creator: owner, label: fr ? 'Créé et modifié par' : 'Created and edited by'),
    );
  }
}
