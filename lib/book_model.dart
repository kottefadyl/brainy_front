// T47: book view model. Pure functions (outline, light Markdown) and the small API it needs.
import 'collections_api.dart';

const bookRoles = ['COVER', 'TITLE_PAGE', 'DEDICATION', 'EPIGRAPH', 'FOREWORD', 'PREFACE', 'ACKNOWLEDGEMENTS', 'INTRODUCTION', 'PART', 'CHAPTER', 'SECTION', 'SUBSECTION', 'CONCLUSION', 'AFTERWORD', 'APPENDIX', 'TERM', 'SOURCE'];
const frontRoles = ['COVER', 'TITLE_PAGE', 'DEDICATION', 'EPIGRAPH', 'FOREWORD', 'PREFACE', 'ACKNOWLEDGEMENTS', 'INTRODUCTION'];
const backSingles = ['CONCLUSION', 'AFTERWORD'];
const singleRoles = [...frontRoles, ...backSingles];
const childRole = {'PART': 'CHAPTER', 'CHAPTER': 'SECTION', 'SECTION': 'SUBSECTION'};
const pageWidthMm = {'A5': 148.0, 'A4': 210.0, 'POCKET': 110.0};
const pageHeightMm = {'A5': 210.0, 'A4': 297.0, 'POCKET': 178.0};
const bookFonts = ['SERIF', 'GARAMOND', 'SANS', 'MONO'];

String bookRoleLabel(String role, bool french) => (french
        ? const {'COVER': 'Couverture', 'TITLE_PAGE': 'Page de titre', 'DEDICATION': 'Dédicace', 'EPIGRAPH': 'Épigraphe', 'FOREWORD': 'Avant-propos', 'PREFACE': 'Préface', 'ACKNOWLEDGEMENTS': 'Remerciements', 'INTRODUCTION': 'Introduction', 'PART': 'Partie', 'CHAPTER': 'Chapitre', 'SECTION': 'Section', 'SUBSECTION': 'Sous-section', 'CONCLUSION': 'Conclusion', 'AFTERWORD': 'Postface', 'APPENDIX': 'Annexe', 'TERM': 'Terme', 'SOURCE': 'Source'}
        : const {'COVER': 'Cover', 'TITLE_PAGE': 'Title page', 'DEDICATION': 'Dedication', 'EPIGRAPH': 'Epigraph', 'FOREWORD': 'Foreword', 'PREFACE': 'Preface', 'ACKNOWLEDGEMENTS': 'Acknowledgements', 'INTRODUCTION': 'Introduction', 'PART': 'Part', 'CHAPTER': 'Chapter', 'SECTION': 'Section', 'SUBSECTION': 'Subsection', 'CONCLUSION': 'Conclusion', 'AFTERWORD': 'Afterword', 'APPENDIX': 'Appendix', 'TERM': 'Term', 'SOURCE': 'Source'})[role] ??
    role;

String bookFontLabel(String font, bool french) => switch (font) {
      'GARAMOND' => 'Garamond',
      'SANS' => french ? 'Moderne sans empattements' : 'Modern sans serif',
      'MONO' => french ? 'Machine à écrire' : 'Typewriter',
      _ => french ? 'Classique à empattements' : 'Classic serif',
    };

class BookSettings {
  const BookSettings({this.enabled = true, this.bodyFont = 'SERIF', this.headingFont = 'SERIF', this.fontSize = 16, this.lineHeight = 1.6, this.paragraphSpacing = 0.8, this.firstLineIndent = 1.5, this.marginMm = 20, this.textAlign = 'JUSTIFY', this.pageSize = 'A5', this.showRuler = true, this.chapterOnNewPage = true, this.roles = const {}});
  final bool enabled;
  final String bodyFont, headingFont, textAlign, pageSize;
  final double fontSize, lineHeight, paragraphSpacing, firstLineIndent, marginMm;
  final bool showRuler, chapterOnNewPage;
  /// Data format id -> book role.
  final Map<String, String> roles;

