import 'package:brainy/auth_api.dart';
import 'package:brainy/book_model.dart';
import 'package:brainy/book_view_screen.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// T47: Book template outline, light Markdown and the book view screen.
BrainyFormat _format(String id, String name, List<(String, BrainyFieldKind)> fields, {String color = '#EEF5FF'}) =>
    BrainyFormat(id: id, name: name, color: color, fields: [for (final (fieldId, kind) in fields) BrainyField(id: fieldId, name: fieldId, kind: kind)]);

final _formats = [
  _format('cover', 'Couverture', [('cover-title', BrainyFieldKind.title), ('cover-subtitle', BrainyFieldKind.text), ('cover-author', BrainyFieldKind.text), ('cover-back', BrainyFieldKind.longText)]),
  _format('preface', 'Préface', [('preface-title', BrainyFieldKind.title), ('preface-text', BrainyFieldKind.longText)], color: '#FFF5EB'),
  _format('part', 'Partie', [('part-title', BrainyFieldKind.title), ('part-order', BrainyFieldKind.number), ('part-text', BrainyFieldKind.longText)], color: '#EFEFFD'),
  _format('chapter', 'Chapitre', [('chapter-title', BrainyFieldKind.title), ('chapter-order', BrainyFieldKind.number), ('chapter-text', BrainyFieldKind.longText)], color: '#EFF8FF'),
  _format('section', 'Section', [('section-title', BrainyFieldKind.title), ('section-order', BrainyFieldKind.number), ('section-text', BrainyFieldKind.longText)], color: '#F1F8ED'),
  _format('subsection', 'Sous-section', [('sub-title', BrainyFieldKind.title), ('sub-order', BrainyFieldKind.number), ('sub-text', BrainyFieldKind.longText)], color: '#F7FBEA'),
  _format('term', 'Terme', [('term-title', BrainyFieldKind.title), ('term-text', BrainyFieldKind.longText), ('term-glossary', BrainyFieldKind.boolean), ('term-index', BrainyFieldKind.boolean)], color: '#FBF1E8'),
  _format('notes', 'Notes', [('note-title', BrainyFieldKind.title)], color: '#F0F8F9'),
];
const _roles = {'cover': 'COVER', 'preface': 'PREFACE', 'part': 'PART', 'chapter': 'CHAPTER', 'section': 'SECTION', 'subsection': 'SUBSECTION', 'term': 'TERM'};
final _bookView = {...const BookSettings().toInput(), 'roles': [for (final item in _roles.entries) {'formatId': item.key, 'role': item.value}]};
final _collection = BrainyCollection(id: 'book', name: 'Le Jardin', fields: _formats.first.fields, formats: _formats, templateId: 'book', bookView: _bookView);

Map<String, dynamic> _entry(String id, String formatId, Map<String, String> values, {int minute = 0}) => {
      'id': id,
      'formatId': formatId,
      'createdAt': DateTime.utc(2026, 11, 11, 9, minute).toIso8601String(),
      'updatedAt': DateTime.utc(2026, 11, 11, 9, minute).toIso8601String(),
      'values': [for (final item in values.entries) {'fieldId': item.key, 'value': item.value}],
    };

