// Search among collaborators as you type (name or e-mail, without regard to case or accents).
// With many collaborators, only the first matches are shown until the search is narrowed.
import 'package:flutter/material.dart';

import 'collaborators_api.dart';

const maxShownCollaborators = 100;

String _fold(String text) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.characters) {
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}

List<BrainyCollaborator> filterCollaborators(List<BrainyCollaborator> people, String query) {
  final words = _fold(query).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return people;
  return people.where((person) { final text = _fold('${person.name} ${person.email}'); return words.every(text.contains); }).toList();
}

class CollaboratorSearchField extends StatelessWidget {
  const CollaboratorSearchField({super.key, required this.onChanged, required this.total, required this.shown, required this.query, required this.french});
  final ValueChanged<String> onChanged;
  final int total, shown;
  final String query;
  final bool french;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final status = query.trim().isNotEmpty && shown == 0
        ? (french ? 'Aucun collaborateur ne correspond.' : 'No collaborator matches.')
        : shown < total ? (french ? '$shown sur $total affichés : précisez la recherche.' : '$shown of $total shown: narrow the search.') : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          key: const Key('collaborator-search'),
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: french ? 'Rechercher par nom ou e-mail…' : 'Search by name or e-mail…',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (status != null) Padding(padding: const EdgeInsets.only(top: 4), child: Semantics(liveRegion: true, child: Text(status, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)))),
      ]),
    );
  }
}
