import 'dart:typed_data';

import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAuthApi extends AuthApi {
  Map<String, dynamic>? savedInput;

  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (query.contains('createEntry')) {
      savedInput = variables['input'] as Map<String, dynamic>;
      return {
        'createEntry': {
          'id': 'entry-1',
          'formatId': 'format-1',
          'values': savedInput!['values'],
          'createdAt': '2026-10-21T10:00:00Z',
          'updatedAt': '2026-10-21T10:00:00Z',
        },
      };
    }
    throw StateError('Unexpected request: $query');
  }
}

void main() {
  test('sends each attachment once, with its name and bytes', () async {
    final auth = _RecordingAuthApi();
    await CollectionsApi(auth).saveEntry(
      'collection-1',
      {'file': 'note.txt'},
      formatId: 'format-1',
      attachments: {
        'file': Uint8List.fromList([65, 66, 67]),
      },
    );
    final values = auth.savedInput!['values'] as List<dynamic>;
    expect(values, hasLength(1));
    expect(values.single['fieldId'], 'file');
    expect(values.single['value'], 'note.txt');
    expect(values.single['attachmentBase64'], 'QUJD');
  });
}