final _entries = [
  _entry('cover-1', 'cover', {'cover-title': 'Le Jardin des heures', 'cover-author': 'Claire Martin', 'cover-back': 'Un été.'}),
  _entry('preface-1', 'preface', {'preface-title': 'Préface', 'preface-text': 'Ce livre est né d’un carnet.'}),
  _entry('part-1', 'part', {'part-title': 'L’été', 'part-order': '1'}),
  _entry('chapter-2', 'chapter', {'chapter-title': 'Le carnet', 'chapter-order': '2', 'chapter-text': 'Les pages étaient jaunies.'}, minute: 1),
  _entry('chapter-1', 'chapter', {'chapter-title': 'Le retour', 'chapter-order': '1', 'chapter-text': 'Le **matin**, la maison dormait.\n\nElle descendit au *jardin*.\n\n> Il faut cultiver notre jardin.\n\n***\n\nPlus tard.'}, minute: 2),
  _entry('chapter-loose', 'chapter', {'chapter-title': 'Hors partie', 'chapter-order': '1'}, minute: 3),
  _entry('section-1', 'section', {'section-title': 'La maison', 'section-order': '1', 'section-text': 'Les volets bleus.'}),
  _entry('section-orphan', 'section', {'section-title': 'À placer', 'section-order': '9'}),
  _entry('sub-1', 'subsection', {'sub-title': 'L’horloge', 'sub-order': '1', 'sub-text': 'Arrêtée à quatre heures.'}),
  _entry('term-1', 'term', {'term-title': 'Carnet', 'term-text': 'Petit cahier.', 'term-glossary': 'true', 'term-index': 'true'}),
  _entry('note-1', 'notes', {'note-title': 'Idée'}),
];
final _relations = [
  {'id': 'r1', 'fromEntryId': 'chapter-1', 'toEntryId': 'part-1', 'kind': 'PARENT'},
  {'id': 'r2', 'fromEntryId': 'chapter-2', 'toEntryId': 'part-1', 'kind': 'PARENT'},
  {'id': 'r3', 'fromEntryId': 'section-1', 'toEntryId': 'chapter-1', 'kind': 'PARENT'},
  {'id': 'r4', 'fromEntryId': 'sub-1', 'toEntryId': 'section-1', 'kind': 'PARENT'},
];

class _Auth extends AuthApi {
  final requests = <String>[];
  final variables = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    requests.add(query);
    this.variables.add(variables);
    if (query.contains('collectionEntries')) return {'collectionEntries': _entries};
    if (query.contains('collectionParentRelations')) return {'collectionParentRelations': _relations};
    if (query.contains('createEntry')) {
      final input = variables['input'] as Map<String, dynamic>;
      return {'createEntry': _entry('new-entry', input['formatId'] as String, {for (final value in input['values'] as List<dynamic>) (value as Map<String, dynamic>)['fieldId'] as String: value['value'] as String})};
    }
    if (query.contains('createCollectionRelation')) return {'createCollectionRelation': {'id': 'r-new'}};
    if (query.contains('setBookView')) return {'setBookView': {'bookView': _bookView}};
    throw StateError('Unexpected request: $query');
  }
}

