import 'dart:convert';
import 'dart:typed_data';

import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/large_file_api.dart';
import 'package:brainy/large_file_attachment_field.dart';
import 'package:brainy/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth extends AuthApi {
  final calls = <Map<String, dynamic>>[];
  final timeouts = <Duration>[];

  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    calls.add({'query': query, ...variables});
    timeouts.add(timeout);
    if (query.contains('startLargeFileUpload')) {
      return {
        'startLargeFileUpload': {
          'id': 'u1',
          'chunkSize': 6 * 1024 * 1024,
          'partCount': 3,
          'receivedParts': [1],
          'state': 'UPLOADING',
        },
      };
    }
    if (query.contains('uploadLargeFilePart')) {
      return {
        'uploadLargeFilePart': {'id': 'u1'},
      };
    }
    if (query.contains('completeLargeFileUpload')) {
      return {
        'completeLargeFileUpload': {'state': 'COMPLETE'},
      };
    }
    throw StateError('unexpected $query');
  }
}

Uint8List _file() {
  final bytes = Uint8List(13 * 1024 * 1024 + 5);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = (i * 31 + 7) & 255;
  }
  return bytes;
}

void main() {
  test('SHA-256 matches the standard vectors', () {
    expect(
      sha256Hex(<int>[]),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('a resumed upload sends only missing parts and the same fingerprint as the API and web', () async {
    final auth = _FakeAuth();
    final api = LargeFileApi(CollectionsApi(auth));
    final file = _file();
    // Arrives in uneven pieces, like a real file stream.
    final stream = Stream<List<int>>.fromIterable([
      for (var offset = 0; offset < file.length; offset += 1000003)
        file.sublist(offset, (offset + 1000003).clamp(0, file.length)),
    ]);
    final progress = <int>[];
    final id = await api.upload(
      'c1',
      'scan.tif',
      file.length,
      stream,
      onProgress: (sent, total, resumed) {
        progress.add(sent);
        expect(resumed, isTrue);
      },
      isCancelled: () => false,
    );
    expect(id, 'u1');
    final parts = auth.calls
        .where(
          (call) => (call['query'] as String).contains('uploadLargeFilePart'),
        )
        .toList();
    expect(parts.map((call) => call['n']), [
      2,
      3,
    ], reason: 'part 1 was already received');
    expect(parts.last['b'], base64Encode(file.sublist(12 * 1024 * 1024)));
    expect(
      auth.timeouts[auth.calls.indexOf(parts.first)],
      const Duration(minutes: 2),
    );
    // Same value as Node's crypto for this content (see the T44 contract rule).
    expect(
      auth.calls.last['s'],
      '245d19e3b8f8d58209518dbca0a030d4992180d090244eafce8b63ae8a3f287f',
    );
    expect(progress.last, file.length);
  });

  test('a paused upload stops between parts', () async {
    final auth = _FakeAuth();
    var parts = 0;
    final api = LargeFileApi(CollectionsApi(auth));
    final file = _file();
    await expectLater(
      api.upload(
        'c1',
        'scan.tif',
        file.length,
        Stream.value(file),
        onProgress: (_, _, _) => parts++,
        isCancelled: () => parts >= 2,
      ),
      throwsA(isA<LargeFileUploadCancelled>()),
    );
    expect(
      auth.calls.any(
        (call) => (call['query'] as String).contains('completeLargeFileUpload'),
      ),
      isFalse,
    );
  });

  test('sizes and states read naturally in both languages', () {
    expect(formatFileSize(15729417, false), '15.0 MiB');
    expect(formatFileSize(15729417, true), '15,0 Mio');
    expect(largeFileStateLabel('MISSING', true), 'Absent du stockage');
    expect(
      largeFileStateLabel('CORRUPTED', false),
      'Altered: fingerprint differs',
    );
  });
}
