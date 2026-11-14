// T50: five-page welcome guide shown once after sign-up. Illustrations are small Brainy UI mock-ups.
import 'format_color_names.dart';
import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'brand_assets.dart';
import 'collections_api.dart';
import 'data_format_colors.dart';
import 'design_tokens.dart';

extension OnboardingApi on AuthApi {
  Future<AppUser> setOnboardingCompleted(bool completed) async {
    final data = await authenticatedRequest('mutation(\$done:Boolean!){setOnboardingCompleted(completed:\$done){${AuthApi.userFields}}}', {'done': completed});
    return AppUser.fromJson(data['setOnboardingCompleted'] as Map<String, dynamic>);
  }
}

/// `created` is the first collection when the person made one; `openTemplates` asks for the template chooser.
typedef OnboardingFinished = void Function(AppUser user, {bool created, bool openTemplates});

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.user, required this.api, required this.onFinished, this.initialPage = 0});
  /// For previews: the page to open first (0 to 4).
  final int initialPage;
  final AppUser user;
  final AuthApi api;
  final OnboardingFinished onFinished;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late int page = widget.initialPage.clamp(0, 4);
  final collectionName = TextEditingController();
  final formatName = TextEditingController();
  final entryTitle = TextEditingController();
  String color = brainyFormatColors.first;
  bool withDate = true;
  bool busy = false;
  String error = '';

  bool get fr => Localizations.localeOf(context).languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    for (final controller in [collectionName, formatName, entryTitle]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    collectionName.dispose();
    formatName.dispose();
    entryTitle.dispose();
    super.dispose();
  }

  Future<void> _skip({bool openTemplates = false}) async {
    setState(() { busy = true; error = ''; });
    try {
      widget.onFinished(await widget.api.setOnboardingCompleted(true), openTemplates: openTemplates);
    } catch (cause) {
      if (mounted) setState(() { busy = false; error = cause.toString(); });
    }
  }

  Future<void> _create() async {
    if (collectionName.text.trim().isEmpty || formatName.text.trim().isEmpty || entryTitle.text.trim().isEmpty) {
      setState(() => error = fr ? 'Remplissez les trois étapes pour créer votre collection.' : 'Fill in the three steps to create your collection.');
      return;
    }
    setState(() { busy = true; error = ''; });
    try {
      final api = CollectionsApi(widget.api);
      final collection = await api.createCollection(
        collectionName.text.trim(),
        [(name: fr ? 'Titre' : 'Title', kind: BrainyFieldKind.title, unit: null, options: null), if (withDate) (name: 'Date', kind: BrainyFieldKind.date, unit: null, options: null)],
        formatName: formatName.text.trim(),
        color: color,
      );
      final format = collection.formats.first;
      final now = DateTime.now();
      await api.saveEntry(collection.id, {
        format.fields.first.id: entryTitle.text.trim(),
        if (withDate) format.fields[1].id: '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      }, formatId: format.id);
      widget.onFinished(await widget.api.setOnboardingCompleted(true), created: true);
    } catch (cause) {
      if (mounted) setState(() { busy = false; error = cause.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme, dark = theme.brightness == Brightness.dark;
    final firstName = widget.user.name.split(' ').first;
    final pages = <({String kicker, String title, Widget art, Widget body})>[
      (kicker: fr ? 'Bienvenue' : 'Welcome', title: fr ? 'Bonjour $firstName, voici Brainy' : 'Hello $firstName, meet Brainy', art: _WelcomeArt(fr: fr), body: _welcomeBody()),
      (kicker: fr ? 'La langue de Brainy' : 'Brainy’s words', title: fr ? 'Trois mots suffisent' : 'Three words are enough', art: _LanguageArt(fr: fr), body: _languageBody()),
      (kicker: fr ? 'Au quotidien' : 'Every day', title: fr ? 'Brainy vous aide chaque jour' : 'Brainy helps you every day', art: _DailyArt(fr: fr), body: _dailyBody()),
      (kicker: fr ? 'Vos données' : 'Your data', title: fr ? 'Privées, toujours à votre main' : 'Private, always in your hands', art: _PrivacyArt(fr: fr), body: _privacyBody()),
      (kicker: fr ? 'À vous de jouer' : 'Your turn', title: fr ? 'Créons votre première collection' : 'Let’s create your first collection', art: _preview(), body: _wizard()),
    ];
    final current = pages[page];
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${current.kicker.toUpperCase()} · ${page + 1}/5', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .8, fontSize: 13, color: dark ? const Color(0xFFCDB8FF) : const Color(0xFF6944A8))),
      const SizedBox(height: 10),
      Semantics(header: true, child: Text(current.title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15))),
      const SizedBox(height: 16),
      current.body,
      if (error.isNotEmpty && page < 4) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: TextStyle(color: scheme.error))),
    ]);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final card = Material(
            color: dark ? BrainyColors.darkSurface : BrainyColors.lightSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(wide ? 24 : 18), side: BorderSide(color: dark ? BrainyColors.darkLine : BrainyColors.lightLine)),
            child: Padding(
            padding: EdgeInsets.all(wide ? 36 : 18),
            child: AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 240),
              child: KeyedSubtree(
                key: ValueKey(page),
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: Center(child: current.art)), const SizedBox(width: 40), Expanded(child: text)])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [current.art, const SizedBox(height: 20), text]),
              ),
            ),
            ),
          );
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                const BrainyMark(size: 34),
                const SizedBox(width: 8),
                if (wide) Text('brainy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: scheme.onSurface)),
                Expanded(child: Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : _skip, child: Text(fr ? 'Passer le guide' : 'Skip the guide', maxLines: 1, overflow: TextOverflow.ellipsis)))),
              ]),
            ),
            Expanded(child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 16, vertical: 12), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1120), child: card)))),
            Padding(
              padding: EdgeInsets.fromLTRB(wide ? 48 : 16, 4, wide ? 48 : 16, 12),
              child: Row(children: [
                if (wide) OutlinedButton.icon(onPressed: page == 0 || busy ? null : () => setState(() => page--), icon: const Icon(Icons.arrow_back, size: 18), label: Text(fr ? 'Retour' : 'Back'))
                else IconButton.outlined(tooltip: fr ? 'Retour' : 'Back', onPressed: page == 0 || busy ? null : () => setState(() => page--), icon: const Icon(Icons.arrow_back)),
                Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var index = 0; index < 5; index++)
                    Semantics(
                      button: true,
                      selected: index == page,
                      label: 'Page ${index + 1}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => setState(() => page = index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 18),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: index == page ? 26 : 10, height: 10, decoration: BoxDecoration(color: index == page ? scheme.primary : scheme.outlineVariant, borderRadius: BorderRadius.circular(99))),
                        ),
                      ),
                    ),
                ])),
                if (page < 4) Flexible(child: Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => setState(() => page++), iconAlignment: IconAlignment.end, icon: const Icon(Icons.arrow_forward, size: 18), label: Text(fr ? 'Suivant' : 'Next', maxLines: 1, overflow: TextOverflow.ellipsis)))) else SizedBox(width: wide ? 88 : 48),
              ]),
            ),
          ]);
        }),
      ),
    );
  }

  TextStyle get _muted => TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5, fontSize: 15);

  Widget _welcomeBody() {
    final scheme = Theme.of(context).colorScheme;
    final verbs = fr ? [('Notez', 'ce qui compte'), ('Rangez', 'comme vous voulez'), ('Retrouvez', 'en un instant')] : [('Write down', 'what matters'), ('Organize', 'the way you like'), ('Find', 'in a moment')];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fr ? 'Votre carnet personnel, organisé à votre façon, sur téléphone, ordinateur et web.' : 'Your personal notebook, organized your way, on phone, computer and web.', style: const TextStyle(fontSize: 18, height: 1.45)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (verb, detail) in verbs)
          Container(width: 150, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: .6), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(verb, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text(detail, style: _muted.copyWith(fontSize: 14))])),
      ]),
    ]);
  }

  Widget _number(int value) => Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle), child: Text('$value', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 13)));

  Widget _languageBody() {
    final scheme = Theme.of(context).colorScheme;
    final words = fr
        ? [('Collection', 'Un grand classeur : Maison, Travail, Santé…'), ('Format de données', 'Le modèle de vos fiches : leurs champs et leur couleur.'), ('Entrée', 'Une fiche remplie, comme « Pain, 500 FCFA ».')]
        : [('Collection', 'A big binder: Home, Work, Health…'), ('Data format', 'The template of your cards: their fields and color.'), ('Entry', 'A filled-in card, like “Bread, €2.50”.')];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var index = 0; index < words.length; index++)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [_number(index + 1), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(words[index].$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text(words[index].$2, style: _muted)]))])),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: .55), borderRadius: BorderRadius.circular(12)),
        child: Text(fr ? 'Vous décidez de la structure. Commencez avec un seul champ : tout reste modifiable.' : 'You decide the structure. Start with one field: everything stays editable.', style: TextStyle(color: scheme.onPrimaryContainer, height: 1.45)),
      ),
    ]);
  }

  Widget _dailyBody() {
    final scheme = Theme.of(context).colorScheme;
    final uses = fr
        ? [(Icons.check_box_outlined, 'Cochez vos tâches du jour, uniques ou qui reviennent.'), (Icons.account_balance_wallet_outlined, 'Suivez vos dépenses et vos totaux de la semaine.'), (Icons.link, 'Gardez liens, idées et notes au même endroit.'), (Icons.dashboard_customize_outlined, 'Partez d’un modèle prêt : tâches, agenda, livre, sport…')]
        : [(Icons.check_box_outlined, 'Check off today’s tasks, one-off or repeating.'), (Icons.account_balance_wallet_outlined, 'Track your spending and weekly totals.'), (Icons.link, 'Keep links, ideas and notes in one place.'), (Icons.dashboard_customize_outlined, 'Start from a ready template: tasks, calendar, book, sport…')];
    return Column(children: [for (final (icon, label) in uses) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(icon, color: scheme.primary), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontSize: 16, height: 1.4)))]))]);
  }

  Widget _privacyBody() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final purple = dark ? const Color(0xFFCDB8FF) : const Color(0xFF6944A8);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fr ? 'Ce que vous enregistrez est privé : personne d’autre ne le voit. Vous partagez seulement quand vous le choisissez, en invitant quelqu’un ou en exportant.' : 'What you save is private: nobody else sees it. You share only when you choose, by inviting someone or exporting.', style: _muted.copyWith(fontSize: 16)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: purple.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: purple.withValues(alpha: .3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: purple.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)), child: Text(fr ? 'Notre vision à long terme' : 'Our long-term vision', style: TextStyle(color: purple, fontWeight: FontWeight.w700, fontSize: 12))),
          const SizedBox(height: 8),
          Text(fr ? 'Faire de Brainy un outil capable de traiter des données à l’échelle industrielle et d’aider aux études scientifiques, mathématiques et statistiques, sur des données de tous types et de tous domaines : santé, agriculture, météo, commerce, éducation…' : 'Make Brainy able to handle data at industrial scale and to support scientific, mathematical and statistical studies on data of every type and field: health, farming, weather, trade, education…', style: const TextStyle(height: 1.45, fontSize: 15)),
          const SizedBox(height: 6),
          Text(fr ? 'Les calculs, graphiques et prévisions existent déjà ; le reste arrive peu à peu. Vos données ne deviendront publiques que si vous le décidez.' : 'Totals, charts and forecasts already exist; the rest is coming step by step. Your data becomes public only if you decide so.', style: _muted.copyWith(fontSize: 14)),
        ]),
      ),
    ]);
  }

  Widget _wizard() {
    final scheme = Theme.of(context).colorScheme;
    Widget step(int number, String title, List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.outlineVariant)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [_number(number), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)))]), const SizedBox(height: 10), ...children]),
        );
    Widget chips(List<String> items, TextEditingController controller) => Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final item in items) ActionChip(label: Text(item), onPressed: () => controller.text = item)]));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      step(1, fr ? 'Nommez votre collection' : 'Name your collection', [
        TextField(controller: collectionName, maxLength: 80, decoration: InputDecoration(border: const OutlineInputBorder(), labelText: fr ? 'Nom de la collection' : 'Collection name', hintText: fr ? 'Par exemple : Maison' : 'For example: Home', counterText: '')),
        chips(fr ? ['Maison', 'Travail', 'Études', 'Santé'] : ['Home', 'Work', 'Studies', 'Health'], collectionName),
      ]),
      step(2, fr ? 'Créez un format de données' : 'Create a data format', [
        TextField(controller: formatName, maxLength: 80, decoration: InputDecoration(border: const OutlineInputBorder(), labelText: fr ? 'Nom du format de données' : 'Data format name', hintText: fr ? 'Par exemple : Dépense' : 'For example: Expense', counterText: '')),
        chips(fr ? ['Note', 'Tâche', 'Dépense', 'Idée'] : ['Note', 'Task', 'Expense', 'Idea'], formatName),
        CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: withDate, onChanged: (value) => setState(() => withDate = value ?? false), title: Text(fr ? 'Ajouter un champ Date en plus du Titre' : 'Add a Date field next to the Title')),
        Text(fr ? 'Couleur' : 'Color', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(formatColorName(color, french: fr), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final option in brainyFormatColors)
            Tooltip(message: formatColorName(option, french: fr), child: Semantics(
              button: true,
              selected: option == color,
              label: '${fr ? 'Couleur' : 'Color'} ${formatColorName(option, french: fr)}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => color = option),
                child: Container(width: 40, height: 40, decoration: BoxDecoration(color: DataFormatColors.surface(option, dark), shape: BoxShape.circle, border: Border.all(color: option == color ? scheme.primary : DataFormatColors.marker(option, dark).withValues(alpha: .4), width: option == color ? 3 : 1)), child: option == color ? Icon(Icons.check, size: 18, color: DataFormatColors.marker(option, dark)) : null),
              ),
            )),
        ]),
      ]),
      step(3, fr ? 'Écrivez votre première entrée' : 'Write your first entry', [
        TextField(controller: entryTitle, maxLength: 200, decoration: InputDecoration(border: const OutlineInputBorder(), labelText: fr ? 'Titre de la première entrée' : 'First entry title', hintText: fr ? 'Par exemple : Pain, 500 FCFA' : 'For example: Bread', counterText: '')),
      ]),
      if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error, style: TextStyle(color: scheme.error))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton(onPressed: busy ? null : _create, child: Text(busy ? (fr ? 'Création…' : 'Creating…') : (fr ? 'Créer et commencer' : 'Create and start'))),
        OutlinedButton.icon(onPressed: busy ? null : () => _skip(openTemplates: true), icon: const Icon(Icons.dashboard_customize_outlined, size: 18), label: Text(fr ? 'Partir d’un modèle' : 'Start from a template')),
      ]),
    ]);
  }

  Widget _preview() => _MockCollection(
        fr: fr,
        name: collectionName.text.trim().isEmpty ? (fr ? 'Ma collection' : 'My collection') : collectionName.text.trim(),
        formats: [(formatName.text.trim().isEmpty ? (fr ? 'Mon format de données' : 'My data format') : formatName.text.trim(), color, [fr ? 'Titre' : 'Title', if (withDate) 'Date'], false)],
        entries: [(entryTitle.text.trim().isEmpty ? (fr ? 'Ma première entrée' : 'My first entry') : entryTitle.text.trim(), withDate ? (fr ? 'aujourd’hui' : 'today') : (fr ? 'à l’instant' : 'just now'), color, false)],
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.color, this.icon, this.label);
  final String color, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: DataFormatColors.surface(color, dark), borderRadius: BorderRadius.circular(14), border: Border.all(color: DataFormatColors.marker(color, dark).withValues(alpha: .25)), boxShadow: dark ? null : const [BoxShadow(color: Color(0x1420242C), blurRadius: 18, offset: Offset(0, 6))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: DataFormatColors.marker(color, dark)), const SizedBox(width: 8), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)))]),
    );
  }
}

