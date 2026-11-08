// T44 — large attachments by reference: resumable chunked upload, signed download link, integrity check.
// The file is read as a byte stream and only one 6 MiB part is held in memory at a time.
import 'dart:convert';
import 'dart:typed_data';

import 'collections_api.dart';
import 'sha256.dart';

const largeFileThreshold = 2097152;

class LargeFileSession {
  const LargeFileSession({
    required this.id,
    required this.chunkSize,
    required this.partCount,
    required this.receivedParts,
    required this.state,
  });
  final String id;
  final int chunkSize;
  final int partCount;
  final Set<int> receivedParts;
  final String state;
  factory LargeFileSession.fromJson(Map<String, dynamic> json) =>
      LargeFileSession(
        id: json['id'] as String,
        chunkSize: (json['chunkSize'] as num).toInt(),
        partCount: (json['partCount'] as num).toInt(),
        receivedParts: {
          for (final part in json['receivedParts'] as List<dynamic>)
            (part as num).toInt(),
        },
        state: json['state'] as String,
      );
}

class LargeFileUploadCancelled implements Exception {
  const LargeFileUploadCancelled();
}

/// File fingerprint shared with the API and the web client: SHA-256 of the part hashes, one per line.
String largeFileManifest(List<String> partHashes) =>
    sha256Hex(utf8.encode(partHashes.join('\n')));

class LargeFileApi {
  const LargeFileApi(this.api);
  final CollectionsApi api;
  static const _fields = 'id chunkSize partCount receivedParts state';

  Future<Map<String, dynamic>> _call(
    String query,
    Map<String, dynamic> variables, {
    Duration timeout = const Duration(seconds: 12),
  }) => api.auth.authenticatedRequest(query, variables, timeout: timeout);

  Future<LargeFileSession> start(
    String collectionId,
    String fileName,
    int size,
    String mimeType,
  ) async {
    final data = await _call(
      'mutation(\$c:String!,\$i:StartLargeFileUploadInput!){startLargeFileUpload(collectionId:\$c,input:\$i){$_fields}}',
      {
        'c': collectionId,
        'i': {'fileName': fileName, 'mimeType': mimeType, 'size': size},
      },
    );
    return LargeFileSession.fromJson(
      data['startLargeFileUpload'] as Map<String, dynamic>,
    );
  }

  Future<void> part(
    String uploadId,
    int number,
    Uint8List bytes,
    String hash,
  ) => _call(
    'mutation(\$u:String!,\$n:Int!,\$b:String!,\$s:String!){uploadLargeFilePart(uploadId:\$u,partNumber:\$n,base64:\$b,sha256:\$s){id}}',
    {'u': uploadId, 'n': number, 'b': base64Encode(bytes), 's': hash},
    timeout: const Duration(minutes: 2),
  );

  Future<String> complete(String uploadId, String hash) async {
    final data = await _call(
      'mutation(\$u:String!,\$s:String!){completeLargeFileUpload(uploadId:\$u,sha256:\$s){state}}',
      {'u': uploadId, 's': hash},
    );
    return (data['completeLargeFileUpload'] as Map<String, dynamic>)['state']
        as String;
  }

  Future<Uri> link(String entryId, String fieldId) async {
    final data = await _call(
      'query(\$e:String!,\$f:String!){largeFileDownloadLink(entryId:\$e,fieldId:\$f){url}}',
      {'e': entryId, 'f': fieldId},
    );
    return Uri.parse(
      (data['largeFileDownloadLink'] as Map<String, dynamic>)['url'] as String,
    );
  }

  Future<String> verify(String entryId, String fieldId) async {
    final data = await _call(
      'mutation(\$e:String!,\$f:String!){verifyLargeFile(entryId:\$e,fieldId:\$f){state}}',
      {'e': entryId, 'f': fieldId},
    );
    return (data['verifyLargeFile'] as Map<String, dynamic>)['state'] as String;
  }

  /// Sends [file] part by part. Choosing the same file again resumes: received parts are only re-hashed.
  /// [isCancelled] is checked between parts. Returns the large file ID.
  Future<String> upload(
    String collectionId,
    String fileName,
    int size,
    Stream<List<int>> bytes, {
    required void Function(int sent, int total, bool resumed) onProgress,
    required bool Function() isCancelled,
  }) async {
    final session = await start(
      collectionId,
      fileName,
      size,
      _mimeType(fileName),
    );
    final resumed = session.receivedParts.isNotEmpty;
    final hashes = <String>[];
    final buffer = BytesBuilder(copy: false);
    var sent = 0;
    var number = 0;
    Future<void> flush() async {
      if (isCancelled()) throw const LargeFileUploadCancelled();
      final bytes = buffer.takeBytes();
      number += 1;
      final hash = sha256Hex(bytes);
      hashes.add(hash);
      if (!session.receivedParts.contains(number)) {
        for (var attempt = 1; ; attempt++) {
          try {
            await part(session.id, number, bytes, hash);
            break;
          } catch (_) {
            if (attempt >= 3 || isCancelled()) rethrow;
            await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
          }
        }
      }
      sent += bytes.length;
      onProgress(sent, size, resumed);
    }

    await for (final chunk in bytes) {
      var offset = 0;
      while (offset < chunk.length) {
        final take = (session.chunkSize - buffer.length).clamp(
          0,
          chunk.length - offset,
        );
        buffer.add(
          chunk is Uint8List
              ? Uint8List.sublistView(chunk, offset, offset + take)
              : chunk.sublist(offset, offset + take),
        );
        offset += take;
        if (buffer.length == session.chunkSize) await flush();
      }
    }
    if (buffer.length > 0) await flush();
    if (number != session.partCount) {
      throw StateError('The file changed while it was being sent');
    }
    if (await complete(session.id, largeFileManifest(hashes)) != 'COMPLETE') {
      throw StateError('Upload did not complete');
    }
    return session.id;
  }

  static String _mimeType(String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    return const {
          'pdf': 'application/pdf',
          'zip': 'application/zip',
          'gz': 'application/gzip',
          'csv': 'text/csv',
          'json': 'application/json',
          'tif': 'image/tiff',
          'tiff': 'image/tiff',
          'png': 'image/png',
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'mp4': 'video/mp4',
          'mov': 'video/quicktime',
        }[extension] ??
        'application/octet-stream';
  }
}
