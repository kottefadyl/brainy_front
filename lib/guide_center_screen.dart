// T51: "Guide and training" screens. Content is generated from scripts/guide/content.mjs (guide_content.dart).
import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'guide_content.dart';

Future<void> openGuideCenter(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GuideCenterScreen()));

const _icons = <String, IconData>{
  'compass': Icons.explore_outlined,
  'folder': Icons.folder_open_outlined,
  'shapes': Icons.category_outlined,
  'pencil': Icons.edit_outlined,
  'layout': Icons.grid_view_outlined,
  'template': Icons.dashboard_customize_outlined,
  'chart': Icons.insights_outlined,
  'boxes': Icons.inventory_2_outlined,
  'warehouse': Icons.warehouse_outlined,
  'users': Icons.group_outlined,
  'shield': Icons.verified_user_outlined,
  'database': Icons.storage_outlined,
};

/// Tile colors by category, as on the web: violet = structure, teal = governance, green = analysis and operations.
(Color, Color) _tile(String icon, bool dark) => switch (icon) {
      'shapes' || 'template' || 'boxes' => dark ? (const Color(0x29A78BFA), const Color(0xFFC4B5FD)) : (const Color(0xFFF1ECFE), const Color(0xFF5B3CC4)),
      'users' || 'shield' || 'database' => dark ? (const Color(0x242DD4BF), const Color(0xFF5EEAD4)) : (const Color(0xFFE3F6F4), const Color(0xFF0E6E66)),
      'chart' || 'warehouse' => dark ? (const Color(0x2134D27B), const Color(0xFF5EDC8C)) : (const Color(0xFFE9F7EF), const Color(0xFF157F3B)),
      _ => dark ? (BrainyColors.darkAccentSoft, BrainyColors.darkAccent) : (BrainyColors.lightAccentSoft, BrainyColors.lightAccent),
    };

String _pick(GuideText text, bool fr) => fr ? text.fr : text.en;
String _plain(String text) => text.replaceAll('**', '').toLowerCase();

/// Chapters whose texts contain every word of [query] in the chosen language.
List<GuideChapter> searchGuide(String query, bool fr) {
  final words = _plain(query).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return guideChapters;
  return guideChapters.where((chapter) {
    final haystack = _plain([chapter.title, chapter.summary, for (final section in chapter.sections) ...[section.title, section.text]].map((text) => _pick(text, fr)).join(' '));
    return words.every(haystack.contains);
  }).toList();
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon, {this.size = 44});
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _tile(icon, Theme.of(context).brightness == Brightness.dark);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Icon(_icons[icon] ?? Icons.explore_outlined, color: foreground, size: size * .5),
    );
  }
}

class GuideCenterScreen extends StatefulWidget {
  const GuideCenterScreen({super.key});

  @override
  State<GuideCenterScreen> createState() => _GuideCenterScreenState();
}

class _GuideCenterScreenState extends State<GuideCenterScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = searchGuide(_search.text, fr);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Guide et formation' : 'Guide and training')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 840 ? 2 : 1;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.dividerColor),
                      gradient: LinearGradient(colors: [scheme.primary.withValues(alpha: .10), scheme.surface], stops: const [0, .7]),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const _IconTile('compass', size: 52),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(fr ? 'Guide et formation' : 'Guide and training', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                              fr
                                  ? 'Apprenez Brainy pas à pas : de la première collection aux analyses, aux objets et au partage. Chaque chapitre se lit en quelques minutes.'
                                  : 'Learn Brainy step by step: from your first collection to analysis, objects and sharing. Each chapter takes a few minutes to read.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: fr ? 'Rechercher dans le guide (ex. unité, stock, partage)' : 'Search the guide (e.g. unit, stock, sharing)',
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: fr ? 'Effacer la recherche' : 'Clear search',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Text(fr ? 'Aucun chapitre ne correspond à cette recherche.' : 'No chapter matches this search.', textAlign: TextAlign.center),
                        TextButton(onPressed: () => setState(_search.clear), child: Text(fr ? 'Effacer la recherche' : 'Clear search')),
                      ]),
                    )
                  else
                    for (var row = 0; row < visible.length; row += columns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (var column = 0; column < columns; column++) ...[
                              if (column > 0) const SizedBox(width: 12),
                              Expanded(child: row + column < visible.length ? _ChapterCard(chapter: visible[row + column], fr: fr) : const SizedBox.shrink()),
                            ],
                          ]),
                        ),
                      ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.fr});
  final GuideChapter chapter;
  final bool fr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final number = guideChapters.indexOf(chapter) + 1;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GuideChapterScreen(index: number - 1))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _IconTile(chapter.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((fr ? 'Chapitre $number' : 'Chapter $number').toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w600, letterSpacing: .5)),
                const SizedBox(height: 4),
                Text(_pick(chapter.title, fr), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_pick(chapter.summary, fr), style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.45)),
              ]),
            ),
            Padding(padding: const EdgeInsets.only(top: 10), child: Icon(Icons.arrow_forward_rounded, size: 18, color: muted)),
          ]),
        ),
      ),
    );
  }
}

