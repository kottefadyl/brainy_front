// T47: book pages (paper sheets), light Markdown rendering and the text editor.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'book_model.dart';
import 'collections_api.dart';

/// Paper colors follow the app theme (warm paper in light, charcoal paper in dark).
class BookPaper {
  const BookPaper._(this.paper, this.ink, this.muted, this.line, this.desk);
  final Color paper, ink, muted, line, desk;
  static BookPaper of(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? const BookPaper._(Color(0xFF232327), Color(0xFFECEAE6), Color(0xFFB4B0A8), Color(0xFF3A3A40), Color(0xFF18181B))
      : const BookPaper._(Color(0xFFFFFDF8), Color(0xFF1F2228), Color(0xFF5B6270), Color(0xFFE4DFD3), Color(0xFFE9ECF2));
}

TextStyle bookFont(String font, TextStyle base) => switch (font) {
      'GARAMOND' => base.copyWith(fontFamily: 'Garamond', fontFamilyFallback: const ['EB Garamond', 'Palatino Linotype', 'Book Antiqua', 'Noto Serif', 'serif']),
      'SANS' => base.copyWith(fontFamily: 'Inter', fontFamilyFallback: const ['Segoe UI', 'Roboto', 'sans-serif']),
      'MONO' => base.copyWith(fontFamily: 'Cascadia Mono', fontFamilyFallback: const ['Consolas', 'Roboto Mono', 'monospace', 'Courier New']),
      _ => base.copyWith(fontFamily: 'Georgia', fontFamilyFallback: const ['Noto Serif', 'Times New Roman', 'serif']),
    };

const mmToPx = 96 / 25.4;

/// Everything the pages need from the screen.
class BookPageContext {
  BookPageContext({required this.settings, required this.french, required this.paper, required this.edit, required this.loadImage, required this.keys});
  final BookSettings settings;
  final bool french;
  final BookPaper paper;
  final Future<void> Function(BookNode node, String kind, int index) edit;
  final Future<Uint8List?> Function(BookNode node) loadImage;
  final Map<String, GlobalKey> keys;

  TextStyle get body => bookFont(settings.bodyFont, TextStyle(fontSize: settings.fontSize, height: settings.lineHeight, color: paper.ink));
  TextStyle heading(double scale, {FontWeight weight = FontWeight.w600}) => bookFont(settings.headingFont, TextStyle(fontSize: settings.fontSize * scale, height: 1.25, fontWeight: weight, color: paper.ink));
  TextStyle get kicker => bookFont(settings.headingFont, TextStyle(fontSize: settings.fontSize * .8, letterSpacing: 1.8, color: paper.muted));
  GlobalKey keyFor(String id) => keys.putIfAbsent(id, GlobalKey.new);
}

List<InlineSpan> inlineSpans(String text, TextStyle style) => [
      for (final run in inlineRuns(text))
        TextSpan(text: run.text, style: style.copyWith(fontWeight: run.bold ? FontWeight.w700 : null, fontStyle: run.italic ? FontStyle.italic : null)),
    ];

class BookRichText extends StatelessWidget {
  const BookRichText({super.key, required this.text, required this.page, this.align, this.indent = true});
  final String text;
  final BookPageContext page;
  final TextAlign? align;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final settings = page.settings, style = page.body;
    final gap = settings.fontSize * settings.paragraphSpacing;
    final indentPx = settings.fontSize * settings.firstLineIndent;
    final blocks = textBlocks(text);
    final children = <Widget>[];
    var previous = '';
    for (final block in blocks) {
      switch (block.kind) {
        case 'break':
          children.add(Padding(padding: EdgeInsets.symmetric(vertical: settings.fontSize * .8), child: Center(child: Text('⁂', style: style.copyWith(color: page.paper.muted)))));
        case 'heading':
          children.add(Padding(padding: EdgeInsets.only(top: settings.fontSize * 1.2, bottom: settings.fontSize * .5), child: Text.rich(TextSpan(children: inlineSpans(block.text, page.heading(1.05))))));
        case 'quote':
          children.add(Container(
            margin: EdgeInsets.only(left: settings.fontSize * 1.5, bottom: gap),
            padding: EdgeInsets.only(left: settings.fontSize),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: page.paper.line, width: 2))),
            child: Text.rich(TextSpan(children: inlineSpans(block.text, style.copyWith(fontStyle: FontStyle.italic, color: page.paper.muted)))),
          ));
        default:
          final first = previous.isEmpty || previous != 'paragraph';
          children.add(Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Text.rich(
              TextSpan(children: [if (indent && !first && indentPx > 0) WidgetSpan(child: SizedBox(width: indentPx)), ...inlineSpans(block.text, style)]),
              textAlign: align ?? (settings.textAlign == 'JUSTIFY' ? TextAlign.justify : TextAlign.left),
            ),
          ));
      }
      previous = block.kind;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// A value of an entry; tapping it opens the editor.
