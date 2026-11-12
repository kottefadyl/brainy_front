// T47: book view of a collection created from the Book template. Entries stay ordinary entries;
// this screen only arranges them (roles, parent relations, order field) and edits their values.
import 'book_format_roles.dart';
import 'app_strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'book_model.dart';
import 'book_pages.dart';
import 'collections_api.dart';
import 'data_format_colors.dart';

/// The Book template card shows the three classic sections of a book.
class BookTemplateArt extends StatelessWidget {
  const BookTemplateArt({super.key, required this.french, required this.dark});
  final bool french, dark;

  @override
  Widget build(BuildContext context) {
    final parts = french
        ? const [('I', 'Pages liminaires', 'Titre, dédicace, préface…'), ('II', 'Corps de l’ouvrage', 'Parties, chapitres, sections'), ('III', 'Parties finales', 'Annexes, glossaire, index')]
        : const [('I', 'Front matter', 'Title, dedication, preface…'), ('II', 'Body', 'Parts, chapters, sections'), ('III', 'Back matter', 'Appendices, glossary, index')];
    final tint = dark ? const Color(0xFF2E2740) : const Color(0xFFF1ECFA), ink = dark ? const Color(0xFFCDB8FF) : const Color(0xFF5A3A98);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(children: [
          for (final (number, name, detail) in parts)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: ink.withValues(alpha: .16), borderRadius: BorderRadius.circular(6)), child: Text(number, style: TextStyle(fontFamily: 'Georgia', fontFamilyFallback: const ['serif'], fontSize: 11, color: ink, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(detail, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Card shown on the collection page of a Book collection.
class BookViewLauncher extends StatefulWidget {
  const BookViewLauncher({super.key, required this.api, required this.collection, required this.french, required this.onOpenEntry, required this.onChanged});
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool french;
  final Future<void> Function(BrainyEntry entry) onOpenEntry;
  final Future<void> Function() onChanged;
  @override
  State<BookViewLauncher> createState() => _BookViewLauncherState();
}

class _BookViewLauncherState extends State<BookViewLauncher> {
  bool busy = false;
  String error = '';

  Future<void> _open() async {
    var settings = BookSettings.fromJson(widget.collection.bookView);
    if (!settings.enabled) {
      setState(() { busy = true; error = ''; });
      try {
        settings = await widget.api.setBookView(widget.collection.id, settings.copyWith(enabled: true));
      } catch (cause) {
        if (mounted) setState(() { busy = false; error = bookError(cause, widget.french); });
        return;
      }
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BookViewScreen(api: widget.api, collection: widget.collection, initial: settings, french: widget.french, onOpenEntry: widget.onOpenEntry)));
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collection.templateId != 'book' || widget.collection.bookView == null) return const SizedBox.shrink();
    final fr = widget.french, scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = BookSettings.fromJson(widget.collection.bookView).enabled;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        gradient: LinearGradient(colors: [Color.alphaBlend(const Color(0x1A6944A8), scheme.surface), scheme.surface]),
      ),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, runSpacing: 10, children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: dark ? const Color(0xFF2E2740) : const Color(0xFFEFEAFB), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.menu_book_outlined, color: dark ? const Color(0xFFCDB8FF) : const Color(0xFF5A3A98))),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(fr ? 'Vue livre' : 'Book view', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(enabled ? (fr ? 'Lisez et mettez en page vos entrées comme un livre.' : 'Read and lay out your entries as a book.') : (fr ? 'Désactivée. Vos entrées restent visibles dans la liste.' : 'Turned off. Your entries stay in the list.'), style: TextStyle(color: scheme.onSurfaceVariant)),
          if (error.isNotEmpty) Text(error, style: TextStyle(color: scheme.error)),
        ])),
        enabled
            ? FilledButton.icon(onPressed: busy ? null : _open, icon: const Icon(Icons.auto_stories_outlined), label: Text(fr ? 'Ouvrir le livre' : 'Open the book'))
            : OutlinedButton(onPressed: busy ? null : _open, child: Text(fr ? 'Activer la vue livre' : 'Turn on book view')),
      ]),
    );
  }
}

class BookViewScreen extends StatefulWidget {
  const BookViewScreen({super.key, required this.api, required this.collection, required this.initial, required this.french, required this.onOpenEntry});
  final CollectionsApi api;
  final BrainyCollection collection;
  final BookSettings initial;
  final bool french;
  final Future<void> Function(BrainyEntry entry) onOpenEntry;
  @override
  State<BookViewScreen> createState() => _BookViewScreenState();
}