class GuideChapterScreen extends StatelessWidget {
  const GuideChapterScreen({super.key, required this.index});
  final int index;

  void _go(BuildContext context, int target) =>
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => GuideChapterScreen(index: target)));

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final chapter = guideChapters[index];
    final language = fr ? 'fr' : 'en';
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Chapitre ${index + 1} sur ${guideChapters.length}' : 'Chapter ${index + 1} of ${guideChapters.length}')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _IconTile(chapter.icon, size: 52),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Semantics(header: true, child: Text(_pick(chapter.title, fr), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                      const SizedBox(height: 6),
                      Text(_pick(chapter.summary, fr), style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),
                const Divider(height: 1),
                for (final section in chapter.sections) ...[
                  const SizedBox(height: 24),
                  Semantics(header: true, child: Text(_pick(section.title, fr), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
                  const SizedBox(height: 10),
                  GuideRichText(_pick(section.text, fr)),
                  if (section.image != null) ...[
                    const SizedBox(height: 12),
                    _Screenshot(asset: 'assets/guide/$language/${section.image}.jpg', label: _pick(section.title, fr), fr: fr),
                  ],
                ],
                const SizedBox(height: 28),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, children: [
                  if (index > 0)
                    OutlinedButton.icon(
                      onPressed: () => _go(context, index - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(_pick(guideChapters[index - 1].title, fr), overflow: TextOverflow.ellipsis),
                    ),
                  if (index < guideChapters.length - 1)
                    FilledButton.tonalIcon(
                      onPressed: () => _go(context, index + 1),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      iconAlignment: IconAlignment.end,
                      label: Text('${fr ? 'Suivant' : 'Next'} : ${_pick(guideChapters[index + 1].title, fr)}', overflow: TextOverflow.ellipsis),
                    )
                  else
                    FilledButton.tonal(onPressed: () => Navigator.of(context).pop(), child: Text(fr ? 'Tous les chapitres' : 'All chapters')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Screenshot extends StatelessWidget {
  const _Screenshot({required this.asset, required this.label, required this.fr});
  final String asset, label;
  final bool fr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        button: true,
        label: fr ? 'Agrandir la capture : $label' : 'Enlarge screenshot: $label',
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => Dialog.fullscreen(
                backgroundColor: Colors.black87,
                child: Stack(children: [
                  Positioned.fill(child: InteractiveViewer(maxScale: 4, child: Center(child: Image.asset(asset, semanticLabel: label)))),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SafeArea(
                      child: IconButton.filledTonal(
                        tooltip: fr ? 'Fermer' : 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            child: Image.asset(asset, width: double.infinity, fit: BoxFit.fitWidth, excludeFromSemantics: true),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(fr ? 'Exemple avec des données de démonstration' : 'Example with demo data', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}

/// Renders the guide markup: blank line = paragraph, "- " = bullet, "1. " = numbered step, **bold**.
class GuideRichText extends StatelessWidget {
  const GuideRichText(this.text, {super.key});
  final String text;

  static List<InlineSpan> _inline(String text) => [
        for (final (index, part) in text.split('**').indexed)
          if (part.isNotEmpty) TextSpan(text: part, style: index.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(height: 1.6);
    final marker = theme.colorScheme.primary;
    final children = <Widget>[];
    for (final line in text.split('\n')) {
      final bullet = RegExp(r'^- (.*)$').firstMatch(line);
      final step = RegExp(r'^(\d+)\. (.*)$').firstMatch(line);
      if (line.trim().isEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 8));
        continue;
      }
      if (bullet != null || step != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 24,
              child: Text(step != null ? '${step.group(1)}.' : '•', style: style?.copyWith(color: marker, fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text.rich(TextSpan(children: _inline(step?.group(2) ?? bullet!.group(1)!)), style: style)),
          ]),
        ));
      } else {
        children.add(Text.rich(TextSpan(children: _inline(line)), style: style));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
