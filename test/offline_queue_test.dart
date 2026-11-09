import 'dart:typed_data';

import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/offline_entry_queue.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReplayApi extends CollectionsApi {
  _ReplayApi() : super(AuthApi());
  final keys = <String>[];
  String? failure;
  Map<String, String>? serverValues;
  @override
  Future<BrainyEntry> saveEntry(String collectionId, Map<String, String> values, {Map<String, Map<String, String>> measures = const {}, String? entryId, String? formatId, Map<String, Uint8List> attachments = const {}, Map<String, String> largeFiles = const {}, String? clientMutationId, DateTime? expectedUpdatedAt}) async {
    keys.add(clientMutationId!);
    if (failure != null) throw AuthApiException(failure!);
    return BrainyEntry(id: entryId ?? 'server-id', values: serverValues ?? values, formatId: formatId, createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('uncertain network response reuses the same key and keeps pending data', () async {
    final queue = OfflineEntryQueue('account-a');
    await queue.enqueue({'id': 'key-1', 'collectionId': 'collection', 'formatId': 'format', 'values': {'title': 'Draft'}, 'status': 'pending'});
    await queue.revise('offline:key-1', {'title': 'Revised draft'});
    final api = _ReplayApi()..failure = 'Could not reach Brainy. Check your connection and try again.';
    expect((await queue.sync(api)).synced, 0);
    expect((await queue.read()).single['values']['title'], 'Revised draft');
    api.failure = null;
    expect((await queue.sync(api)).synced, 1);
    expect(api.keys, ['key-1', 'key-1']);
    expect(await queue.read(), isEmpty);
    expect(await OfflineEntryQueue('account-b').read(), isEmpty);
  });

  test('conflict is preserved for a visible decision', () async {
    final queue = OfflineEntryQueue('account-a');
    await queue.enqueue({'id': 'key-2', 'collectionId': 'collection', 'entryId': 'existing', 'formatId': 'format', 'values': {'title': 'Local edit'}, 'expectedUpdatedAt': '2026-10-28T12:00:00Z', 'status': 'pending'});
    final api = _ReplayApi()..failure = 'This entry changed elsewhere. Review the conflict before syncing';
    expect((await queue.sync(api)).synced, 0);
    expect((await queue.read()).single['status'], 'conflict');
    expect((await queue.read()).single['values']['title'], 'Local edit');
    await queue.discard('key-2');
    expect(await queue.read(), isEmpty);
  });

  test('uncertain create response never drops a newer local revision silently', () async {
    final queue = OfflineEntryQueue('account-a');
    await queue.enqueue({'id': 'key-3', 'collectionId': 'collection', 'formatId': 'format', 'values': {'title': 'Newer local'}, 'status': 'pending'});
    final api = _ReplayApi()..serverValues = {'title': 'Earlier saved'};
    expect((await queue.sync(api)).synced, 0);
    final pending = (await queue.read()).single;
    expect(pending['status'], 'conflict');
    expect(pending['entryId'], 'server-id');
    expect(pending['values']['title'], 'Newer local');
  });
}
