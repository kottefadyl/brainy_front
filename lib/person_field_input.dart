// T54: collaborator field. Chooses one or more people among the collection owner and the owner's collaborators.
import 'dart:convert';

import 'package:flutter/material.dart';

import 'collections_api.dart';
import 'entry_authors.dart';

/// People of a collection, read once per collection while the app runs.
final _peopleByCollection = <String, Future<List<BrainyPerson>>>{};

/// Editable text of a collaborator field: the people's IDs as a JSON list.
String personFieldEditableValue(BrainyEntry? entry, BrainyField field) {
  final people = entry?.people[field.id];
  if (people == null || people.isEmpty) return entry?.values[field.id] ?? '';
  return jsonEncode([for (final person in people) person.userId]);
}

class PersonFieldInput extends StatefulWidget {
  const PersonFieldInput({
    super.key,
    required this.api,
    required this.collectionId,
    required this.field,
    required this.controller,
    required this.french,
    required this.onChanged,
    this.stored = const [],
  });

  final CollectionsApi api;
  final String collectionId;
  final BrainyField field;
  final TextEditingController controller;
  final bool french;
  final VoidCallback onChanged;

  /// People saved on the entry, kept visible after their collaboration ended.
  final List<BrainyPerson> stored;

  @override
  State<PersonFieldInput> createState() => _PersonFieldInputState();
}

class _PersonFieldInputState extends State<PersonFieldInput> {
  late Future<List<BrainyPerson>> _people = _load();

  Future<List<BrainyPerson>> _load() {
    final future = _peopleByCollection.putIfAbsent(widget.collectionId, () => widget.api.collectionPeople(widget.collectionId));
    future.catchError((Object _) {
      _peopleByCollection.remove(widget.collectionId);
      return <BrainyPerson>[];
    });
    return future;
  }

  List<String> get _selected {
    try {
      return (jsonDecode(widget.controller.text) as List<dynamic>).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  void _toggle(String userId) {
    final selected = _selected;
    final next = selected.contains(userId) ? selected.where((id) => id != userId).toList() : [...selected, userId];
    widget.controller.text = next.isEmpty ? '' : jsonEncode(next);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final fr = widget.french;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: widget.field.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: '  ${fr ? 'Collaborateur' : 'Collaborator'}', style: muted),
          ])),
          const SizedBox(height: 8),
          FutureBuilder<List<BrainyPerson>>(
            future: _people,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Row(children: [
                  Flexible(child: Text(fr ? 'Impossible de charger les collaborateurs.' : 'Could not load collaborators.', style: muted)),
                  TextButton(onPressed: () => setState(() => _people = _load()), child: Text(fr ? 'Réessayer' : 'Retry')),
                ]);
              }
              if (!snapshot.hasData) {
                return const SizedBox(height: 48, child: Align(alignment: Alignment.centerLeft, child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))));
              }
              final people = snapshot.data!;
              final selected = _selected;
              final former = widget.stored.where((person) => selected.contains(person.userId) && !people.any((item) => item.userId == person.userId));
              final ownerId = people.firstOrNull?.userId;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final person in [...people, ...former])
                        FilterChip(
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          avatar: PersonAvatar(person, size: 26),
                          label: Text(person.userId == ownerId ? '${person.name} · ${fr ? 'propriétaire' : 'owner'}' : person.name, overflow: TextOverflow.ellipsis),
                          selected: selected.contains(person.userId),
                          showCheckmark: false,
                          onSelected: (_) => _toggle(person.userId),
                        ),
                    ],
                  ),
                  if (people.length < 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(fr ? 'Invitez des collaborateurs depuis « Autres actions » pour pouvoir les choisir ici.' : 'Invite collaborators from “More actions” to choose them here.', style: muted),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