class _BookViewScreenState extends State<BookViewScreen> {
  late BookSettings settings = widget.initial;
  List<BrainyEntry> entries = [];
  List<Map<String, dynamic>> relations = [];
  bool loading = true;
  String loadError = '';
  String busyId = '';
  String settingsStatus = '';
  Timer? saveTimer;
  final keys = <String, GlobalKey>{};
  final scaffold = GlobalKey<ScaffoldState>();
  bool get fr => widget.french;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([widget.api.entries(widget.collection.id), widget.api.parentRelations(widget.collection.id)]);
      if (!mounted) return;
      setState(() { entries = results[0] as List<BrainyEntry>; relations = results[1] as List<Map<String, dynamic>>; loadError = ''; loading = false; });
    } catch (cause) {
      if (mounted) setState(() { loadError = bookError(cause, fr); loading = false; });
    }
  }

  void _message(Object cause) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bookError(cause, fr))));
  }

  void _changeSettings(BookSettings next) {
    setState(() { settings = next; settingsStatus = fr ? 'Enregistrement…' : 'Saving…'; });
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await widget.api.setBookView(widget.collection.id, next);
        if (mounted) setState(() => settingsStatus = fr ? 'Mise en page enregistrée.' : 'Layout saved.');
      } catch (cause) {
        if (mounted) setState(() => settingsStatus = bookError(cause, fr));
      }
    });
  }

  void _replace(BrainyEntry saved) => setState(() => entries = entries.any((item) => item.id == saved.id) ? [for (final item in entries) item.id == saved.id ? saved : item] : [saved, ...entries]);

  Future<void> _edit(BookNode node, String kind, int index) async {
    final field = node.field(kind, index);
    if (field == null) return;
    final multiline = kind == 'LONG_TEXT';
    final page = _pageContext(context);
    final next = await showBookEditor(context, label: field.name, initial: node.entry.values[field.id] ?? '', multiline: multiline, french: fr, style: multiline ? page.body : page.heading(1.1));
    if (next == null || next == (node.entry.values[field.id] ?? '')) return;
    final values = bookValuesWith(node.entry, field.id, next);
    if (values.values.every((value) => value.trim().isEmpty)) {
      _message(fr ? 'Gardez au moins une valeur ou supprimez cette partie depuis le plan.' : 'Keep at least one value, or delete this part from the outline.');
      return;
    }
    try {
      _replace(await widget.api.saveEntry(widget.collection.id, values, entryId: node.entry.id, formatId: node.entry.formatId, expectedUpdatedAt: node.entry.updatedAt));
    } catch (cause) {
      _message(cause);
    }
  }

  Future<void> _create(BookOutline outline, String role, {BookNode? parent, List<BookNode> siblings = const []}) async {
    final format = outline.formatByRole[role];
    if (format == null) {
      _message(fr ? 'Le format de données « ${bookRoleLabel(role, fr)} » n’existe plus dans cette collection.' : 'The ${bookRoleLabel(role, fr)} data format no longer exists in this collection.');
      return;
    }
    setState(() => busyId = parent?.entry.id ?? role);
    try {
      final probe = BookNode(BrainyEntry(id: '', values: const {}, createdAt: DateTime.now(), updatedAt: DateTime.now()), format, role);
      final first = probe.field('TITLE') ?? probe.field('LONG_TEXT');
      final number = probe.field('NUMBER');
      const fresh = {'PART': ('New part', 'Nouvelle partie'), 'CHAPTER': ('New chapter', 'Nouveau chapitre'), 'SECTION': ('New section', 'Nouvelle section'), 'SUBSECTION': ('New subsection', 'Nouvelle sous-section'), 'APPENDIX': ('New appendix', 'Nouvelle annexe'), 'TERM': ('New term', 'Nouveau terme'), 'SOURCE': ('New source', 'Nouvelle source'), 'DEDICATION': ('To…', 'À…'), 'EPIGRAPH': ('…', '…')};
      final label = fresh[role] == null ? bookRoleLabel(role, fr) : (fr ? fresh[role]!.$2 : fresh[role]!.$1);
      final maxOrder = siblings.fold<double>(0, (value, item) => (item.order ?? 0) > value ? item.order! : value);
      final values = {
        first!.id: label,
        if (number != null) number.id: '${maxOrder.floor() + 1}',
        if (role == 'TERM') for (final field in format.fields.where((item) => item.kind == BrainyFieldKind.boolean)) field.id: 'true',
      };
      final created = await widget.api.saveEntry(widget.collection.id, values, formatId: format.id);
      if (parent != null) {
        try {
          await widget.api.createRelation(widget.collection.id, created.id, parent.entry.id, 'PARENT', '');
          relations = [...relations, {'fromEntryId': created.id, 'toEntryId': parent.entry.id, 'kind': 'PARENT'}];
        } catch (cause) {
          _message(cause);
        }
      }
      _replace(created);
      if (['TERM', 'SOURCE', 'COVER'].contains(role)) {
        await widget.onOpenEntry(created);
        await _load();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBookSheet(_pageContext(context), created.id));
      }
    } catch (cause) {
      _message(cause);
    } finally {
      if (mounted) setState(() => busyId = '');
    }
  }

  Future<void> _move(BookNode node, List<BookNode> siblings, int direction) async {
    final index = siblings.indexOf(node);
    if (index + direction < 0 || index + direction >= siblings.length) return;
    setState(() => busyId = node.entry.id);
    try {
      final reordered = [...siblings]..[index] = siblings[index + direction]..[index + direction] = node;
      for (var position = 0; position < reordered.length; position++) {
        final item = reordered[position], field = item.field('NUMBER');
        if (field == null || item.entry.values[field.id] == '${position + 1}') continue;
        _replace(await widget.api.saveEntry(widget.collection.id, bookValuesWith(item.entry, field.id, '${position + 1}'), entryId: item.entry.id, formatId: item.entry.formatId, expectedUpdatedAt: item.entry.updatedAt));
      }
    } catch (cause) {
      _message(cause);
      await _load();
    } finally {
      if (mounted) setState(() => busyId = '');
    }
  }

  Future<void> _place(BookNode node, String parentId) async {
    setState(() => busyId = node.entry.id);
    try {
      await widget.api.createRelation(widget.collection.id, node.entry.id, parentId, 'PARENT', '');
      await _load();
    } catch (cause) {
      _message(cause);
    } finally {
      if (mounted) setState(() => busyId = '');
    }
  }

  Future<void> _delete(BookNode node) async {
    final name = node.title.isEmpty ? bookRoleLabel(node.role, fr) : node.title;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(fr ? 'Supprimer cette partie du livre ?' : 'Delete this part of the book?'),
      content: Text(fr ? '« $name » sera supprimée de la collection.${node.children.isEmpty ? '' : ' Ses ${node.children.length} sous-parties sont conservées et restent dans le plan.'}' : '“$name” will be deleted from the collection.${node.children.isEmpty ? '' : ' Its ${node.children.length} sub-parts are kept and stay in the outline.'}'),
      actions: [
        TextButton(autofocus: true, onPressed: () => Navigator.of(context).pop(false), child: Text(fr ? 'Annuler' : 'Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError), onPressed: () => Navigator.of(context).pop(true), child: Text(fr ? 'Supprimer' : 'Delete')),
      ],
    ));
    if (confirmed != true) return;
    setState(() => busyId = node.entry.id);
    try {
      for (final relation in relations.where((item) => item['fromEntryId'] == node.entry.id || item['toEntryId'] == node.entry.id)) {
        final id = relation['id'] as String?;
        if (id != null) await widget.api.removeRelation(widget.collection.id, id);
      }
      await widget.api.deleteEntry(node.entry.id);
      await _load();
    } catch (cause) {
      _message(cause);
    } finally {
      if (mounted) setState(() => busyId = '');
    }
  }

  Future<void> _turnOff() async {
    try {
      await widget.api.setBookView(widget.collection.id, settings.copyWith(enabled: false));
      if (mounted) Navigator.of(context).pop();
    } catch (cause) {
      _message(cause);
    }
  }

  BookPageContext _pageContext(BuildContext context) => BookPageContext(
        settings: settings,
        french: fr,
        paper: BookPaper.of(context),
        keys: keys,
        edit: _edit,
        loadImage: (node) async {
          final field = node.field('ATTACHMENT');
          if (field == null || (node.entry.values[field.id] ?? '').isEmpty || node.entry.largeFiles.containsKey(field.id)) return null;
          try {
            final file = await widget.api.entryAttachment(node.entry.id, field.id);
            return file.mimeType.startsWith('image/') ? file.bytes : null;
          } catch (_) {
            return null;
          }
        },
      );

  void _openSettings() {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final sheet = StatefulBuilder(builder: (context, setSheet) => _BookSettingsPanel(settings: settings, french: fr, status: settingsStatus, onChanged: (next) { _changeSettings(next); setSheet(() {}); }, current: () => settings, statusText: () => settingsStatus));
    if (wide) {
      showDialog<void>(context: context, builder: (_) => Dialog(alignment: Alignment.centerRight, insetPadding: const EdgeInsets.all(16), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: sheet)));
    } else {
      showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => FractionallySizedBox(heightFactor: .8, child: sheet));
    }
  }

  Future<void> _setFormatRole(String formatId, String? role) async {
    setState(() => busyId = formatId);
    try {
      final next = await widget.api.setBookFormatRole(widget.collection.id, formatId, role);
      if (mounted) setState(() => settings = settings.copyWith(roles: next.roles));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).error(error))));
    } finally {
      if (mounted) setState(() => busyId = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final outline = buildBookOutline(widget.collection, settings, entries, relations);
    final page = _pageContext(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final outlinePanel = _BookOutlinePanel(
      outline: outline, french: fr, busyId: busyId,
      onJump: (id) { if (!wide) Navigator.of(context).maybePop(); WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBookSheet(page, id)); },
      onCreate: (role, {parent, siblings = const []}) => _create(outline, role, parent: parent, siblings: siblings),
      onMove: _move, onDelete: _delete, onPlace: _place,
      onOpenEntry: (entry) async { await widget.onOpenEntry(entry); await _load(); },
      formatRoles: widget.collection.sharedBy != null ? null : BookFormatRoles(formats: widget.collection.formats, roles: settings.roles, french: fr, busyFormatId: busyId, onChanged: _setFormatRole),
    );
    final paper = BookPaper.of(context);
    Widget pages;
    if (loading) {
      pages = const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    } else if (loadError.isNotEmpty) {
      pages = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(loadError), const SizedBox(height: 12), FilledButton(onPressed: () { setState(() => loading = true); _load(); }, child: Text(fr ? 'Réessayer' : 'Retry'))]));
    } else if (outline.isEmpty) {
      pages = SingleChildScrollView(padding: const EdgeInsets.all(16), child: BookSheet(page: page, center: true, child: Column(children: [
        Icon(Icons.auto_stories_outlined, size: 40, color: paper.muted),
        const SizedBox(height: 10),
        Text(fr ? 'Votre livre commence ici' : 'Your book starts here', style: page.heading(1.2)),
        const SizedBox(height: 6),
        Text(fr ? 'Ajoutez une couverture, une partie ou directement un premier chapitre. Chaque page reste une entrée de la collection.' : 'Add a cover, a part or straight away a first chapter. Every page stays an entry of the collection.', textAlign: TextAlign.center, style: page.body.copyWith(color: paper.muted)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          FilledButton.icon(onPressed: () => _create(outline, 'CHAPTER'), icon: const Icon(Icons.add), label: Text(fr ? 'Premier chapitre' : 'First chapter')),
          if (outline.formatByRole.containsKey('COVER')) OutlinedButton(onPressed: () => _create(outline, 'COVER'), child: Text(bookRoleLabel('COVER', fr))),
        ]),
      ])));
    } else {
      pages = SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 16, 12, 40), child: BookPages(page: page, outline: outline, bookTitle: widget.collection.name));
    }
    final workspace = Container(
      color: paper.desk,
      child: Column(children: [
        if (settings.showRuler && !loading) Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: _BookRuler(settings: settings, french: fr, onChanged: _changeSettings)),
        Expanded(child: pages),
      ]),
    );
    return Scaffold(
      key: scaffold,
      appBar: AppBar(
        title: Row(children: [const Icon(Icons.menu_book_outlined, size: 20), const SizedBox(width: 8), Flexible(child: Text(widget.collection.name, overflow: TextOverflow.ellipsis))]),
        actions: [
          if (!wide) IconButton(tooltip: fr ? 'Plan du livre' : 'Book outline', onPressed: () => scaffold.currentState?.openEndDrawer(), icon: const Icon(Icons.account_tree_outlined)),
          IconButton(tooltip: fr ? 'Mise en page' : 'Layout', onPressed: _openSettings, icon: const Icon(Icons.tune)),
          PopupMenuButton<String>(
            tooltip: fr ? 'Plus d’actions' : 'More actions',
            onSelected: (value) { if (value == 'off') _turnOff(); },
            itemBuilder: (_) => [PopupMenuItem(value: 'off', child: Text(fr ? 'Désactiver la vue livre' : 'Turn off book view'))],
          ),
        ],
      ),
      endDrawer: wide ? null : Drawer(width: 340, child: SafeArea(child: outlinePanel)),
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SizedBox(width: 320, child: Material(color: Theme.of(context).colorScheme.surface, child: outlinePanel)), const VerticalDivider(width: 1), Expanded(child: workspace)])
          : workspace,
    );
  }
}

