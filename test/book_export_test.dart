import 'package:brainy/collection_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('book export follows the written order and preserves linked notes', () {
    final chapter = {
      'id': 'chapter',
      'name': 'Chapter',
      'fields': [
        {'id': 'chapter-title', 'name': 'Title', 'kind': 'TITLE'},
        {'id': 'chapter-order', 'name': 'Order', 'kind': 'NUMBER'},
        {'id': 'chapter-text', 'name': 'Text', 'kind': 'LONG_TEXT'},
      ],
    };
    final scene = {
      'id': 'scene',
      'name': 'Scene',
      'fields': [
        {'id': 'scene-title', 'name': 'Title', 'kind': 'TITLE'},
        {'id': 'scene-order', 'name': 'Order', 'kind': 'NUMBER'},
        {'id': 'scene-text', 'name': 'Text', 'kind': 'LONG_TEXT'},
      ],
    };
    final note = {
      'id': 'note',
      'name': 'Note',
      'fields': [
        {'id': 'note-title', 'name': 'Title', 'kind': 'TITLE'},
        {'id': 'note-text', 'name': 'Text', 'kind': 'LONG_TEXT'},
      ],
    };
    Map<String, dynamic> entry(
      String id,
      String formatId,
      String titleField,
      String title,
      String textField,
      String text, {
      String? orderField,
      String? order,
    }) => {
      'id': id,
      'formatId': formatId,
      'createdAt': '2026-10-24T10:00:00.000Z',
      'updatedAt': '2026-10-24T10:00:00.000Z',
      'values': [
        {'fieldId': titleField, 'value': title},
        {'fieldId': textField, 'value': text},
        if (orderField != null) {'fieldId': orderField, 'value': order},
      ],
    };
    final transfer = BrainyTransfer({
      'brainyExportVersion': 1,
      'collection': {
        'id': 'book',
        'name': 'My book',
        'formats': [chapter, scene, note],
      },
      'entries': [
        entry(
          'note-1',
          'note',
          'note-title',
          'Research note',
          'note-text',
          'A useful detail',
        ),
        entry(
          'chapter-2',
          'chapter',
          'chapter-title',
          'Later',
          'chapter-text',
          'Second chapter',
          orderField: 'chapter-order',
          order: '2',
        ),
        entry(
          'scene-1',
          'scene',
          'scene-title',
          'First scene',
          'scene-text',
          'A quiet beginning',
          orderField: 'scene-order',
          order: '1.1',
        ),
        entry(
          'chapter-1',
          'chapter',
          'chapter-title',
          'Beginning',
          'chapter-text',
          'First chapter',
          orderField: 'chapter-order',
          order: '1',
        ),
      ],
      'links': [
        {
          'fromSourceId': 'chapter-1',
          'toSourceId': 'note-1',
          'label': 'research',
        },
      ],
    });

    final output = transfer.bookText(french: false);
    expect(
      output.indexOf('Chapter — Beginning'),
      lessThan(output.indexOf('Scene — First scene')),
    );
    expect(
      output.indexOf('Scene — First scene'),
      lessThan(output.indexOf('Chapter — Later')),
    );
    expect(
      output.indexOf('Chapter — Later'),
      lessThan(output.indexOf('Note — Research note')),
    );
    expect(output, contains('First chapter'));
    expect(output, contains('research: Research note'));
  });
}