class BookEditable extends StatelessWidget {
  const BookEditable({super.key, required this.page, required this.node, required this.kind, this.index = 0, required this.placeholder, required this.builder});
  final BookPageContext page;
  final BookNode node;
  final String kind;
  final int index;
  final String placeholder;
  final Widget Function(String value) builder;

  @override
  Widget build(BuildContext context) {
    final field = node.field(kind, index);
    if (field == null) return const SizedBox.shrink();
    final value = node.entry.values[field.id] ?? '';
    return Semantics(
      button: true,
      label: '${page.french ? 'Modifier' : 'Edit'} ${field.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => page.edit(node, kind, index),
        child: value.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(placeholder, style: page.body.copyWith(fontStyle: FontStyle.italic, color: page.paper.muted)))
            : builder(value),
      ),
    );
  }
}

class BookSheet extends StatelessWidget {
  const BookSheet({super.key, required this.page, required this.child, this.center = false, this.bottom = false, this.tint, this.fullHeight = false});
  final BookPageContext page;
  final Widget child;
  final bool center, bottom;
  final Color? tint;
  final bool fullHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = (pageWidthMm[page.settings.pageSize]! * mmToPx).clamp(0, constraints.maxWidth).toDouble();
        final height = pageHeightMm[page.settings.pageSize]! * mmToPx * width / (pageWidthMm[page.settings.pageSize]! * mmToPx);
        final margin = (page.settings.marginMm * mmToPx).clamp(12, width * .09).toDouble();
        return Center(
          child: Container(
            width: width,
            constraints: BoxConstraints(minHeight: fullHeight ? height : height * .55),
            margin: const EdgeInsets.only(bottom: 24),
            padding: EdgeInsets.all(margin),
            decoration: BoxDecoration(
              color: tint ?? page.paper.paper,
              border: Border.all(color: page.paper.line),
              borderRadius: BorderRadius.circular(3),
              boxShadow: Theme.of(context).brightness == Brightness.dark ? null : const [BoxShadow(color: Color(0x1A20242C), blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: center || bottom
                ? ConstrainedBox(
                    constraints: BoxConstraints(minHeight: (fullHeight ? height : height * .55) - margin * 2),
                    child: IntrinsicHeight(child: Column(mainAxisAlignment: bottom ? MainAxisAlignment.end : MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [child])),
                  )
                : child,
          ),
        );
      });
}

/// Returns the edited text, or null when cancelled.
Future<String?> showBookEditor(BuildContext context, {required String label, required String initial, required bool multiline, required bool french, required TextStyle style}) {
  final narrow = MediaQuery.sizeOf(context).width < 640;
  return showDialog<String>(
    context: context,
    builder: (context) {
      final editor = _BookEditor(label: label, initial: initial, multiline: multiline, french: french, style: style);
      return narrow ? Dialog.fullscreen(child: editor) : Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720), child: editor));
    },
  );
}

class _BookEditor extends StatefulWidget {
  const _BookEditor({required this.label, required this.initial, required this.multiline, required this.french, required this.style});
  final String label, initial;
  final bool multiline, french;
  final TextStyle style;
  @override
  State<_BookEditor> createState() => _BookEditorState();
}

class _BookEditorState extends State<_BookEditor> {
  late final controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _wrap(String marker) {
    final selection = controller.selection;
    final next = wrapSelection(controller.text, selection.start, selection.end, marker);
    controller.value = TextEditingValue(text: next.text, selection: TextSelection(baseOffset: next.start, extentOffset: next.end));
  }

  void _prefix(String prefix) {
    final next = prefixParagraph(controller.text, controller.selection.start, prefix);
    controller.value = TextEditingValue(text: next.text, selection: TextSelection.collapsed(offset: next.caret));
  }