class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt({required this.fr});
  final bool fr;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: 260,
          width: 420,
          child: Stack(children: [
            Positioned(top: 10, left: 0, right: 90, child: Align(alignment: Alignment.centerLeft, child: _Pill('#FFF5EB', Icons.check_box_outlined, fr ? 'Arroser les plantes' : 'Water the plants'))),
            Positioned(top: 62, right: 0, left: 120, child: Align(alignment: Alignment.centerRight, child: _Pill('#FFF0F4', Icons.account_balance_wallet_outlined, fr ? 'Pain · 500 FCFA' : 'Bread · €2.50'))),
            Positioned(bottom: 50, left: 16, right: 90, child: Align(alignment: Alignment.centerLeft, child: _Pill('#EDF9F3', Icons.link, fr ? 'Recette de crêpes' : 'Pancake recipe'))),
            Positioned(bottom: 0, right: 24, left: 120, child: Align(alignment: Alignment.centerRight, child: _Pill('#F4F0FF', Icons.menu_book_outlined, fr ? 'Chapitre 1' : 'Chapter 1'))),
            Center(child: Container(width: 84, height: 84, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2454E6), Color(0xFF6944A8)]), borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x552454E6), blurRadius: 30, offset: Offset(0, 14))]), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 34))),
          ]),
        ),
      );
}