  factory BookSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BookSettings(enabled: false);
    double number(String key, double fallback) => (json[key] as num?)?.toDouble() ?? fallback;
    return BookSettings(
      enabled: json['enabled'] as bool? ?? false,
      bodyFont: json['bodyFont'] as String? ?? 'SERIF',
      headingFont: json['headingFont'] as String? ?? 'SERIF',
      fontSize: number('fontSize', 16),
      lineHeight: number('lineHeight', 1.6),
      paragraphSpacing: number('paragraphSpacing', 0.8),
      firstLineIndent: number('firstLineIndent', 1.5),
      marginMm: number('marginMm', 20),
      textAlign: json['textAlign'] as String? ?? 'JUSTIFY',
      pageSize: json['pageSize'] as String? ?? 'A5',
      showRuler: json['showRuler'] as bool? ?? true,
      chapterOnNewPage: json['chapterOnNewPage'] as bool? ?? true,
      roles: {for (final item in (json['roles'] as List<dynamic>? ?? const [])) (item as Map<String, dynamic>)['formatId'] as String: item['role'] as String},
    );
  }

  Map<String, dynamic> toInput() => {'enabled': enabled, 'bodyFont': bodyFont, 'headingFont': headingFont, 'fontSize': fontSize, 'lineHeight': lineHeight, 'paragraphSpacing': paragraphSpacing, 'firstLineIndent': firstLineIndent, 'marginMm': marginMm, 'textAlign': textAlign, 'pageSize': pageSize, 'showRuler': showRuler, 'chapterOnNewPage': chapterOnNewPage};
  Map<String, dynamic> toJson() => {...toInput(), 'roles': [for (final item in roles.entries) {'formatId': item.key, 'role': item.value}]};

  BookSettings copyWith({bool? enabled, String? bodyFont, String? headingFont, double? fontSize, double? lineHeight, double? paragraphSpacing, double? firstLineIndent, double? marginMm, String? textAlign, String? pageSize, bool? showRuler, bool? chapterOnNewPage}) => BookSettings(
        enabled: enabled ?? this.enabled, bodyFont: bodyFont ?? this.bodyFont, headingFont: headingFont ?? this.headingFont, fontSize: fontSize ?? this.fontSize, lineHeight: lineHeight ?? this.lineHeight,
        paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing, firstLineIndent: firstLineIndent ?? this.firstLineIndent, marginMm: marginMm ?? this.marginMm, textAlign: textAlign ?? this.textAlign,
        pageSize: pageSize ?? this.pageSize, showRuler: showRuler ?? this.showRuler, chapterOnNewPage: chapterOnNewPage ?? this.chapterOnNewPage, roles: roles);
}

class BookNode {
  BookNode(this.entry, this.format, this.role);
  final BrainyEntry entry;
  final BrainyFormat format;
  final String role;
  final children = <BookNode>[];
  int number = 0;

  BrainyField? field(String kind, [int index = 0]) {
    final matches = format.fields.where((item) => item.kind.name.toUpperCase() == kind.replaceAll('_', '')).toList();
    return index < matches.length ? matches[index] : null;
  }

  String value(String kind, [int index = 0]) {
    final target = field(kind, index);
    return target == null ? '' : entry.values[target.id] ?? '';
  }

  List<String> values(String kind) => [for (final item in format.fields.where((field) => field.kind.name.toUpperCase() == kind.replaceAll('_', ''))) entry.values[item.id] ?? ''];
  String get title => value('TITLE');
  String get text => value('LONG_TEXT');
  double? get order => double.tryParse(value('NUMBER'));
}

class BookOutline {
  BookOutline({required this.front, required this.parts, required this.looseChapters, required this.unplaced, required this.back, required this.appendices, required this.glossary, required this.sources, required this.indexTerms, required this.formatByRole, required this.hiddenFormats});
  final List<BookNode> front, parts, looseChapters, unplaced, back, appendices, glossary, sources;
  final List<({String term, List<int> chapters})> indexTerms;
  final Map<String, BrainyFormat> formatByRole;
  final List<BrainyFormat> hiddenFormats;
  List<BookNode> get chapters => [...parts.expand((part) => part.children), ...looseChapters];
  bool get isEmpty => [front, parts, looseChapters, unplaced, back, appendices, glossary, sources].every((list) => list.isEmpty);
}