typedef _CreateCallback = Future<void> Function(String role, {BookNode? parent, List<BookNode> siblings});

class _BookOutlinePanel extends StatelessWidget {
  const _BookOutlinePanel({required this.outline, required this.french, required this.busyId, required this.onJump, required this.onCreate, required this.onMove, required this.onDelete, required this.onPlace, required this.onOpenEntry, this.formatRoles});
  /// T47/3: owner only — choose how each data format appears in the book.
  final Widget? formatRoles;
  final BookOutline outline;
  final bool french;
  final String busyId;
  final void Function(String id) onJump;
  final _CreateCallback onCreate;
  final Future<void> Function(BookNode node, List<BookNode> siblings, int direction) onMove;
  final Future<void> Function(BookNode node) onDelete;
  final Future<void> Function(BookNode node, String parentId) onPlace;
  final Future<void> Function(BrainyEntry entry) onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final fr = french, theme = Theme.of(context), dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget heading(String text) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 6), child: Text(text.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: .6, fontWeight: FontWeight.w700)));
    Widget add(String label, VoidCallback? onPressed, {double indent = 0}) => Padding(padding: EdgeInsets.only(left: indent), child: Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: onPressed, icon: const Icon(Icons.add, size: 16), label: Text(label))));
    final chapterParents = outline.chapters;
    List<Widget> row(BookNode node, String label, List<BookNode> siblings, int depth) {
      final child = childRole[node.role];
      final busy = busyId == node.entry.id;
      final name = node.title.isEmpty ? bookRoleLabel(node.role, fr) : node.title;
      final indent = depth * 16.0;
      return [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: Row(children: [
            Container(width: 12, height: 12, margin: const EdgeInsets.only(right: 8, left: 4), decoration: BoxDecoration(color: DataFormatColors.marker(node.format.color, dark), borderRadius: BorderRadius.circular(4))),
            Expanded(child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onJump(node.entry.id),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
            )),
            if (siblings.length > 1 && node.field('NUMBER') != null) ...[
              IconButton(visualDensity: VisualDensity.compact, tooltip: '${fr ? 'Monter' : 'Move up'} : $name', onPressed: busy || siblings.first == node ? null : () => onMove(node, siblings, -1), icon: const Icon(Icons.arrow_upward, size: 18)),
              IconButton(visualDensity: VisualDensity.compact, tooltip: '${fr ? 'Descendre' : 'Move down'} : $name', onPressed: busy || siblings.last == node ? null : () => onMove(node, siblings, 1), icon: const Icon(Icons.arrow_downward, size: 18)),
            ],
            PopupMenuButton<String>(
              tooltip: '${fr ? 'Actions' : 'Actions'} : $name',
              enabled: !busy,
              onSelected: (value) => value == 'fields' ? onOpenEntry(node.entry) : onDelete(node),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'fields', child: Text(fr ? 'Tous les champs' : 'All fields')),
                PopupMenuItem(value: 'delete', child: Text(fr ? 'Supprimer' : 'Delete', style: TextStyle(color: theme.colorScheme.error))),
              ],
            ),
          ]),
        ),
        for (final item in node.children) ...row(item, child == 'CHAPTER' ? '${bookRoleLabel('CHAPTER', fr)} ${item.number}' : child == 'SECTION' ? '${node.number}.${item.number}' : '${bookRoleLabel('SUBSECTION', fr)} ${item.number}', node.children, depth + 1),
        if (child != null) add(bookRoleLabel(child, fr), busy ? null : () => onCreate(child, parent: node, siblings: node.children), indent: indent + 16),
      ];
    }

    final missing = singleRoles.where((role) => outline.formatByRole.containsKey(role) && ![...outline.front, ...outline.back].any((item) => item.role == role));
    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
      Row(children: [const Icon(Icons.account_tree_outlined, size: 18), const SizedBox(width: 8), Text(fr ? 'Plan du livre' : 'Book outline', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
      heading(fr ? 'Pages liminaires' : 'Front matter'),
      for (final item in outline.front) ...row(item, bookRoleLabel(item.role, fr), const [], 0),
      heading(fr ? 'Corps de l’ouvrage' : 'Body'),
      for (final part in outline.parts) ...row(part, '${bookRoleLabel('PART', fr)} ${romanNumeral(part.number)}', outline.parts, 0),
      for (final chapter in outline.looseChapters) ...row(chapter, '${bookRoleLabel('CHAPTER', fr)} ${chapter.number}', outline.looseChapters, 0),
      add(bookRoleLabel('PART', fr), busyId == 'PART' ? null : () => onCreate('PART', siblings: outline.parts)),
      add(fr ? 'Chapitre hors partie' : 'Chapter outside a part', busyId == 'CHAPTER' ? null : () => onCreate('CHAPTER', siblings: outline.looseChapters)),
      if (outline.unplaced.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Color.alphaBlend(const Color(0x178A5A00), theme.colorScheme.surface), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(fr ? 'À placer' : 'To place', style: TextStyle(fontWeight: FontWeight.w700, color: dark ? const Color(0xFFE8C77A) : const Color(0xFF8A5A00))),
            Text(fr ? 'Ces sections n’ont pas encore de parent ; elles n’apparaissent pas dans les pages.' : 'These sections have no parent yet, so they are not shown in the pages.', style: theme.textTheme.bodySmall),
            for (final item in outline.unplaced) ...[
              const SizedBox(height: 8),
              Text('${bookRoleLabel(item.role, fr)} · ${item.title.isEmpty ? '—' : item.title}'),
              Builder(builder: (context) {
                final candidates = item.role == 'SECTION' ? chapterParents : chapterParents.expand((chapter) => chapter.children).toList();
                return DropdownButton<String>(
                  isExpanded: true,
                  hint: Text(candidates.isEmpty ? (fr ? 'Aucun parent possible' : 'No possible parent') : (fr ? 'Placer sous…' : 'Place under…')),
                  items: [for (final candidate in candidates) DropdownMenuItem(value: candidate.entry.id, child: Text(candidate.title.isEmpty ? bookRoleLabel(candidate.role, fr) : candidate.title, overflow: TextOverflow.ellipsis))],
                  onChanged: candidates.isEmpty || busyId == item.entry.id ? null : (value) { if (value != null) onPlace(item, value); },
                );
              }),
            ],
          ]),
        ),
      heading(fr ? 'Parties finales' : 'Back matter'),
      for (final item in outline.back) ...row(item, bookRoleLabel(item.role, fr), const [], 0),
      for (var index = 0; index < outline.appendices.length; index++) ...row(outline.appendices[index], '${bookRoleLabel('APPENDIX', fr)} ${String.fromCharCode(65 + index)}', outline.appendices, 0),
      add(bookRoleLabel('APPENDIX', fr), () => onCreate('APPENDIX', siblings: outline.appendices)),
      add(fr ? 'Terme (glossaire, index)' : 'Term (glossary, index)', () => onCreate('TERM')),
      add(fr ? 'Source (bibliographie)' : 'Source (bibliography)', () => onCreate('SOURCE')),
      if (missing.isNotEmpty) ...[
        heading(fr ? 'Ajouter une page' : 'Add a page'),
        Text(fr ? 'Chacune de ces pages n’existe qu’une fois dans le livre.' : 'Each of these pages exists only once in the book.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final role in missing) ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(bookRoleLabel(role, fr)), onPressed: busyId == role ? null : () => onCreate(role))]),
      ],
      if (formatRoles != null) formatRoles! else if (outline.hiddenFormats.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('${fr ? 'Non affichés dans le livre' : 'Not shown in the book'} : ${outline.hiddenFormats.map((format) => format.name).join(', ')}.', style: theme.textTheme.bodySmall?.copyWith(color: muted))),
    ]);
  }
}

