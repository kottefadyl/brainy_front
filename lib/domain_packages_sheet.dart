import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'collections_api.dart';
import 'domain_package_api.dart';

/// T45 — install, update, detach and export domain packages. Returns the collection to open after an install.
Future<String?> showDomainPackages(
  BuildContext context, {
  required CollectionsApi api,
  required List<BrainyCollection> collections,
  BrainyCollection? current,
  required String userId,
  required String userName,
  required bool french,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final body = _DomainPackages(
        api: DomainPackageApi(api),
        collections: collections,
        current: current,
        userId: userId,
        userName: userName,
        fr: french,
      );
      return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 600
            ? Dialog.fullscreen(child: SafeArea(child: body))
            : Dialog(
                insetPadding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 820,
                    maxHeight: constraints.maxHeight * 0.88,
                  ),
                  child: body,
                ),
              ),
      );
    },
  );
}

const _newTarget = '__new__';

class _DomainPackages extends StatefulWidget {
  const _DomainPackages({
    required this.api,
    required this.collections,
    required this.current,
    required this.userId,
    required this.userName,
    required this.fr,
  });
  final DomainPackageApi api;
  final List<BrainyCollection> collections;
  final BrainyCollection? current;
  final String userId, userName;
  final bool fr;
  @override
  State<_DomainPackages> createState() => _DomainPackagesState();
}