int _byOrder(BookNode a, BookNode b) {
  final first = a.order ?? double.maxFinite, second = b.order ?? double.maxFinite;
  final compared = first.compareTo(second);
  return compared != 0 ? compared : a.entry.createdAt.compareTo(b.entry.createdAt);
}

/// Relations are `{fromEntryId, toEntryId, kind}` maps; a PARENT relation goes from the child to its parent.
BookOutline buildBookOutline(BrainyCollection collection, BookSettings settings, List<BrainyEntry> entries, List<Map<String, dynamic>> relations) {
  final formatByRole = <String, BrainyFormat>{};
  for (final item in settings.roles.entries) {
    final format = collection.formats.where((candidate) => candidate.id == item.key).firstOrNull;
    if (format != null) formatByRole[item.value] = format;
  }
  final nodes = <String, BookNode>{};
  for (final entry in entries) {
    final format = collection.formats.where((item) => item.id == entry.formatId).firstOrNull;
    final role = format == null ? null : settings.roles[format.id];
    if (format != null && role != null) nodes[entry.id] = BookNode(entry, format, role);
  }
  final parentOf = <String, String>{};
  for (final relation in relations) {
    final from = relation['fromEntryId'] as String?, to = relation['toEntryId'] as String?;
    if (relation['kind'] == 'PARENT' && nodes.containsKey(from) && nodes.containsKey(to)) parentOf[from!] = to!;
  }
  final placed = <String>{};
  for (final child in nodes.values) {
    final parent = nodes[parentOf[child.entry.id]];
    if (parent != null && childRole[parent.role] == child.role) {
      parent.children.add(child);
      placed.add(child.entry.id);
    }
  }
  for (final node in nodes.values) {
    node.children.sort(_byOrder);
  }
  List<BookNode> ofRole(String role) => nodes.values.where((item) => item.role == role).toList()..sort(_byOrder);
  final parts = ofRole('PART');
  final looseChapters = ofRole('CHAPTER').where((item) => !placed.contains(item.entry.id)).toList();
  for (var index = 0; index < parts.length; index++) {
    parts[index].number = index + 1;
  }
  var chapterNumber = 0;
  final chapters = [...parts.expand((part) => part.children), ...looseChapters];
  for (final chapter in chapters) {
    chapter.number = ++chapterNumber;
    for (var index = 0; index < chapter.children.length; index++) {
      final section = chapter.children[index]..number = index + 1;
      for (var subIndex = 0; subIndex < section.children.length; subIndex++) {
        section.children[subIndex].number = subIndex + 1;
      }
    }
  }
  String subtree(BookNode node) => [node.title, node.text, ...node.children.map(subtree)].join('\n').toLowerCase();
  final chapterTexts = [for (final chapter in chapters) (number: chapter.number, text: subtree(chapter))];
  final terms = ofRole('TERM')..sort((a, b) => a.title.compareTo(b.title));
  bool flag(BookNode node, int index) => node.value('BOOLEAN', index) == 'true';
  String sourceKey(BookNode node) => node.value('TEXT').isNotEmpty ? node.value('TEXT') : node.title;
  return BookOutline(
    front: [for (final role in frontRoles) ...ofRole(role).take(1)],
    parts: parts,
    looseChapters: looseChapters,
    unplaced: [...ofRole('SECTION'), ...ofRole('SUBSECTION')].where((item) => !placed.contains(item.entry.id)).toList(),
    back: [for (final role in backSingles) ...ofRole(role).take(1)],
    appendices: ofRole('APPENDIX'),
    glossary: terms.where((item) => flag(item, 0)).toList(),
    sources: ofRole('SOURCE')..sort((a, b) => sourceKey(a).compareTo(sourceKey(b))),
    indexTerms: [
      for (final term in terms.where((item) => flag(item, 1) && item.title.trim().isNotEmpty))
        (term: term.title, chapters: [for (final chapter in chapterTexts) if (chapter.text.contains(term.title.toLowerCase())) chapter.number]),
    ],
    formatByRole: formatByRole,
    hiddenFormats: collection.formats.where((format) => !settings.roles.containsKey(format.id)).toList(),
  );
}

String romanNumeral(int value) {
  const table = [(1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'), (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')];
  var rest = value;
  final result = StringBuffer();
  for (final (size, letters) in table) {
    while (rest >= size) {
      result.write(letters);
      rest -= size;
    }
  }
  return result.toString();
}

