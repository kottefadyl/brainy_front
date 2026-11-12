import 'package:brainy/realtime_sync.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// Real-time sync: quick signals make one reload, my own changes are skipped, a lost access still counts.
void main() {
  test('signals are grouped, own changes ignored, lost access reported', () {
    fakeAsync((async) {
      final reloads = <Set<String>>[];
      final batcher = ChangeBatcher('me', reloads.add);
      batcher.add((collectionId: 'a', by: 'awa', removed: false));
      batcher.add((collectionId: 'a', by: 'awa', removed: false));
      batcher.add((collectionId: 'b', by: 'bruno', removed: false));
      batcher.add((collectionId: 'c', by: 'me', removed: false));
      async.elapse(const Duration(milliseconds: 300));
      expect(reloads, isEmpty, reason: 'still within the grouping delay');
      async.elapse(const Duration(milliseconds: 400));
      expect(reloads, [{'a', 'b'}]);
      batcher.add((collectionId: 'c', by: 'me', removed: true));
      async.elapse(const Duration(seconds: 1));
      expect(reloads.last, {'c'}, reason: 'access ended, even if I made the change');
      batcher.dispose();
    });
  });
}