  void _sceneBreak() {
    final at = controller.selection.start < 0 ? controller.text.length : controller.selection.start;
    final before = controller.text.substring(0, at).trimRight(), after = controller.text.substring(at).trimLeft();
    final text = '$before\n\n***\n\n$after';
    controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: before.length + 7));
  }

  @override
  Widget build(BuildContext context) {
    final fr = widget.french;
    final tools = <(IconData, String, VoidCallback)>[
      (Icons.format_bold, fr ? 'Gras' : 'Bold', () => _wrap('**')),
      (Icons.format_italic, fr ? 'Italique' : 'Italic', () => _wrap('*')),
      (Icons.title, fr ? 'Intertitre' : 'Subheading', () => _prefix('# ')),
      (Icons.format_quote, fr ? 'Citation' : 'Quotation', () => _prefix('> ')),
      (Icons.horizontal_rule, fr ? 'Séparateur de scène' : 'Scene break', _sceneBreak),
    ];
    void save() => Navigator.of(context).pop(controller.text);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): save,
        if (widget.multiline) const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => _wrap('**'),
        if (widget.multiline) const SingleActivator(LogicalKeyboardKey.keyI, control: true): () => _wrap('*'),
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(widget.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              IconButton(tooltip: fr ? 'Annuler' : 'Cancel', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ]),
            if (widget.multiline)
              Wrap(spacing: 2, children: [for (final (icon, tip, action) in tools) IconButton(tooltip: tip, onPressed: action, icon: Icon(icon))]),
            const SizedBox(height: 8),
            Flexible(
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLines: widget.multiline ? null : 1,
                minLines: widget.multiline ? 8 : 1,
                keyboardType: widget.multiline ? TextInputType.multiline : TextInputType.text,
                textInputAction: widget.multiline ? TextInputAction.newline : TextInputAction.done,
                onSubmitted: widget.multiline ? null : (_) => save(),
                style: widget.style,
                decoration: InputDecoration(border: const OutlineInputBorder(), labelText: widget.label),
              ),
            ),
            if (widget.multiline) Padding(padding: const EdgeInsets.only(top: 6), child: Text(fr ? 'Ligne vide : nouveau paragraphe · Ctrl+Entrée : enregistrer' : 'Blank line: new paragraph · Ctrl+Enter: save', style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(fr ? 'Annuler' : 'Cancel')),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: save, icon: const Icon(Icons.check), label: Text(fr ? 'Enregistrer' : 'Save')),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// All the sheets of the book, in reading order.
class BookPages extends StatelessWidget {
  const BookPages({super.key, required this.page, required this.outline, required this.bookTitle});
  final BookPageContext page;
  final BookOutline outline;
  final String bookTitle;

