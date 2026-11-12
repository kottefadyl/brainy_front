// T47/3: the owner chooses which data formats appear in the book, and as what (chapter, section…).
import 'package:flutter/material.dart';

import 'book_model.dart';
import 'collections_api.dart';

/// Roles the owner can give to any data format; front and back matter pages keep their template role.
const assignableBookRoles = ['PART', 'CHAPTER', 'SECTION', 'SUBSECTION', 'APPENDIX', 'TERM', 'SOURCE'];

extension BookFormatRoleApi on CollectionsApi {
  Future<BookSettings> setBookFormatRole(String collectionId, String formatId, String? role) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$id:String!,\$formatId:String!,\$role:String){setBookFormatRole(collectionId:\$id,formatId:\$formatId,role:\$role){bookView{enabled bodyFont headingFont fontSize lineHeight paragraphSpacing firstLineIndent marginMm textAlign pageSize showRuler chapterOnNewPage roles{formatId role}}}}',
      {'id': collectionId, 'formatId': formatId, 'role': role},
    );
    return BookSettings.fromJson((data['setBookFormatRole'] as Map<String, dynamic>)['bookView'] as Map<String, dynamic>?);
  }
}

class BookFormatRoles extends StatelessWidget {
  const BookFormatRoles({super.key, required this.formats, required this.roles, required this.french, required this.busyFormatId, required this.onChanged});
  final List<BrainyFormat> formats;
  final Map<String, String> roles;
  final bool french;
  final String busyFormatId;
  final void Function(String formatId, String? role) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = formats.where((format) => !roles.containsKey(format.id) || assignableBookRoles.contains(roles[format.id])).toList();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(french ? 'Formats de données dans le livre' : 'Data formats in the book', style: const TextStyle(fontWeight: FontWeight.w600)),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Align(alignment: Alignment.centerLeft, child: Text(french ? 'Choisissez comment chaque format de données apparaît dans le livre, ou « Non affiché ».' : 'Choose how each data format appears in the book, or “Not shown”.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
        const SizedBox(height: 6),
        for (final format in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: DropdownButtonFormField<String>(
              key: ValueKey('book-role-${format.id}-${roles[format.id]}'),
              isExpanded: true,
              initialValue: roles[format.id] ?? '',
              decoration: InputDecoration(labelText: format.name, isDense: true),
              items: [
                DropdownMenuItem(value: '', child: Text(french ? 'Non affiché' : 'Not shown')),
                for (final role in assignableBookRoles) DropdownMenuItem(value: role, child: Text(bookRoleLabel(role, french))),
              ],
              onChanged: busyFormatId == format.id ? null : (value) => onChanged(format.id, value == null || value.isEmpty ? null : value),
            ),
          ),
      ],
    );
  }
}
