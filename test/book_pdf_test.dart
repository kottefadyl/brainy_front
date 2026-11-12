import 'dart:convert';

import 'package:brainy/book_model.dart';
import 'package:brainy/book_pdf.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter_test/flutter_test.dart';

// T47/1: the book as a PDF from the outline and the book view settings.
BrainyFormat _format(String id, List<(String, BrainyFieldKind)> fields) =>
    BrainyFormat(id: id, name: id, color: '#EEF5FF', fields: [for (final (fieldId, kind) in fields) BrainyField(id: fieldId, name: fieldId, kind: kind)]);

BrainyEntry _entry(String id, String formatId, Map<String, String> values) =>
    BrainyEntry(id: id, formatId: formatId, values: values, createdAt: DateTime.utc(2026, 11, 12), updatedAt: DateTime.utc(2026, 11, 12));

void main() {
  test('a book with chapters, a section and an index becomes a PDF of several pages', () async {
    final formats = [
      _format('cover', [('cover-title', BrainyFieldKind.title), ('cover-subtitle', BrainyFieldKind.text), ('cover-author', BrainyFieldKind.text)]),
      _format('chapter', [('chapter-title', BrainyFieldKind.title), ('chapter-order', BrainyFieldKind.number), ('chapter-text', BrainyFieldKind.longText)]),
      _format('section', [('section-title', BrainyFieldKind.title), ('section-order', BrainyFieldKind.number), ('section-text', BrainyFieldKind.longText)]),
      _format('term', [('term-title', BrainyFieldKind.title), ('term-text', BrainyFieldKind.longText), ('term-glossary', BrainyFieldKind.boolean), ('term-index', BrainyFieldKind.boolean)]),
    ];
    const roles = {'cover': 'COVER', 'chapter': 'CHAPTER', 'section': 'SECTION', 'term': 'TERM'};
    final collection = BrainyCollection(id: 'b', name: 'Le Jardin', fields: const [], formats: formats, templateId: 'book');
    final settings = BookSettings(roles: roles, chapterOnNewPage: true);
    final long = List.filled(40, 'Élise ouvrit la fenêtre ; l’odeur des tilleuls entra, « déjà » chaude — c’était l’été… **Toujours**, *jamais*.').join('\n\n');
    final entries = [
      _entry('c', 'cover', {'cover-title': 'Le Jardin des heures', 'cover-author': 'Claire Martin'}),
      _entry('ch1', 'chapter', {'chapter-title': 'Le retour', 'chapter-order': '1', 'chapter-text': '$long\n\n> Il faut cultiver notre jardin.\n\n***\n\n# Plus tard\n\nFin.'}),
      _entry('ch2', 'chapter', {'chapter-title': 'Le carnet', 'chapter-order': '2', 'chapter-text': 'Le carnet était là.'}),
      _entry('s1', 'section', {'section-title': 'La maison', 'section-order': '1', 'section-text': 'Les volets bleus.'}),
      _entry('t1', 'term', {'term-title': 'carnet', 'term-text': 'Petit cahier.', 'term-glossary': 'true', 'term-index': 'true'}),
    ];
    final outline = buildBookOutline(collection, settings, entries, [{'fromEntryId': 's1', 'toEntryId': 'ch1', 'kind': 'PARENT'}]);
    final bytes = await buildBookPdf(outline: outline, settings: settings, bookTitle: 'Le Jardin', french: true);
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text.startsWith('%PDF'), isTrue);
    final pages = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
    expect(pages, greaterThanOrEqualTo(6), reason: 'cover, contents, two chapters on new pages (one long), glossary, index');
  });

  test('typographic signs outside the PDF fonts become plain ones', () {
    expect(pdfSafe('l’été… « œuvre » — 3 %'), "l'été... « oeuvre » - 3 %");
    expect(pdfSafe('数'), '?');
  });
}