  @override
  Widget build(BuildContext context) {
    final fr = page.french;
    BookNode? find(String role) => outline.front.where((item) => item.role == role).firstOrNull;
    final cover = find('COVER'), titlePage = find('TITLE_PAGE'), introduction = find('INTRODUCTION');
    final beforeToc = outline.front.where((item) => !['COVER', 'TITLE_PAGE', 'INTRODUCTION'].contains(item.role));
    final cited = outline.sources.where((item) => item.value('SELECT').toLowerCase().contains('cit')).toList();
    final consulted = outline.sources.where((item) => !cited.contains(item)).toList();
    final sheets = <Widget>[];
    void sheet(String id, Widget child, {bool center = false, bool bottom = false, Color? tint, bool fullHeight = false}) => sheets.add(KeyedSubtree(key: page.keyFor(id), child: BookSheet(page: page, center: center, bottom: bottom, tint: tint, fullHeight: fullHeight, child: child)));
    Widget title(BookNode node, double scale, String placeholder, {TextAlign align = TextAlign.left}) => BookEditable(page: page, node: node, kind: 'TITLE', placeholder: placeholder, builder: (value) => Text.rich(TextSpan(children: inlineSpans(value, page.heading(scale))), textAlign: align));
    Widget body(BookNode node, String placeholder, {TextAlign? align}) => BookEditable(page: page, node: node, kind: 'LONG_TEXT', placeholder: placeholder, builder: (value) => BookRichText(text: value, page: page, align: align));
    Widget matter(BookNode node) {
      if (node.role == 'DEDICATION') return Padding(padding: EdgeInsets.only(top: page.settings.fontSize * 8), child: body(node, fr ? 'À…' : 'To…', align: TextAlign.right));
      if (node.role == 'EPIGRAPH') {
        return Padding(padding: EdgeInsets.only(top: page.settings.fontSize * 8, left: page.settings.fontSize * 4), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          body(node, fr ? 'Citation' : 'Quotation', align: TextAlign.left),
          BookEditable(page: page, node: node, kind: 'TEXT', placeholder: fr ? 'Auteur de la citation' : 'Quoted author', builder: (value) => Text('— $value', textAlign: TextAlign.right, style: page.body.copyWith(color: page.paper.muted))),
        ]));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: page.settings.fontSize * 2),
        title(node, 1.5, bookRoleLabel(node.role, fr)),
        SizedBox(height: page.settings.fontSize * 1.2),
        body(node, fr ? 'Écrivez ici…' : 'Write here…'),
        if (node.role == 'FOREWORD') BookEditable(page: page, node: node, kind: 'TEXT', placeholder: fr ? 'Signé par' : 'Signed by', builder: (value) => Text(value, textAlign: TextAlign.right, style: page.body.copyWith(fontStyle: FontStyle.italic))),
      ]);
    }

    if (cover != null) {
      sheet(cover.entry.id, fullHeight: true, bottom: true, tint: Color.alphaBlend(const Color(0x266944A8), page.paper.paper), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CoverImage(node: cover, page: page),
        SizedBox(height: page.settings.fontSize * 2),
        BookEditable(page: page, node: cover, kind: 'TEXT', index: 1, placeholder: fr ? 'Auteur' : 'Author', builder: (value) => Text(value.toUpperCase(), style: page.heading(1.05, weight: FontWeight.w400).copyWith(letterSpacing: 1.4))),
        title(cover, 2.3, bookTitle),
        BookEditable(page: page, node: cover, kind: 'TEXT', placeholder: fr ? 'Sous-titre' : 'Subtitle', builder: (value) => Text(value, style: page.body.copyWith(color: page.paper.muted))),
      ]));
    }
    if (titlePage != null) {
      final small = page.body.copyWith(fontSize: page.settings.fontSize * .78, color: page.paper.muted);
      sheet(titlePage.entry.id, fullHeight: true, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: page.settings.fontSize * 6),
        title(titlePage, 1.9, bookTitle, align: TextAlign.center),
        if (cover != null && cover.value('TEXT', 1).isNotEmpty) Text(cover.value('TEXT', 1), textAlign: TextAlign.center, style: page.body),
        SizedBox(height: page.settings.fontSize * 10),
        for (var index = 0; index < 3; index++)
          BookEditable(page: page, node: titlePage, kind: 'TEXT', index: index, placeholder: [fr ? 'Éditeur' : 'Publisher', fr ? 'Lieu et année' : 'Place and year', 'ISBN'][index], builder: (value) => Text(index == 2 ? 'ISBN $value' : value, textAlign: TextAlign.center, style: small)),
        BookEditable(page: page, node: titlePage, kind: 'LONG_TEXT', placeholder: fr ? 'Mentions légales' : 'Copyright notice', builder: (value) => Text.rich(TextSpan(children: inlineSpans(value, small)), textAlign: TextAlign.center)),
      ]));
    }
    for (final item in beforeToc) {
      sheet(item.entry.id, matter(item));
    }
    if (outline.chapters.isNotEmpty || outline.parts.isNotEmpty || outline.back.isNotEmpty) {
      final rows = <(String id, String label, String title, int depth)>[
        if (introduction != null) (introduction.entry.id, '', introduction.title.isEmpty ? bookRoleLabel('INTRODUCTION', fr) : introduction.title, 0),
        for (final part in outline.parts) ...[
          (part.entry.id, '${bookRoleLabel('PART', fr)} ${romanNumeral(part.number)}', part.title, 0),
          for (final chapter in part.children) (chapter.entry.id, '${chapter.number}', chapter.title, 1),
        ],
        for (final chapter in outline.looseChapters) (chapter.entry.id, '${chapter.number}', chapter.title, 0),
        for (final item in outline.back) (item.entry.id, '', item.title.isEmpty ? bookRoleLabel(item.role, fr) : item.title, 0),
        for (var index = 0; index < outline.appendices.length; index++) (outline.appendices[index].entry.id, '${bookRoleLabel('APPENDIX', fr)} ${String.fromCharCode(65 + index)}', outline.appendices[index].title, 0),
        if (outline.glossary.isNotEmpty) ('glossary', '', fr ? 'Glossaire' : 'Glossary', 0),
        if (outline.sources.isNotEmpty) ('sources', '', fr ? 'Bibliographie' : 'Bibliography', 0),
        if (outline.indexTerms.isNotEmpty) ('index', '', 'Index', 0),
      ];
      sheet('toc', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: page.settings.fontSize * 2),
        Text(fr ? 'Table des matières' : 'Contents', style: page.heading(1.5)),
        SizedBox(height: page.settings.fontSize),
        for (final row in rows)
          InkWell(
            onTap: () => scrollToBookSheet(page, row.$1),
            child: Container(
              padding: EdgeInsets.only(left: row.$4 * page.settings.fontSize * 1.5, top: 4, bottom: 4),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: page.paper.line))),
              child: Row(children: [SizedBox(width: page.settings.fontSize * 4.5, child: Text(row.$2, style: page.body.copyWith(color: page.paper.muted))), Expanded(child: Text(row.$3, style: page.body))]),
            ),
          ),
      ]));
    }
    if (introduction != null) sheet(introduction.entry.id, matter(introduction));
    Widget chapterBody(BookNode chapter) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: page.settings.fontSize * 3),
          Text('${bookRoleLabel('CHAPTER', fr).toUpperCase()} ${chapter.number}', style: page.kicker),
          title(chapter, 1.7, fr ? 'Titre du chapitre' : 'Chapter title'),
          SizedBox(height: page.settings.fontSize * 1.6),
          body(chapter, fr ? 'Écrivez le chapitre…' : 'Write the chapter…'),
          for (final section in chapter.children)
            KeyedSubtree(key: page.keyFor(section.entry.id), child: Padding(padding: EdgeInsets.only(top: page.settings.fontSize * 1.4), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BookEditable(page: page, node: section, kind: 'TITLE', placeholder: fr ? 'Titre de la section' : 'Section title', builder: (value) => Text.rich(TextSpan(children: [TextSpan(text: '${chapter.number}.${section.number}  ', style: page.heading(1.2, weight: FontWeight.w500).copyWith(color: page.paper.muted)), ...inlineSpans(value, page.heading(1.2))]))),
              SizedBox(height: page.settings.fontSize * .6),
              body(section, fr ? 'Texte de la section…' : 'Section text…'),
              for (final sub in section.children)
                KeyedSubtree(key: page.keyFor(sub.entry.id), child: Padding(padding: EdgeInsets.only(top: page.settings.fontSize), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  BookEditable(page: page, node: sub, kind: 'TITLE', placeholder: fr ? 'Titre de la sous-section' : 'Subsection title', builder: (value) => Text.rich(TextSpan(children: [TextSpan(text: '${chapter.number}.${section.number}.${sub.number}  ', style: page.heading(1.05, weight: FontWeight.w500).copyWith(color: page.paper.muted)), ...inlineSpans(value, page.heading(1.05).copyWith(fontStyle: FontStyle.italic))]))),
                  SizedBox(height: page.settings.fontSize * .4),
                  body(sub, fr ? 'Texte…' : 'Text…'),
                ]))),
            ]))),
        ]);
    void chapters(List<BookNode> list) {
      if (page.settings.chapterOnNewPage || list.isEmpty) {
        for (final chapter in list) {
          sheet(chapter.entry.id, chapterBody(chapter));
        }
      } else {
        sheet(list.first.entry.id, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final chapter in list) KeyedSubtree(key: list.first == chapter ? null : page.keyFor(chapter.entry.id), child: chapterBody(chapter))]));
      }
    }

    for (final part in outline.parts) {
      sheet(part.entry.id, center: true, Column(children: [
        Text('${bookRoleLabel('PART', fr).toUpperCase()} ${romanNumeral(part.number)}', style: page.kicker, textAlign: TextAlign.center),
        title(part, 2, fr ? 'Titre de la partie' : 'Part title', align: TextAlign.center),
        SizedBox(height: page.settings.fontSize),
        body(part, fr ? 'Texte d’ouverture (facultatif)' : 'Opening text (optional)', align: TextAlign.center),
      ]));
      chapters(part.children);
    }
    chapters(outline.looseChapters);
    for (final item in outline.back) {
      sheet(item.entry.id, matter(item));
    }
    for (var index = 0; index < outline.appendices.length; index++) {
      final item = outline.appendices[index];
      sheet(item.entry.id, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: page.settings.fontSize * 2),
        Text('${bookRoleLabel('APPENDIX', fr).toUpperCase()} ${String.fromCharCode(65 + index)}', style: page.kicker),
        title(item, 1.5, bookRoleLabel('APPENDIX', fr)),
        SizedBox(height: page.settings.fontSize),
        body(item, fr ? 'Écrivez ici…' : 'Write here…'),
      ]));
    }
    Widget heading(String text) => Padding(padding: EdgeInsets.only(top: page.settings.fontSize * 2, bottom: page.settings.fontSize), child: Text(text, style: page.heading(1.5)));
    if (outline.glossary.isNotEmpty) {
      sheet('glossary', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heading(fr ? 'Glossaire' : 'Glossary'),
        for (final term in outline.glossary) ...[
          Text(term.title, style: page.body.copyWith(fontWeight: FontWeight.w700)),
          Padding(padding: EdgeInsets.only(left: page.settings.fontSize * 1.5, bottom: page.settings.fontSize * .6), child: BookRichText(text: term.text, page: page, indent: false)),
        ],
      ]));
    }
    if (outline.sources.isNotEmpty) {
      Widget line(BookNode item) {
        final texts = item.values('TEXT');
        final author = texts.isNotEmpty ? texts[0] : '', year = texts.length > 1 ? texts[1] : '', publisher = texts.length > 2 ? texts[2] : '';
        return Padding(padding: const EdgeInsets.only(bottom: 6), child: Text.rich(TextSpan(style: page.body, children: [
          if (author.isNotEmpty) TextSpan(text: '$author${year.isNotEmpty ? ' ($year)' : ''}. '),
          TextSpan(text: item.title, style: const TextStyle(fontStyle: FontStyle.italic)),
          TextSpan(text: publisher.isNotEmpty ? '. $publisher.' : '.'),
        ])));
      }
      sheet('sources', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (consulted.isNotEmpty) ...[heading(fr ? 'Bibliographie' : 'Bibliography'), ...consulted.map(line)],
        if (cited.isNotEmpty) ...[heading(fr ? 'Références bibliographiques' : 'References'), ...cited.map(line)],
      ]));
    }
    if (outline.indexTerms.isNotEmpty) {
      sheet('index', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heading('Index'),
        for (final item in outline.indexTerms)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: page.paper.line))),
            child: Row(children: [Expanded(child: Text(item.term, style: page.body)), Text(item.chapters.isEmpty ? '—' : '${fr ? 'chap.' : 'ch.'} ${item.chapters.join(', ')}', style: page.body.copyWith(color: page.paper.muted))]),
          ),
      ]));
    }
    final backCover = cover?.values('LONG_TEXT').lastOrNull ?? '';
    if (backCover.isNotEmpty) sheet('back-cover', center: true, tint: Color.alphaBlend(const Color(0x1A6944A8), page.paper.paper), BookRichText(text: backCover, page: page, indent: false));
    return Column(children: sheets);
  }
}

void scrollToBookSheet(BookPageContext page, String id) {
  final target = page.keys[id]?.currentContext;
  if (target != null) Scrollable.ensureVisible(target, duration: MediaQuery.of(target).disableAnimations ? Duration.zero : const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
}

class _CoverImage extends StatefulWidget {
  const _CoverImage({required this.node, required this.page});
  final BookNode node;
  final BookPageContext page;
  @override
  State<_CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<_CoverImage> {
  Uint8List? bytes;

  @override
  void initState() {
    super.initState();
    widget.page.loadImage(widget.node).then((value) { if (mounted) setState(() => bytes = value); });
  }

  @override
  Widget build(BuildContext context) => bytes == null
      ? const SizedBox.shrink()
      : ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.memory(bytes!, fit: BoxFit.cover, height: 260, width: double.infinity, errorBuilder: (_, _, _) => const SizedBox.shrink()));
}

/// Values sent back to the API with one field replaced (removed when empty).
Map<String, String> bookValuesWith(BrainyEntry entry, String fieldId, String value) => {
      for (final item in entry.values.entries) if (item.key != fieldId) item.key: item.value,
      if (value.trim().isNotEmpty) fieldId: value,
    };