typedef _Format = (String name, String color, List<String> fields, bool numbered);
typedef _EntryRow = (String title, String meta, String color, bool numbered);

class _MockCollection extends StatelessWidget {
  const _MockCollection({required this.fr, required this.name, required this.formats, required this.entries, this.numbered = false});
  final bool fr, numbered;
  final String name;
  final List<_Format> formats;
  final List<_EntryRow> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme, dark = theme.brightness == Brightness.dark;
    Widget number(int value) => Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle), child: Text('$value', style: TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w800)));
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: dark ? BrainyColors.darkCanvas : BrainyColors.lightCanvas, borderRadius: BorderRadius.circular(18), border: Border.all(color: dark ? BrainyColors.darkLine : BrainyColors.lightLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(Icons.folder_special_outlined, color: scheme.primary, size: 20), const SizedBox(width: 8), Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))), if (numbered) number(1)]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (index, format) in formats.indexed)
              Expanded(child: Container(
                margin: EdgeInsets.only(right: index < formats.length - 1 ? 8 : 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: DataFormatColors.surface(format.$2, dark), borderRadius: BorderRadius.circular(14), border: Border(top: BorderSide(color: DataFormatColors.marker(format.$2, dark), width: 3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(format.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))), if (format.$4) number(2)]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [for (final field in format.$3) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: scheme.surface.withValues(alpha: .7), borderRadius: BorderRadius.circular(99)), child: Text(field, style: const TextStyle(fontSize: 12)))]),
                ]),
              )),
          ]),
          const SizedBox(height: 10),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: DataFormatColors.surface(entry.$3, dark), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: DataFormatColors.marker(entry.$3, dark), shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(entry.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    Flexible(child: Text(entry.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
                  ]),
                )),
                if (entry.$4) ...[const SizedBox(width: 6), number(3)],
              ]),
            ),
        ]),
      ),
    );
  }
}