/// Light Markdown kept as plain text in the entry: **bold**, *italic*, # heading, > quote, *** scene break.
typedef InlineRun = ({String text, bool bold, bool italic});
List<InlineRun> inlineRuns(String text) {
  final runs = <InlineRun>[];
  var last = 0;
  for (final match in RegExp(r'(\*\*[^*\n]+\*\*|\*[^*\n]+\*)').allMatches(text)) {
    if (match.start > last) runs.add((text: text.substring(last, match.start), bold: false, italic: false));
    final token = match.group(0)!;
    runs.add(token.startsWith('**') ? (text: token.substring(2, token.length - 2), bold: true, italic: false) : (text: token.substring(1, token.length - 1), bold: false, italic: true));
    last = match.end;
  }
  if (last < text.length) runs.add((text: text.substring(last), bold: false, italic: false));
  return runs;
}

typedef TextBlock = ({String kind, String text});
List<TextBlock> textBlocks(String text) => [
      for (final chunk in text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n')).map((item) => item.trim()).where((item) => item.isNotEmpty))
        if (RegExp(r'^(\*\s*){3}$|^-{3,}$').hasMatch(chunk))
          (kind: 'break', text: '')
        else if (chunk.startsWith('# '))
          (kind: 'heading', text: chunk.substring(2))
        else if (chunk.startsWith('> '))
          (kind: 'quote', text: chunk.split('\n').map((line) => line.replaceFirst(RegExp(r'^>\s?'), '')).join('\n'))
        else
          (kind: 'paragraph', text: chunk),
    ];

/// Wraps the selection with a Markdown marker; returns the new text and selection.
({String text, int start, int end}) wrapSelection(String value, int start, int end, String marker) {
  final from = start < 0 ? value.length : start, to = end < 0 ? value.length : end;
  final selected = from == to ? (marker == '**' ? 'bold' : 'italic') : value.substring(from, to);
  return (text: value.substring(0, from) + marker + selected + marker + value.substring(to), start: from + marker.length, end: from + marker.length + selected.length);
}

({String text, int caret}) prefixParagraph(String value, int caret, String prefix) {
  final at = caret < 0 ? value.length : caret;
  final lineStart = at == 0 ? 0 : value.lastIndexOf('\n', at - 1) + 1;
  final already = value.startsWith(prefix, lineStart);
  return already
      ? (text: value.substring(0, lineStart) + value.substring(lineStart + prefix.length), caret: (at - prefix.length).clamp(0, value.length))
      : (text: value.substring(0, lineStart) + prefix + value.substring(lineStart), caret: at + prefix.length);
}

extension BookApi on CollectionsApi {
  Future<BookSettings> setBookView(String collectionId, BookSettings settings) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$id:String!,\$input:BookViewSettingsInput!){setBookView(collectionId:\$id,input:\$input){bookView{enabled bodyFont headingFont fontSize lineHeight paragraphSpacing firstLineIndent marginMm textAlign pageSize showRuler chapterOnNewPage roles{formatId role}}}}',
      {'id': collectionId, 'input': settings.toInput()},
    );
    return BookSettings.fromJson((data['setBookView'] as Map<String, dynamic>)['bookView'] as Map<String, dynamic>?);
  }

  Future<List<Map<String, dynamic>>> parentRelations(String collectionId) async {
    final data = await auth.authenticatedRequest('query(\$id:String!){collectionParentRelations(collectionId:\$id){id fromEntryId toEntryId kind}}', {'id': collectionId});
    return (data['collectionParentRelations'] as List<dynamic>).cast<Map<String, dynamic>>();
  }
}

String bookError(Object error, bool french) {
  final message = error.toString().replaceFirst(RegExp(r'^(Exception|ApiException|AuthException): '), '');
  if (!french) return message;
  if (message.contains('can only have one entry')) return 'Ce format de données n’accepte qu’une seule entrée. Modifiez celle qui existe.';
  if (message.contains('can only be placed under')) return 'Cette partie se place seulement sous : ${message.split(': ').last}.';
  if (message.contains('only available in collections created from the Book template')) return 'La vue livre n’est disponible que dans les collections créées depuis le modèle Livre.';
  return message;
}