void main() {
  List<BrainyEntry> entries() => [for (final item in _entries) BrainyEntry.fromJson(item)];

  test('outline follows roles, parents and order, and numbers chapters across parts', () {
    final outline = buildBookOutline(_collection, BookSettings.fromJson(_bookView), entries(), _relations);
    expect(outline.front.map((item) => item.role), ['COVER', 'PREFACE']);
    expect(outline.parts.single.children.map((item) => item.title), ['Le retour', 'Le carnet']);
    expect(outline.looseChapters.single.number, 3, reason: 'chapters are numbered across parts');
    expect(outline.parts.single.children.first.children.single.children.single.title, 'L’horloge');
    expect(outline.unplaced.single.title, 'À placer');
    expect(outline.glossary.single.title, 'Carnet');
    expect(outline.indexTerms.single.chapters, [2], reason: 'the term appears in chapter 2 only');
    expect(outline.hiddenFormats.map((item) => item.name), ['Notes']);
  });

  test('light Markdown keeps plain text in the entry', () {
    expect(inlineRuns('Le **matin** et le *soir*').map((run) => (run.text, run.bold, run.italic)), [('Le ', false, false), ('matin', true, false), (' et le ', false, false), ('soir', false, true)]);
    expect(textBlocks('Un\n\n# Titre\n\n> Citation\n\n***\n\nFin').map((block) => block.kind), ['paragraph', 'heading', 'quote', 'break', 'paragraph']);
    expect(wrapSelection('Le matin', 3, 8, '**'), (text: 'Le **matin**', start: 5, end: 10));
    expect(prefixParagraph('Un\nDeux', 5, '> ').text, 'Un\n> Deux');
    expect(prefixParagraph('Un\n> Deux', 6, '> ').text, 'Un\nDeux');
    expect(romanNumeral(14), 'XIV');
  });

  test('settings round-trip and keep the roles out of the input', () {
    final settings = BookSettings.fromJson(_bookView).copyWith(bodyFont: 'GARAMOND', fontSize: 18);
    expect(settings.roles['chapter'], 'CHAPTER');
    expect(settings.toInput().containsKey('roles'), isFalse);
    expect(BookSettings.fromJson(settings.toJson()).bodyFont, 'GARAMOND');
  });

  for (final (label, width, dark) in [('phone, light', 390.0, false), ('phone, dark', 390.0, true), ('desktop, light', 1280.0, false), ('desktop, dark', 1280.0, true)]) {
    testWidgets('book view renders pages and outline ($label)', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _Auth();
      await tester.pumpWidget(MaterialApp(
        theme: dark ? BrainyTheme.dark : BrainyTheme.light,
        home: BookViewScreen(api: CollectionsApi(auth), collection: _collection, initial: BookSettings.fromJson(_bookView), french: true, onOpenEntry: (_) async {}),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Table des matières'), findsOneWidget);
      expect(find.text('CHAPITRE 1'), findsOneWidget);
      expect(find.text('Glossaire'), findsWidgets);
      if (width < 1000) {
        await tester.tap(find.byTooltip('Plan du livre'));
        await tester.pumpAndSettle();
      }
      expect(find.text('À PLACER'), findsNothing);
      expect(find.text('À placer'), findsWidgets);
      final outlineList = find.descendant(of: find.byType(width < 1000 ? Drawer : Row).first, matching: find.byType(Scrollable)).first;
      // T47/3: the owner places the other data formats (here Notes) from the outline.
      await tester.scrollUntilVisible(find.text('Formats de données dans le livre'), 300, scrollable: outlineList);
      expect(find.text('Formats de données dans le livre'), findsOneWidget);
      await tester.scrollUntilVisible(find.widgetWithText(TextButton, 'Section').first, -300, scrollable: outlineList);

      await tester.tap(find.widgetWithText(TextButton, 'Section').first);
      await tester.pumpAndSettle();
      final created = auth.variables[auth.requests.indexWhere((query) => query.contains('createEntry'))];
      expect((created['input'] as Map<String, dynamic>)['formatId'], 'section');
      final relation = auth.variables[auth.requests.indexWhere((query) => query.contains('createCollectionRelation'))];
      expect(relation['kind'], 'PARENT');
      expect(relation['fromEntryId'], 'new-entry');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('layout settings save after a short pause', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _Auth();
    await tester.pumpWidget(MaterialApp(theme: BrainyTheme.light, home: BookViewScreen(api: CollectionsApi(auth), collection: _collection, initial: BookSettings.fromJson(_bookView), french: true, onOpenEntry: (_) async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mise en page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('À gauche'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final saved = auth.variables[auth.requests.indexWhere((query) => query.contains('setBookView'))];
    expect((saved['input'] as Map<String, dynamic>)['textAlign'], 'LEFT');
  });

  testWidgets('launcher appears only for Book collections', (tester) async {
    final auth = _Auth();
    Future<void> pump(BrainyCollection collection) => tester.pumpWidget(MaterialApp(home: Scaffold(body: BookViewLauncher(api: CollectionsApi(auth), collection: collection, french: true, onOpenEntry: (_) async {}, onChanged: () async {}))));
    await pump(_collection);
    expect(find.text('Ouvrir le livre'), findsOneWidget);
    await pump(BrainyCollection(id: 'notes', name: 'Notes', fields: _formats.last.fields, formats: [_formats.last]));
    expect(find.text('Ouvrir le livre'), findsNothing);
  });
}