class _LanguageArt extends StatelessWidget {
  const _LanguageArt({required this.fr});
  final bool fr;
  @override
  Widget build(BuildContext context) => _MockCollection(
        fr: fr,
        numbered: true,
        name: fr ? 'Maison' : 'Home',
        formats: [
          (fr ? 'Dépense' : 'Expense', '#FFF0F4', [fr ? 'Titre' : 'Title', fr ? 'Montant' : 'Amount', 'Date'], true),
          (fr ? 'Tâche' : 'Task', '#FFF5EB', [fr ? 'Titre' : 'Title', fr ? 'Terminée' : 'Done'], false),
        ],
        entries: [
          (fr ? 'Pain' : 'Bread', fr ? '500 FCFA · aujourd’hui' : '€2.50 · today', '#FFF0F4', true),
          (fr ? 'Électricité' : 'Electricity', fr ? '12 000 FCFA' : '€48', '#FFF0F4', false),
          (fr ? 'Sortir les poubelles' : 'Take out the bins', fr ? 'chaque lundi' : 'every Monday', '#FFF5EB', false),
        ],
      );
}

class _DailyArt extends StatelessWidget {
  const _DailyArt({required this.fr});
  final bool fr;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme, dark = theme.brightness == Brightness.dark;
    Widget tile(String color, IconData icon, String title, Widget content) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: dark ? BrainyColors.darkCanvas : BrainyColors.lightCanvas, borderRadius: BorderRadius.circular(16), border: Border.all(color: dark ? BrainyColors.darkLine : BrainyColors.lightLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: DataFormatColors.surface(color, dark), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: DataFormatColors.marker(color, dark))),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            content,
          ]),
        );
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _TileGrid(
          children: [
            tile('#FFF5EB', Icons.check_box_outlined, fr ? 'Tâches du jour' : 'Today’s tasks', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.check_box, size: 15, color: Colors.green.shade600), const SizedBox(width: 4), Text(fr ? 'Arroser' : 'Water', style: TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: scheme.onSurfaceVariant))]),
              Row(children: [Icon(Icons.check_box_outline_blank, size: 15, color: scheme.onSurfaceVariant), const SizedBox(width: 4), Text(fr ? 'Sport' : 'Workout', style: const TextStyle(fontSize: 12))]),
            ])),
            tile('#FFF0F4', Icons.account_balance_wallet_outlined, fr ? 'Dépenses' : 'Expenses', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fr ? 'Cette semaine' : 'This week', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)), Text(fr ? '12 500 FCFA' : '€52.40', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))])),
            tile('#EDF9F3', Icons.link, fr ? 'Liens et notes' : 'Links and notes', Row(children: [Container(width: 30, height: 30, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF4F0FF), Color(0xFFEEF5FF)]), borderRadius: BorderRadius.circular(8))), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 7, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 5), FractionallySizedBox(widthFactor: .6, child: Container(height: 7, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))))]))])),
            tile('#EEF5FF', Icons.bar_chart, fr ? 'Calculs et graphiques' : 'Totals and charts', SizedBox(height: 40, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final height in [.4, .65, .5, .85, .6, .95]) Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 40 * height, decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .75), borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))))]))),
          ],
        ),
      ),
    );
  }
}