class _BookSettingsPanel extends StatelessWidget {
  const _BookSettingsPanel({required this.settings, required this.french, required this.status, required this.onChanged, required this.current, required this.statusText});
  final BookSettings settings;
  final bool french;
  final String status;
  final ValueChanged<BookSettings> onChanged;
  final BookSettings Function() current;
  final String Function() statusText;

  @override
  Widget build(BuildContext context) {
    final fr = french, value = current();
    Widget slider(String label, double number, double min, double max, int divisions, String unit, BookSettings Function(double) apply) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text(label)), Text('${number.toStringAsFixed(number == number.roundToDouble() ? 0 : number * 10 == (number * 10).roundToDouble() ? 1 : 2)}$unit', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]),
          Slider(value: number.clamp(min, max), min: min, max: max, divisions: divisions, label: '$number$unit', onChanged: (next) => onChanged(apply(double.parse(next.toStringAsFixed(2))))),
        ]);
    Widget dropdown(String label, String selected, Map<String, String> options, ValueChanged<String> apply) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(isExpanded: true, initialValue: selected, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), items: [for (final item in options.entries) DropdownMenuItem(value: item.key, child: Text(item.value, overflow: TextOverflow.ellipsis))], onChanged: (next) { if (next != null) apply(next); }),
        );
    final fonts = {for (final font in bookFonts) font: bookFontLabel(font, fr)};
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(fr ? 'Mise en page' : 'Layout', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      dropdown(fr ? 'Police du texte' : 'Body font', value.bodyFont, fonts, (next) => onChanged(value.copyWith(bodyFont: next))),
      dropdown(fr ? 'Police des titres' : 'Heading font', value.headingFont, fonts, (next) => onChanged(value.copyWith(headingFont: next))),
      dropdown(fr ? 'Format de page' : 'Page size', value.pageSize, {'A5': 'A5 (148 × 210 mm)', 'A4': 'A4 (210 × 297 mm)', 'POCKET': fr ? 'Poche (110 × 178 mm)' : 'Pocket (110 × 178 mm)'}, (next) => onChanged(value.copyWith(pageSize: next))),
      slider(fr ? 'Taille du texte' : 'Text size', value.fontSize, 12, 24, 12, ' px', (next) => value.copyWith(fontSize: next.roundToDouble())),
      slider(fr ? 'Interligne' : 'Line spacing', value.lineHeight, 1, 2.4, 14, '', (next) => value.copyWith(lineHeight: next)),
      slider(fr ? 'Espace entre paragraphes' : 'Paragraph spacing', value.paragraphSpacing, 0, 2, 20, ' em', (next) => value.copyWith(paragraphSpacing: next)),
      slider(fr ? 'Retrait de première ligne' : 'First-line indent', value.firstLineIndent, 0, 3, 12, ' em', (next) => value.copyWith(firstLineIndent: next)),
      slider(fr ? 'Marges' : 'Margins', value.marginMm, 10, 40, 30, ' mm', (next) => value.copyWith(marginMm: next.roundToDouble())),
      const SizedBox(height: 8),
      Text(fr ? 'Alignement' : 'Alignment'),
      const SizedBox(height: 6),
      SegmentedButton<String>(
        segments: [ButtonSegment(value: 'LEFT', label: Text(fr ? 'À gauche' : 'Left'), icon: const Icon(Icons.format_align_left)), ButtonSegment(value: 'JUSTIFY', label: Text(fr ? 'Justifié' : 'Justified'), icon: const Icon(Icons.format_align_justify))],
        selected: {value.textAlign},
        onSelectionChanged: (next) => onChanged(value.copyWith(textAlign: next.first)),
      ),
      const SizedBox(height: 8),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(fr ? 'Afficher la règle' : 'Show ruler'), value: value.showRuler, onChanged: (next) => onChanged(value.copyWith(showRuler: next))),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(fr ? 'Chaque chapitre sur une nouvelle page' : 'Each chapter on a new page'), value: value.chapterOnNewPage, onChanged: (next) => onChanged(value.copyWith(chapterOnNewPage: next))),
      Semantics(liveRegion: true, child: Text(statusText(), style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
}

/// Ruler in millimetres: the lower markers move both margins, the upper marker the first-line indent.
class _BookRuler extends StatelessWidget {
  const _BookRuler({required this.settings, required this.french, required this.onChanged});
  final BookSettings settings;
  final bool french;
  final ValueChanged<BookSettings> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final pageMm = pageWidthMm[settings.pageSize]!;
        final width = (pageMm * mmToPx).clamp(0, constraints.maxWidth).toDouble();
        final scale = width / pageMm;
        final indentMm = settings.firstLineIndent * settings.fontSize / mmToPx;
        final scheme = Theme.of(context).colorScheme;
        double clampMargin(double value) => value.clamp(10, 40).roundToDouble();
        double clampIndent(double value) => (value.clamp(0, 3) * 4).round() / 4;
        Widget handle({required double mm, required bool top, required String label, required String text, required String up, required String down, required void Function(double mm) drag, required void Function(int delta) step}) => Positioned(
              left: mm * scale - 12,
              top: top ? -4 : null,
              bottom: top ? null : -4,
              child: Semantics(
                slider: true,
                label: label,
                value: text,
                increasedValue: up,
                decreasedValue: down,
                onIncrease: () => step(1),
                onDecrease: () => step(-1),
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) { step(1); return KeyEventResult.handled; }
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) { step(-1); return KeyEventResult.handled; }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(builder: (context) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Focus.of(context).requestFocus(),
                    onHorizontalDragUpdate: (details) => drag(mm + details.delta.dx / scale),
                    child: SizedBox(width: 24, height: 24, child: CustomPaint(painter: _MarkerPainter(color: top ? const Color(0xFF6944A8) : scheme.primary, down: top, focused: Focus.of(context).hasFocus))),
                  )),
                ),
              ),
            );
        return Center(
          child: SizedBox(
            width: width,
            height: 28,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: scheme.surface, border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(4)), child: CustomPaint(painter: _RulerPainter(pageMm: pageMm, marginMm: settings.marginMm, color: scheme.onSurfaceVariant, shade: scheme.onSurfaceVariant.withValues(alpha: .12))))),
              handle(mm: settings.marginMm, top: false, label: french ? 'Marges' : 'Margins', text: '${settings.marginMm.round()} mm', up: '${clampMargin(settings.marginMm + 1).round()} mm', down: '${clampMargin(settings.marginMm - 1).round()} mm', drag: (mm) => onChanged(settings.copyWith(marginMm: clampMargin(mm))), step: (delta) => onChanged(settings.copyWith(marginMm: clampMargin(settings.marginMm + delta)))),
              handle(mm: pageMm - settings.marginMm, top: false, label: french ? 'Marge droite' : 'Right margin', text: '${settings.marginMm.round()} mm', up: '${clampMargin(settings.marginMm - 1).round()} mm', down: '${clampMargin(settings.marginMm + 1).round()} mm', drag: (mm) => onChanged(settings.copyWith(marginMm: clampMargin(pageMm - mm))), step: (delta) => onChanged(settings.copyWith(marginMm: clampMargin(settings.marginMm - delta)))),
              handle(mm: settings.marginMm + indentMm, top: true, label: french ? 'Retrait de première ligne' : 'First-line indent', text: '${settings.firstLineIndent} em', up: '${clampIndent(settings.firstLineIndent + .25)} em', down: '${clampIndent(settings.firstLineIndent - .25)} em', drag: (mm) => onChanged(settings.copyWith(firstLineIndent: clampIndent((mm - settings.marginMm) * mmToPx / settings.fontSize))), step: (delta) => onChanged(settings.copyWith(firstLineIndent: clampIndent(settings.firstLineIndent + delta * .25)))),
            ]),
          ),
        );
      });
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.pageMm, required this.marginMm, required this.color, required this.shade});
  final double pageMm, marginMm;
  final Color color, shade;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / pageMm;
    final fill = Paint()..color = shade;
    canvas.drawRect(Rect.fromLTWH(0, 0, marginMm * scale, size.height), fill);
    canvas.drawRect(Rect.fromLTWH(size.width - marginMm * scale, 0, marginMm * scale, size.height), fill);
    final line = Paint()..color = color..strokeWidth = 1;
    for (var mm = 0; mm <= pageMm; mm++) {
      final x = mm * scale;
      final tick = mm % 10 == 0 ? 10.0 : mm % 5 == 0 ? 6.0 : 3.0;
      canvas.drawLine(Offset(x, size.height - tick), Offset(x, size.height), line);
      if (mm % 10 == 0 && mm > 0 && mm < pageMm) {
        final label = TextPainter(text: TextSpan(text: '${mm ~/ 10}', style: TextStyle(fontSize: 10, color: color)), textDirection: TextDirection.ltr)..layout();
        label.paint(canvas, Offset(x - label.width / 2, 2));
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.pageMm != pageMm || old.marginMm != marginMm || old.color != color;
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter({required this.color, required this.down, required this.focused});
  final Color color;
  final bool down, focused;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final path = down
        ? (Path()..moveTo(center - 7, 4)..lineTo(center + 7, 4)..lineTo(center, 13)..close())
        : (Path()..moveTo(center - 7, size.height - 4)..lineTo(center + 7, size.height - 4)..lineTo(center, size.height - 13)..close());
    canvas.drawPath(path, Paint()..color = color);
    if (focused) canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)), Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.color != color || old.down != down || old.focused != focused;
}