class _DomainPackagesState extends State<_DomainPackages>
    with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(
    length: widget.current == null ? 2 : 3,
    vsync: this,
  )..addListener(() => setState(() {}));
  final link = TextEditingController();
  final collectionName = TextEditingController();
  List<DomainPackageSummary>? pilots;
  String? source, sourceLabel, error;
  String target = _newTarget;
  DomainPackagePreview? preview;
  bool previewing = false, busy = false;
  int request = 0;

  String t(String en, String fr) => widget.fr ? fr : en;
  String get language => widget.fr ? 'fr' : 'en';
  bool get managing => tabs.index == 2;

  @override
  void initState() {
    super.initState();
    widget.api
        .pilots(language)
        .then((items) {
          if (mounted) setState(() => pilots = items);
        })
        .catchError((Object cause) {
          if (mounted) {
            setState(() {
              pilots = [];
              error = '$cause';
            });
          }
        });
  }

  @override
  void dispose() {
    tabs.dispose();
    link.dispose();
    collectionName.dispose();
    super.dispose();
  }

  Future<void> refreshPreview() async {
    final json = source;
    if (json == null) return;
    final ticket = ++request;
    setState(() {
      previewing = true;
      error = null;
    });
    try {
      final result = await widget.api.preview(
        json,
        language,
        collectionId: target == _newTarget ? null : target,
      );
      if (!mounted || ticket != request) return;
      setState(() {
        preview = result;
        if (collectionName.text.isEmpty) collectionName.text = result.name;
      });
    } catch (cause) {
      if (mounted && ticket == request) {
        setState(() {
          preview = null;
          error = '$cause';
        });
      }
    } finally {
      if (mounted && ticket == request) setState(() => previewing = false);
    }
  }

  void choose(String json, String label) {
    setState(() {
      source = json;
      sourceLabel = label;
      preview = null;
      collectionName.clear();
    });
    refreshPreview();
  }

  Future<void> pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxDomainPackageBytes) {
      setState(
        () => error = t(
          'This file is larger than 512 KiB.',
          'Ce fichier dépasse 512 Kio.',
        ),
      );
      return;
    }
    choose(utf8.decode(bytes), file.name);
  }

  Future<void> readLink() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      choose(
        await DomainPackageApi.fetchLink(link.text),
        Uri.parse(link.text.trim()).host,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'This link could not be read. Use a complete https link to a package file, or save the file and import it.',
            'Ce lien n’a pas pu être lu. Utilisez un lien https complet vers un fichier de paquet, ou enregistrez le fichier puis importez-le.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> install() async {
    if (source == null || preview?.allowed != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await widget.api.install(
        source!,
        language,
        collectionId: target == _newTarget ? null : target,
        collectionName: target == _newTarget
            ? collectionName.text.trim()
            : null,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owned = widget.collections
        .where((item) => item.ownerId == null || item.ownerId == widget.userId)
        .toList();
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t('Domain packages', 'Paquets de domaine'),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: t('Close', 'Fermer'),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        TabBar(
          controller: tabs,
          isScrollable: false,
          tabs: [
            Tab(text: t('Library', 'Bibliothèque')),
            Tab(text: t('Import', 'Importer')),
            if (widget.current != null) Tab(text: t('Manage', 'Gérer')),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              if (!managing)
                Text(
                  t(
                    'A package copies data formats, units, code lists, views and formulas into a collection. It never contains code or anyone’s entries, and your copy stays yours to change.',
                    'Un paquet copie des formats de données, unités, listes de codes, vues et formules dans une collection. Il ne contient jamais de code ni les entrées de quiconque, et votre copie reste modifiable.',
                  ),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              const SizedBox(height: 12),
              if (tabs.index == 0) _library(scheme),
              if (tabs.index == 1) _import(),
              if (managing)
                _ManagePanel(
                  api: widget.api,
                  collection: widget.current!,
                  userName: widget.userName,
                  fr: widget.fr,
                ),
              if (!managing && source != null) ...[
                const SizedBox(height: 16),
                _target(owned),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: reduce
                      ? const Duration(milliseconds: 80)
                      : const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  child: preview == null
                      ? (previewing
                            ? const LinearProgressIndicator(
                                key: ValueKey('loading'),
                              )
                            : const SizedBox.shrink())
                      : _PreviewDetails(
                          key: ValueKey(
                            '${preview!.packageId}-${preview!.mode}-$target',
                          ),
                          preview: preview!,
                          fr: widget.fr,
                        ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(error!, style: TextStyle(color: scheme.error)),
                  ),
                ),
            ],
          ),
        ),
        if (!managing)
          Material(
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (source == null)
                    Text(
                      t(
                        'Choose a package to see what it adds before installing.',
                        'Choisissez un paquet pour voir ce qu’il ajoute avant l’installation.',
                      ),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  if (preview != null && !preview!.allowed)
                    Text(
                      preview!.signatureStatus == 'INVALID'
                          ? t(
                              'Installation is blocked because the signature does not match the file.',
                              'L’installation est bloquée car la signature ne correspond pas au fichier.',
                            )
                          : t(
                              'Installation is blocked until the conflicts are resolved, for example by choosing a new collection.',
                              'L’installation est bloquée tant que les conflits ne sont pas résolus, par exemple en choisissant une nouvelle collection.',
                            ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('Cancel', 'Annuler')),
                      ),
                      FilledButton(
                        onPressed:
                            busy || previewing || preview?.allowed != true
                            ? null
                            : install,
                        child: Text(
                          busy
                              ? t('Installing…', 'Installation…')
                              : preview?.mode == 'UPDATE'
                              ? t(
                                  'Update to ${preview!.version}',
                                  'Mettre à jour vers ${preview!.version}',
                                )
                              : t(
                                  'Install a local copy',
                                  'Installer une copie locale',
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _library(ColorScheme scheme) {
    final items = pilots;
    if (items == null) return const LinearProgressIndicator();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Semantics(
                  button: true,
                  selected: source == item.packageJson,
                  child: Material(
                    color: source == item.packageJson
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: source == item.packageJson
                            ? scheme.primary
                            : scheme.outlineVariant,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => choose(item.packageJson, item.name),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${t('Version', 'Version')} ${item.version}',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _import() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: busy ? null : pickFile,
        icon: const Icon(Icons.upload_file),
        label: Text(
          t(
            'Choose a package file (.json, 512 KiB maximum)',
            'Choisir un fichier de paquet (.json, 512 Kio maximum)',
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: link,
        keyboardType: TextInputType.url,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: t('Or a https link', 'Ou un lien https'),
          hintText: 'https://',
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: busy || link.text.trim().isEmpty ? null : readLink,
        icon: const Icon(Icons.link),
        label: Text(t('Read link', 'Lire le lien')),
      ),
      const SizedBox(height: 8),
      Text(
        t(
          'Brainy reads the file on this device and checks it before anything is installed. There is no public package store.',
          'Brainy lit le fichier sur cet appareil et le vérifie avant toute installation. Il n’existe pas de boutique publique de paquets.',
        ),
      ),
      if (sourceLabel != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${t('Selected', 'Sélectionné')} : $sourceLabel',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
    ],
  );

  Widget _target(List<BrainyCollection> owned) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.end,
    children: [
      DropdownMenu<String>(
        initialSelection: target,
        label: Text(t('Install into', 'Installer dans')),
        width: 300,
        dropdownMenuEntries: [
          DropdownMenuEntry(
            value: _newTarget,
            label: t('A new collection', 'Une nouvelle collection'),
          ),
          for (final item in owned)
            DropdownMenuEntry(value: item.id, label: item.name),
        ],
        onSelected: (value) {
          if (value == null) return;
          setState(() => target = value);
          refreshPreview();
        },
      ),
      if (target == _newTarget)
        SizedBox(
          width: 300,
          child: TextField(
            controller: collectionName,
            maxLength: 80, buildCounter: quietFormCounter,
            decoration: InputDecoration(
              labelText: t('Collection name', 'Nom de la collection'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
    ],
  );
}

class _PreviewDetails extends StatelessWidget {
  const _PreviewDetails({super.key, required this.preview, required this.fr});
  final DomainPackagePreview preview;
  final bool fr;

  @override
  Widget build(BuildContext context) {
    String t(String en, String frText) => fr ? frText : en;
    final scheme = Theme.of(context).colorScheme;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(DateTime.parse('${preview.publishedAt}T12:00:00'));
    final groups = <(String, List<String>)>[
      (t('Data formats', 'Formats de données'), preview.dataFormats),
      (t('New fields', 'Nouveaux champs'), preview.addedFields),
      (t('Local units', 'Unités locales'), preview.units),
      (t('Code lists', 'Listes de codes'), preview.codeLists),
      (t('Views', 'Vues'), preview.views),
      (t('Formulas', 'Formules'), preview.formulas),
      (t('Stock rules', 'Règles de stock'), preview.stockRules),
    ].where((group) => group.$2.isNotEmpty).toList();
    Widget box(
      Color background,
      Color border,
      String title,
      List<String> items, {
      IconData? icon,
    }) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(icon, size: 18, color: scheme.error),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final item in items) Text('• $item'),
              ],
            ),
          ),
        ],
      ),
    );
    final mode = preview.mode == 'UPDATE'
        ? t(
            'Update ${preview.installedVersion} → ${preview.version}',
            'Mise à jour ${preview.installedVersion} → ${preview.version}',
          )
        : preview.mode == 'INSTALL'
        ? t('Add to this collection', 'Ajout à cette collection')
        : t('New collection', 'Nouvelle collection');
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  preview.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Chip(label: Text(mode), visualDensity: VisualDensity.compact),
              ],
            ),
            if (preview.description.isNotEmpty)
              Text(
                preview.description,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                for (final (label, value) in [
                  (t('Author', 'Auteur'), preview.author),
                  (t('Version', 'Version'), preview.version),
                  (t('Licence', 'Licence'), preview.license),
                  (t('Published', 'Publié le'), date),
                ])
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      Text(value),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Signature', 'Signature'),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      preview.signatureStatus == 'VALID'
                          ? '${t('Matches key', 'Correspond à la clé')} ${preview.keyFingerprint}'
                          : preview.signatureStatus == 'INVALID'
                          ? t('Invalid', 'Invalide')
                          : t('Not signed', 'Non signé'),
                      style: TextStyle(
                        color: preview.signatureStatus == 'INVALID'
                            ? scheme.error
                            : null,
                        fontWeight: preview.signatureStatus == 'INVALID'
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (preview.signatureStatus == 'VALID')
              Text(
                t(
                  'A signature proves the file was not changed since signing with this key. It does not prove who the author is.',
                  'Une signature prouve que le fichier n’a pas changé depuis sa signature avec cette clé. Elle ne prouve pas l’identité de l’auteur.',
                ),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            if (preview.notice.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(preview.notice),
              ),
            if (preview.conflicts.isNotEmpty)
              Semantics(
                liveRegion: true,
                child: box(
                  scheme.errorContainer,
                  scheme.error.withValues(alpha: .4),
                  t('Conflicts to resolve', 'Conflits à résoudre'),
                  preview.conflicts,
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            if (preview.adjustments.isNotEmpty)
              box(
                scheme.tertiaryContainer,
                scheme.tertiary.withValues(alpha: .35),
                t('Adjustments', 'Ajustements'),
                preview.adjustments,
              ),
            if (groups.isEmpty && preview.exampleObjects == 0)
              Text(t('Nothing new to add.', 'Rien de nouveau à ajouter.'))
            else
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final (title, items) in groups)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 160,
                        maxWidth: 260,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$title  ${items.length}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          for (final item in items) Text('• $item'),
                        ],
                      ),
                    ),
                  if (preview.exampleObjects > 0)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t('Example objects', 'Objets d’exemple')}  ${preview.exampleObjects}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            t(
                              'Editable examples you can delete.',
                              'Exemples modifiables, supprimables.',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (preview.dependencies.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${t('Dependencies', 'Dépendances')} (${preview.dependencies.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in preview.dependencies) Text('• $item'),
                ],
              ),
            if (preview.mode == 'UPDATE')
              Text(
                t(
                  'An update only adds elements. Nothing you changed or entered is modified or removed.',
                  'Une mise à jour ne fait qu’ajouter des éléments. Rien de ce que vous avez modifié ou saisi n’est changé ni supprimé.',
                ),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManagePanel extends StatefulWidget {
  const _ManagePanel({
    required this.api,
    required this.collection,
    required this.userName,
    required this.fr,
  });
  final DomainPackageApi api;
  final BrainyCollection collection;
  final String userName;
  final bool fr;
  @override
  State<_ManagePanel> createState() => _ManagePanelState();
}

class _ManagePanelState extends State<_ManagePanel> {
  List<DomainPackageInstall>? installs;
  late final fields = <String, TextEditingController>{
    'name': TextEditingController(text: widget.collection.name),
    'packageId': TextEditingController(
      text:
          '${_slug(widget.userName, 'me')}.${_slug(widget.collection.name, 'package')}',
    ),
    'version': TextEditingController(text: '1.0.0'),
    'author': TextEditingController(text: widget.userName),
    'license': TextEditingController(text: 'CC-BY-4.0'),
    'description': TextEditingController(),
  };
  List<String> warnings = [];
  String? error, done;
  bool busy = false;

  String t(String en, String fr) => widget.fr ? fr : en;
  static String _slug(String value, String fallback) {
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
    };
    final plain = value
        .toLowerCase()
        .split('')
        .map((char) => accents[char] ?? char)
        .join();
    final slug = plain
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty
        ? fallback
        : slug.substring(0, slug.length.clamp(0, 60));
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final items = await widget.api.installs(widget.collection.id);
      if (mounted) setState(() => installs = items);
    } catch (cause) {
      if (mounted) {
        setState(() {
          installs = [];
          error = '$cause';
        });
      }
    }
  }

  Future<void> detach(DomainPackageInstall item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Detach ${item.name}?', 'Détacher ${item.name} ?')),
        content: Text(
          t(
            'Data formats and entries stay in the collection. Updates for this package will no longer be proposed.',
            'Les formats de données et les entrées restent dans la collection. Les mises à jour de ce paquet ne seront plus proposées.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Keep', 'Garder')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Detach', 'Détacher')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.detach(item.id);
      done = t(
        'Package detached. Data formats and entries stay in the collection.',
        'Paquet détaché. Les formats de données et les entrées restent dans la collection.',
      );
      await load();
    } catch (cause) {
      error = '$cause';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    setState(() {
      busy = true;
      error = null;
      done = null;
    });
    try {
      final input = {
        for (final entry in fields.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
      };
      final result = await widget.api.export(
        widget.collection.id,
        input,
        widget.fr ? 'fr' : 'en',
      );
      await FilePicker.saveFile(
        fileName: result.fileName,
        bytes: Uint8List.fromList(utf8.encode(result.packageJson)),
      );
      if (mounted) {
        setState(() {
          warnings = result.warnings;
          done = t(
            'Package exported with ${result.dataFormats} data formats and no entries.',
            'Paquet exporté avec ${result.dataFormats} formats de données et aucune entrée.',
          );
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget input(String key, String label, {String? help}) => SizedBox(
      width: 240,
      child: TextField(
        controller: fields[key],
        decoration: InputDecoration(
          labelText: label,
          helperText: help,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          t('Installed packages', 'Paquets installés'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        if (installs == null)
          const LinearProgressIndicator()
        else if (installs!.isEmpty)
          Text(
            t(
              'No package is linked to this collection.',
              'Aucun paquet n’est lié à cette collection.',
            ),
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          for (final item in installs!)
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${item.version} · ${item.author} · ${item.license} · ${t('${item.dataFormatCount} data formats', '${item.dataFormatCount} formats de données')}',
                ),
                trailing: OutlinedButton(
                  onPressed: busy ? null : () => detach(item),
                  child: Text(t('Detach…', 'Détacher…')),
                ),
              ),
            ),
        const Divider(height: 24),
        Text(
          t(
            'Share this structure as a package',
            'Partager cette structure en paquet',
          ),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        Text(
          t(
            'The file holds data formats, local units, code lists, views, formulas and stock rules only. Entries, objects, files, members and shared links are never exported.',
            'Le fichier contient uniquement formats de données, unités locales, listes de codes, vues, formules et règles de stock. Entrées, objets, fichiers, membres et liens partagés ne sont jamais exportés.',
          ),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            input('name', t('Package name', 'Nom du paquet')),
            input(
              'packageId',
              t('Identifier', 'Identifiant'),
              help: t(
                'Lowercase letters, digits, dots and dashes. Keep it for later versions.',
                'Minuscules, chiffres, points et tirets. Gardez-le pour les versions suivantes.',
              ),
            ),
            input('version', t('Version', 'Version')),
            input('author', t('Author', 'Auteur')),
            input('license', t('Licence', 'Licence')),
            input(
              'description',
              t('Description (optional)', 'Description (facultative)'),
            ),
          ],
        ),
        if (warnings.isNotEmpty)
          Text('${t('Not included', 'Non inclus')} : ${warnings.join(' · ')}'),
        if (done != null)
          Semantics(
            liveRegion: true,
            child: Text(
              done!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (error != null) Text(error!, style: TextStyle(color: scheme.error)),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: busy ? null : export,
            icon: const Icon(Icons.download),
            label: Text(t('Export package', 'Exporter le paquet')),
          ),
        ),
      ],
    );
  }
}
