import 'package:flutter/material.dart';

import 'auth_api.dart';

/// English is the source language. Every visible application label has a
/// French counterpart; user-created names and values are kept as entered.
class AppStrings {
  AppStrings(this.languageCode);

  final String languageCode;

  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context).languageCode);

  bool get isFrench => languageCode == 'fr';

  String text(String english) =>
      isFrench ? (_french[english] ?? english) : english;

  String error(Object error) {
    final message = error.toString();
    if (!isFrench) return message;
    if (_french.containsKey(message)) return text(message);
    for (final rule in [
      'An object data format needs a title field',
      'Give this object a name',
      'Object model not found',
      'Object not found',
      'Existing entries need titles before becoming objects',
      'Review existing entries before converting them to objects',
      'Choose a text field in a regular data format in this collection',
      'This object is used in entries. Remove those links first',
    ]) {
      if (message.contains(rule)) return text(rule);
    }
    if (message.contains('Choose a light data format color') ||
        message.contains('Choose a light format color')) {
      return text('Choose a color for this data format.');
    }
    if (message.contains('Each data format needs a different color') ||
        message.contains('Each format needs a different color')) {
      return text('Each data format needs a different color');
    }
    if (message.contains('Data format changed')) {
      return text('This data format changed. Refresh and try again.');
    }
    if (message.contains('has saved values')) {
      return text(
        'A field with saved values cannot be removed or change its type, unit or choices.',
      );
    }
    if (message.contains('Choice fields need')) {
      return text('Add 2 to 30 different choices.');
    }
    if (message.contains('needs a duration')) {
      return text('Enter a duration as hours:minutes.');
    }
    if (message.contains('file is too large') ||
        message.contains('Attachments in one entry')) {
      return text(
        'Choose a file smaller than 2 MB. An entry can hold at most 8 MB of files.',
      );
    }
    if (message.contains('needs one of its choices') ||
        message.contains('needs valid choices')) {
      return text('Choose one of the available options.');
    }
    if (message.contains('must be yes or no')) {
      return text('Choose yes or no.');
    }
    if (message.contains('needs a valid file') ||
        message.contains('needs a file')) {
      return text('Choose a valid file.');
    }
    if (message.contains('Attachment not found')) {
      return text('This file is no longer available.');
    }
    if (message.contains('Add at least one interest or hobby')) {
      return text('Add at least one interest or hobby.');
    }
    if (message.contains('Profile photo must be at most')) {
      return text('This photo can’t be reduced below 1 MB. Choose a smaller one.');
    }
    if (message.contains('Profile photo must be a')) {
      return text('This image can’t be read. Choose a JPEG, PNG or WebP photo.');
    }
    if (message.contains('can have at most 12 items') ||
        message.contains('items must be at most 60 characters')) {
      return text(
        'Keep up to 12 interests or hobbies, with 60 characters per item.',
      );
    }
    if (message.contains('items must be unique')) {
      return text('Remove repeated interests or hobbies.');
    }
    if (message.contains('Could not reach Brainy')) {
      return text(
        'Could not reach Brainy. Check your connection and try again.',
      );
    }
    if (message.contains('temporarily unavailable')) {
      return text('Brainy is temporarily unavailable. Please try again.');
    }
    if (message.contains('Incorrect email or password')) {
      return text('Incorrect email or password');
    }
    if (message.contains('account with this email already exists')) {
      return text('An account with this email already exists');
    }
    if (message.contains('Invalid or expired session') ||
        message.contains('Sign in to continue')) {
      return text('Sign in to continue.');
    }
    if (message.contains('must be a number')) {
      return text('Enter a valid number.');
    }
    if (message.contains('must be a valid date')) {
      return text('Enter a valid date.');
    }
    if (message.contains('must be a valid time')) {
      return text('Enter a valid time.');
    }
    if (message.contains('must be a web link')) {
      return text('Enter a valid web link.');
    }
    if (message.contains('must be one character')) {
      return text('Enter one character.');
    }
    if (message.contains('Collection not found') ||
        message.contains('Entry not found')) {
      return text('This item is no longer available. Refresh and try again.');
    }
    if (message.contains('Data format names must be unique') ||
        message.contains('Format names must be unique')) {
      return text('Data format names must be unique.');
    }
    if (message.contains('Data format name must be') ||
        message.contains('Format name must be')) {
      return text('Name the data format.');
    }
    if (message.contains('at most 24 data formats') ||
        message.contains('between 1 and 24 data formats')) {
      return text('A collection can have up to 24 data formats.');
    }
    debugPrint('Brainy error: $message');
    // A refusal from the API says what to fix, so it must not be hidden.
    if (error is AuthApiException) return 'Une erreur est survenue : $message';
    return text('Something went wrong. Please try again.');
  }

  static const Map<String, String> _french = {
    'An object data format needs a title field':
        'Un format de données d’objet a besoin d’un champ titre.',
    'Give this object a name': 'Donnez un nom à cet objet.',
    'Object model not found': 'Ce modèle d’objet est introuvable.',
    'Object not found': 'Cet objet est introuvable.',
    'Existing entries need titles before becoming objects':
        'Nommez les entrées existantes avant de les utiliser comme objets.',
    'Review existing entries before converting them to objects':
        'Examinez les entrées existantes avant de les convertir en objets.',
    'Choose a text field in a regular data format in this collection': 'Choisissez un champ texte dans un format de données ordinaire de cette collection.',
    'This object is used in entries. Remove those links first': 'Cet objet est utilisé dans des entrées. Retirez ces liens avant de le supprimer.',
    'A space for every thought': 'Un espace pour chaque idée',
    'YOUR CREATIVE SPACE': 'VOTRE ESPACE CRÉATIF',
    'Make room for ideas.': 'Faites place aux idées.',
    'Welcome back.': 'Heureux de vous revoir.',
    'Create your account and start collecting every spark.':
        'Créez votre compte et gardez toutes vos idées.',
    'Your notes, sketches, and big ideas are waiting.':
        'Vos notes, croquis et grandes idées vous attendent.',
    'Your name': 'Votre nom',
    'What should we call you?': 'Comment vous appelez-vous ?',
    'Enter your name': 'Saisissez votre nom',
    'Email address': 'Adresse e-mail',
    'Enter a valid email address': 'Saisissez une adresse e-mail valide',
    'Password': 'Mot de passe',
    'At least 8 characters': 'Au moins 8 caractères',
    'Enter your password': 'Votre mot de passe',
    'Hide password': 'Masquer le mot de passe',
    'Show password': 'Afficher le mot de passe',
    'Use at least 8 characters': 'Utilisez au moins 8 caractères',
    'Confirm password': 'Confirmer le mot de passe',
    'Repeat your password': 'Répétez votre mot de passe',
    'Passwords do not match': 'Les mots de passe ne correspondent pas',
    'Create account': 'Créer un compte',
    'Sign in': 'Se connecter',
    'OR': 'OU',
    'Continue with Google': 'Continuer avec Google',
    'Preparing Google sign-in…': 'Préparation de la connexion Google…',
    'Google sign-in is unavailable. Try reloading.':
        'La connexion Google est indisponible. Actualisez la page.',
    'Already have an account? ': 'Vous avez déjà un compte ? ',
    'New to Brainy? ': 'Nouveau sur Brainy ? ',
    'Create an account': 'Créer un compte',
    'Your ideas stay with your account, wherever you sign in.':
        'Vos idées restent liées à votre compte, sur tous vos appareils.',
    'YOUR IDEAS, EVERYWHERE': 'VOS IDÉES, PARTOUT',
    'A little space for\nbig thoughts.':
        'Un petit espace pour\nde grandes idées.',
    'Capture a passing thought. Draw out a new idea. Pick up where you left off, on any device.': 'Notez une pensée, développez une idée et reprenez sur n’importe quel appareil.',
    'The next big idea': 'La prochaine grande idée',
    'It starts with one small thought...':
        'Tout commence par une petite pensée…',
    'IDEAS': 'IDÉES',
    'TODAY': 'AUJOURD’HUI',
    'One account. Every device.': 'Un compte. Tous vos appareils.',
    'Something went wrong. Please try again.':
        'Une erreur est survenue. Réessayez.',
    'Google sign-in failed. Please try again.':
        'La connexion Google a échoué. Réessayez.',
    'Could not reach Brainy. Check your connection and try again.':
        'Connexion à Brainy impossible. Vérifiez votre connexion et réessayez.',
    'Brainy is temporarily unavailable. Please try again.':
        'Brainy est temporairement indisponible. Réessayez.',
    'Incorrect email or password': 'Adresse e-mail ou mot de passe incorrect',
    'An account with this email already exists':
        'Un compte utilise déjà cette adresse e-mail',
    'Sign in to continue.': 'Connectez-vous pour continuer.',
    'Enter a valid number.': 'Saisissez un nombre valide.',
    'Enter a valid date.': 'Saisissez une date valide.',
    'Enter a valid time.': 'Saisissez une heure valide.',
    'Enter a valid web link.': 'Saisissez un lien web valide.',
    'Enter one character.': 'Saisissez un seul caractère.',
    'This item is no longer available. Refresh and try again.':
        'Cet élément n’est plus disponible. Actualisez et réessayez.',
    'Your workspace': 'Votre espace',
    'Save information in your own data format.': 'Enregistrez vos informations dans le format de données qui vous convient.',
    'Your data, your way': 'Vos données, à votre façon',
    'A home for your thoughts': 'Un espace pour vos idées',
    'Account': 'Compte',
    'Sign out': 'Se déconnecter',
    'COLLECTIONS': 'COLLECTIONS',
    'New collection': 'Nouvelle collection',
    'Collection': 'Collection',
    'Try again': 'Réessayer',
    'Start with a collection. Give it a name and choose the fields you want to keep.': 'Commencez par une collection. Donnez-lui un nom et choisissez les champs à conserver.',
    'Create collection': 'Créer la collection',
    'New entry': 'Nouvelle entrée',
    'Saved entries': 'Entrées enregistrées',
    'Close': 'Fermer',
    'The server sent an unexpected response.': 'Le serveur a envoyé une réponse inattendue.',
    'Entries': 'Entrées',
    'Data formats': 'Formats de données',
    'Search entries': 'Rechercher des entrées',
    'All data formats': 'Tous les formats de données',
    'Filter by field': 'Filtrer par champ',
    'No field filter': 'Aucun filtre de champ',
    'Filter value': 'Valeur du filtre',
    'Equals': 'Égal à',
    'Contains': 'Contient',
    'Greater than': 'Supérieur à',
    'Less than': 'Inférieur à',
    'Load more entries': 'Afficher plus d’entrées',
    'Import and export': 'Importer et exporter',
    'Export collection': 'Exporter la collection',
    'Brainy backup (JSON)': 'Sauvegarde Brainy (JSON)',
    'Readable table (CSV)': 'Tableau lisible (CSV)',
    'Import collection': 'Importer une collection',
    'Choose a Brainy backup': 'Choisir une sauvegarde Brainy',
    'Create a new collection': 'Créer une nouvelle collection',
    'Add to this collection': 'Ajouter à cette collection',
    'Field mapping': 'Correspondance des champs',
    'Importing again skips entries already copied.':
        'Un nouvel import ignore les entrées déjà copiées.',
    'Import entries': 'Importer les entrées',
    'Import complete': 'Import terminé',
    'created': 'créées',
    'skipped': 'ignorées',
    'Invalid Brainy backup': 'Sauvegarde Brainy invalide',
    'Invalid collection': 'Collection invalide',
    'Invalid data format': 'Format de données invalide',
    'Invalid field': 'Champ invalide',
    'Invalid entry': 'Entrée invalide',
    'Invalid entry value': 'Valeur d’entrée invalide',
    'Units and conversions': 'Unités et conversions',
    'Units in this collection': 'Unités de cette collection',
    'New unit': 'Nouvelle unité',
    'Unit name': 'Nom de l’unité',
    'Symbol': 'Symbole',
    'Dimension': 'Grandeur',
    'Base unit': 'Unité de base',
    'No base unit': 'Aucune unité de base',
    'Factor': 'Facteur',
    'One carton of 12 bottles has factor 12.':
        'Un carton de 12 bouteilles a le facteur 12.',
    'Object data format': 'Format de données d’objet',
    'Any item': 'Tout article',
    'Save unit': 'Enregistrer l’unité',
    'Convert': 'Convertir',
    'Amount': 'Quantité',
    'From': 'De',
    'To': 'Vers',
    'As of': 'À la date du',
    'Exchange rate': 'Taux de change',
    'Currency rates are dated and do not change older entries.': 'Les taux de change ont une date et ne modifient pas les anciennes entrées.',
    'Rate': 'Taux',
    'Save rate': 'Enregistrer le taux',
    'Exchange rate saved': 'Taux de change enregistré',
    'Loading...': 'Chargement…',
    'Collection data format': 'Format de données de la collection',
    'Collection data formats': 'Formats de données de la collection',
    'Data format': 'Format de données',
    'Data format name': 'Nom du format de données',
    'Data format color': 'Couleur du format de données',
    'Change color': 'Changer la couleur',
    'Share by link': 'Partager par lien',
    'Review updates': 'Voir les mises à jour',
    'View': 'Vue',
    'Default list': 'Liste par défaut',
    'Save a view': 'Enregistrer une vue',
    'Edit view': 'Modifier la vue',
    'Delete view': 'Supprimer la vue',
    'Action': 'Action',
    'Color': 'Couleur',
    'Choose a color for this data format.':
        'Choisissez une couleur pour ce format de données.',
    'Every entry in this data format uses this soft background.':
        'Chaque entrée de ce format de données aura ce fond très clair.',
    'Each data format needs a different color':
        'Chaque format de données doit avoir une couleur différente',
    'Edit profile': 'Modifier le profil',
    'Tell us about yourself': 'Parlez-nous de vous',
    'Tell Brainy about your work and interests. Meeting people with similar interests may be offered later.': 'Décrivez votre activité et vos centres d’intérêt. Une mise en relation pourrait être proposée plus tard.',
    'Your profile is private. Any future sharing will require your choice.':
        'Votre profil est privé. Tout partage futur demandera votre choix.',
    'Profession': 'Profession',
    'Current job or role': 'Emploi ou poste actuel',
    'Field of study': 'Domaine d’études',
    'Interests': 'Centres d’intérêt',
    'Hobbies': 'Loisirs',
    'Optional': 'Facultatif',
    'Separate items with commas': 'Séparez les éléments par des virgules',
    'Profile photo': 'Photo de profil',
    'Choose a photo': 'Choisir une photo',
    'Change photo': 'Changer la photo',
    'Remove photo': 'Retirer la photo',
    'Preparing photo…': 'Préparation de la photo…',
    'JPEG, PNG or WebP. Photos over 1 MB are compressed automatically.':
        'JPEG, PNG ou WebP. Les photos de plus de 1 Mo sont compressées automatiquement.',
    'Photo compressed to {size} to fit the 1 MB limit.':
        'Photo compressée à {size} pour respecter la limite de 1 Mo.',
    'This image can’t be read. Choose a JPEG, PNG or WebP photo.':
        'Cette image est illisible. Choisissez une photo JPEG, PNG ou WebP.',
    'This photo can’t be reduced below 1 MB. Choose a smaller one.':
        'Cette photo ne peut pas descendre sous 1 Mo. Choisissez-en une plus petite.',
    'Choose from the list or type your own.':
        'Choisissez dans la liste ou saisissez votre propre réponse.',
    'Choose from the list or type your own. A comma adds exactly what you typed.':
        'Choisissez dans la liste ou saisissez votre propre réponse. Une virgule ajoute exactement votre saisie.',
    'Add “{value}”': 'Ajouter « {value} »',
    'Remove {item}': 'Retirer {item}',
    'Search or type…': 'Rechercher ou saisir…',
    'Add at least one interest or hobby.':
        'Ajoutez au moins un centre d’intérêt ou un loisir.',
    'Add at least one interest or hobby':
        'Ajoutez au moins un centre d’intérêt ou un loisir',
    'Keep up to 12 interests or hobbies, with 60 characters per item.': 'Gardez au plus 12 centres d’intérêt ou loisirs, avec 60 caractères par élément.',
    'Remove repeated interests or hobbies.':
        'Supprimez les centres d’intérêt ou loisirs répétés.',
    'Save profile': 'Enregistrer le profil',
    'Continue to workspace': 'Continuer vers l’espace',
    'General': 'Général',
    'Add data format': 'Ajouter un format de données',
    'data format': 'format de données',
    'data formats': 'formats de données',
    'Give this data format a name and choose its fields.':
        'Donnez un nom à ce format de données et choisissez ses champs.',
    'Data format names must be unique.':
        'Les noms des formats de données doivent être différents.',
    'Name the data format.': 'Nommez le format de données.',
    'A collection can have up to 24 data formats.':
        'Une collection peut contenir jusqu’à 24 formats de données.',
    'Collection actions': 'Actions de la collection',
    'Created': 'Créée le',
    'Edited': 'Modifiée le',
    'Copy entry': 'Copier l’entrée',
    'Copied to clipboard': 'Entrée copiée dans le presse-papiers',
    'Rename': 'Renommer',
    'Delete collection': 'Supprimer la collection',
    'Nothing written yet': 'Aucune entrée pour le moment',
    'Add an entry using the fields in this collection.':
        'Ajoutez une entrée avec les champs de cette collection.',
    'Write an entry': 'Écrire une entrée',
    'Entry': 'Entrée',
    'Entry actions': 'Actions de l’entrée',
    'Edit': 'Modifier',
    'Delete': 'Supprimer',
    'Empty entry': 'Entrée vide',
    'Updated': 'Modifié le',
    'field': 'champ',
    'fields': 'champs',
    'entry': 'entrée',
    'entries': 'entrées',
    'Title': 'Titre',
    'Date': 'Date',
    'Number': 'Nombre',
    'Measure': 'Mesure',
    'Code from a list': 'Code d’une liste',
    'Position': 'Position',
    'Zone': 'Zone',
    'Time': 'Heure',
    'Link': 'Lien',
    'Character': 'Caractère',
    'Text': 'Texte',
    'Long text': 'Texte long',
    'Yes or no': 'Oui ou non',
    'Single choice': 'Choix unique',
    'Multiple choices': 'Choix multiples',
    'Date and time': 'Date et heure',
    'Duration': 'Durée',
    'Attachment': 'Pièce jointe',
    'Object reference': 'Référence d’objet',
    'Choose a file': 'Choisir un fichier',
    'Remove file': 'Retirer le fichier',
    'File saved': 'Fichier enregistré',
    'Choose one of the available options.':
        'Choisissez parmi les options disponibles.',
    'Choose yes or no.': 'Choisissez oui ou non.',
    'Choose a valid file.': 'Choisissez un fichier valide.',
    'This file is no longer available.': 'Ce fichier n’est plus disponible.',
    'Wait for the file upload to finish.': 'Attendez la fin de l’envoi du fichier.',
    'Choose a file smaller than 2 MB. An entry can hold at most 8 MB of files.': 'Choisissez un fichier de moins de 2 Mo. Une entrée peut contenir au plus 8 Mo de fichiers.',
    'Yes': 'Oui',
    'No': 'Non',
    'Choose a value': 'Choisissez une valeur',
    'Edit data format': 'Modifier le format de données',
    'Rename, reorder or add fields. Saved values stay safe.': 'Renommez, réorganisez ou ajoutez des champs. Les valeurs enregistrées restent protégées.',
    'Entries using this data format': 'Entrées utilisant ce format de données',
    'Choices (one per line)': 'Choix (un par ligne)',
    'Add 2 to 30 different choices.': 'Ajoutez de 2 à 30 choix différents.',
    'Move up': 'Monter',
    'Move down': 'Descendre',
    'Enter a duration as hours:minutes.':
        'Saisissez une durée en heures:minutes.',
    'This data format changed. Refresh and try again.':
        'Ce format de données a changé. Actualisez et réessayez.',
    'A field with saved values cannot be removed or change its type, unit or choices.': 'Un champ déjà renseigné ne peut être supprimé ni changer de type, d’unité ou de choix.',
    'Delete entry?': 'Supprimer cette entrée ?',
    'This entry will be removed permanently.':
        'Cette entrée sera supprimée définitivement.',
    'Cancel': 'Annuler',
    'Rename collection': 'Renommer la collection',
    'Collection name': 'Nom de la collection',
    'Save': 'Enregistrer',
    'The collection and every entry in it will be removed permanently.':
        'La collection et toutes ses entrées seront supprimées définitivement.',
    'Create a collection': 'Créer une collection',
    'Choose what each entry can hold. Keep one field or mix several types.': 'Choisissez les données à conserver. Utilisez un seul champ ou combinez plusieurs types.',
    'Ideas, recipes, contacts…': 'Idées, recettes, contacts…',
    'FIELDS': 'CHAMPS',
    'Field': 'Champ',
    'Type': 'Type',
    'Remove field': 'Supprimer le champ',
    'Add field': 'Ajouter un champ',
    'Creating…': 'Création…',
    'Name the collection and every field.':
        'Nommez la collection et chaque champ.',
    'Field names must be unique.':
        'Les noms des champs doivent être différents.',
    'Edit entry': 'Modifier l’entrée',
    'Write something before saving.':
        'Écrivez quelque chose avant d’enregistrer.',
    'One character': 'Un seul caractère',
    'Save entry': 'Enregistrer l’entrée',
    'Saving…': 'Enregistrement…',
    'must contain one character.': 'doit contenir un seul caractère.',
    'must be a full web link, starting with https://.':
        'doit être un lien web complet commençant par https://.',
    'Unit': 'Unité',
    'No unit': 'Sans unité',
    'Custom unit': 'Unité personnalisée',
    'Enter a unit': 'Saisissez une unité',
    'Choose a unit or leave the number plain.':
        'Choisissez une unité ou gardez un nombre simple.',
    'Distance': 'Distance',
    'Mass': 'Masse',
    'Volume': 'Volume',
    'Temperature': 'Température',
    'Money': 'Monnaie',
    'Other': 'Autres',
    'Kilometres': 'Kilomètres',
    'Metres': 'Mètres',
    'Centimetres': 'Centimètres',
    'Millimetres': 'Millimètres',
    'Miles': 'Miles',
    'Feet': 'Pieds',
    'Inches': 'Pouces',
    'Kilograms': 'Kilogrammes',
    'Grams': 'Grammes',
    'Pounds': 'Livres',
    'Litres': 'Litres',
    'Millilitres': 'Millilitres',
    'Celsius': 'Celsius',
    'Fahrenheit': 'Fahrenheit',
    'Euro': 'Euro',
    'US dollar': 'Dollar américain',
    'British pound': 'Livre sterling',
    'Nigerian naira': 'Naira nigérian',
    'CFA franc': 'Franc CFA',
    'Percent': 'Pourcentage',
    'Hours': 'Heures',
    'Minutes': 'Minutes',
    'Seconds': 'Secondes',
    'A unit can be at most 24 characters.':
        'Une unité ne peut pas dépasser 24 caractères.',
    'Number example': 'Ex. 12.5',
    'Number example French': 'Ex. 12,5',
  };
}

class LanguageMenu extends StatelessWidget {
  const LanguageMenu({
    super.key,
    this.onChanged,
    this.onDark = false,
    this.fullName = false,
  });

  final ValueChanged<String>? onChanged;
  final bool onDark;

  /// Shows "English" rather than "EN", as on the web's desktop bar.
  final bool fullName;

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final color = onDark
        ? Colors.white
        : fullName
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD6E4FA)
        : const Color(0xFF24456F);
    return PopupMenuButton<String>(
      tooltip: code == 'fr' ? 'Langue' : 'Language',
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'fr', child: Text('Français')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_rounded, size: 17, color: color),
            const SizedBox(width: 5),
            Text(
              fullName
                  ? (code == 'fr' ? 'Français' : 'English')
                  : code.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: fullName ? 14 : 12,
                fontWeight: fullName ? FontWeight.w600 : FontWeight.w800,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