class _PrivacyArt extends StatelessWidget {
  const _PrivacyArt({required this.fr});
  final bool fr;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme, dark = theme.brightness == Brightness.dark;
    const teal = Color(0xFF087C83);
    final levels = fr
        ? [(Icons.lock_outline, 'Privé', 'par défaut, pour vous seul', true), (Icons.group_outlined, 'Partagé', 'avec qui vous invitez', false), (Icons.public, 'Public', 'seulement si vous le décidez', false)]
        : [(Icons.lock_outline, 'Private', 'by default, only you', true), (Icons.group_outlined, 'Shared', 'with people you invite', false), (Icons.public, 'Public', 'only if you decide', false)];
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(children: [
          Container(width: 100, height: 100, decoration: BoxDecoration(color: teal.withValues(alpha: dark ? .25 : .12), borderRadius: BorderRadius.circular(30)), child: Icon(Icons.lock_outline, size: 40, color: dark ? const Color(0xFF7FD6DC) : teal)),
          const SizedBox(height: 16),
          for (final (icon, title, detail, on) in levels)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: on ? teal.withValues(alpha: .1) : (dark ? BrainyColors.darkCanvas : BrainyColors.lightCanvas), borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? teal : (dark ? BrainyColors.darkLine : BrainyColors.lightLine))),
              child: Row(children: [Icon(icon, size: 18, color: on ? (dark ? const Color(0xFF7FD6DC) : teal) : scheme.onSurfaceVariant), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(detail, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))]))]),
            ),
        ]),
      ),
    );
  }
}

/// Two tiles per row, each row as tall as its tallest tile (no fixed height that could cut text).
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var index = 0; index < children.length; index += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: children[index]),
              const SizedBox(width: 10),
              Expanded(child: index + 1 < children.length ? children[index + 1] : const SizedBox.shrink()),
            ])),
          ),
      ]);
}
