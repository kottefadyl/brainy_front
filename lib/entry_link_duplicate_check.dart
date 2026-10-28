import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'collections_api.dart';

Future<bool> confirmDuplicateLinks({
  required BuildContext context,
  required CollectionsApi api,
  required String collectionId,
  required String formatId,
  required String? entryId,
  required Iterable<BrainyField> fields,
  required Map<String, String> values,
  required bool isFrench,
}) async {
  for (final field in fields.where((item) => item.kind == BrainyFieldKind.link)) {
    final url = values[field.id] ?? '';
    if (url.isEmpty) continue;
    List<BrainyEntry> duplicates;
    try {
      duplicates = await api.duplicateLinks(collectionId, formatId, field.id, url, excludeEntryId: entryId);
    } on AuthApiException catch (cause) {
      if (cause.message.contains('Could not reach') || cause.message.contains('temporarily unavailable')) continue;
      rethrow;
    }
    if (duplicates.isEmpty || !context.mounted) continue;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFrench ? 'Lien déjà enregistré' : 'Link already saved'),
        content: Text(isFrench
            ? 'Ce lien existe déjà dans ${duplicates.length} entrée(s). Voulez-vous quand même enregistrer ?'
            : 'This link already exists in ${duplicates.length} entry or entries. Save anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isFrench ? 'Vérifier' : 'Check')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isFrench ? 'Enregistrer encore' : 'Save anyway')),
        ],
      ),
    );
    if (proceed != true) return false;
  }
  return true;
}
