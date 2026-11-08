// T32 — EN/FR texts shared by the data source screens.
String dsTr(bool fr, String en, String frText) => fr ? frText : en;

const _frErrors = <String, String>{
  'Only a collection owner':
      'Seul le propriétaire de la collection peut faire cette action.',
  'Read-only members': 'Les lecteurs ne peuvent pas envoyer de données.',
  'needs access to every field': 'Cette source de données demande l’accès à tous les champs de son format de données.',
  'MISSING_COLUMN': 'Colonne absente du fichier : ',
  'already used for different content':
      'Cet identifiant de livraison a déjà servi pour un autre contenu.',
  'A delivery cannot exceed 4 MB': 'Une livraison ne peut pas dépasser 4 Mo.',
  'rows per delivery': 'Envoyez de 1 à 10 000 lignes par livraison.',
  'not valid JSON': 'Le fichier n’est pas un JSON valide.',
  'Column names must be present and distinct':
      'Les noms de colonnes doivent être présents et distincts.',
  'cannot write into a register': 'Une source de données ne peut pas écrire dans un registre ni dans un format de données avec flux d’états.',
  'Map a column to the object name': 'Associez une colonne au nom de l’objet.',
  'Each column and field can be mapped once':
      'Chaque colonne et chaque champ ne peuvent être associés qu’une fois.',
  'up to 20 data sources':
      'Une collection peut avoir 20 sources de données au plus.',
  'Cancel the running delivery':
      'Annulez la livraison en cours avant de supprimer cette source.',
  'No rejected row to retry': 'Aucune ligne rejetée à relancer.',
};

String dataSourceErrorText(Object error, bool fr) {
  final message = error.toString().replaceFirst(
    RegExp(r'^(Exception|ApiException|AuthException):\s*'),
    '',
  );
  if (!fr) return message;
  for (final entry in _frErrors.entries) {
    if (message.contains(entry.key)) {
      return entry.key == 'MISSING_COLUMN'
          ? entry.value +
                message.replaceFirst(RegExp(r'^.*Missing column:\s*'), '')
          : entry.value;
    }
  }
  return message;
}

String rejectionLabel(String code, bool fr) => switch (code) {
  'MISSING_RECORD_ID' => dsTr(fr, 'Missing record ID', 'Identifiant manquant'),
  'DUPLICATE_IN_DELIVERY' => dsTr(
    fr,
    'Repeated in this delivery',
    'Répété dans cette livraison',
  ),
  'EMPTY_ROW' => dsTr(fr, 'No mapped value', 'Aucune valeur correspondante'),
  'INVALID_OBSERVED_AT' => dsTr(
    fr,
    'Invalid fact date',
    'Date du fait invalide',
  ),
  'UNIT_MISMATCH' => dsTr(fr, 'Different unit', 'Unité différente'),
  'INVALID_VALUE' => dsTr(fr, 'Invalid value', 'Valeur invalide'),
  'LOCKED_ENTRY' => dsTr(fr, 'Entry locked', 'Entrée verrouillée'),
  'COLUMN_COUNT' => dsTr(
    fr,
    'Wrong number of columns',
    'Nombre de colonnes incorrect',
  ),
  'CHANGED_DURING_RUN' => dsTr(
    fr,
    'Edited during the delivery',
    'Modifiée pendant la livraison',
  ),
  _ => code,
};

String runStateLabel(String state, bool fr) => switch (state) {
  'QUEUED' => dsTr(fr, 'Waiting', 'En attente'),
  'RUNNING' => dsTr(fr, 'In progress', 'En cours'),
  'COMPLETED' => dsTr(fr, 'Finished', 'Terminée'),
  'FAILED' => dsTr(fr, 'Stopped by an error', 'Arrêtée par une erreur'),
  'CANCELLED' => dsTr(fr, 'Cancelled', 'Annulée'),
  _ => state,
};
