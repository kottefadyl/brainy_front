import 'package:brainy/collections_api.dart';
import 'package:brainy/realtime_sync.dart';
import 'package:brainy/workspace_screen.dart';
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

  test('a live update replaces only what changed, adds new shares first, drops lost access', () {
    BrainyCollection c(String id, String name) => BrainyCollection(id: id, name: name, fields: const [], formats: const []);
    final current = [c('a', 'A'), c('b', 'B'), c('d', 'D')];
    final merged = mergeChangedCollections(current, {'b', 'd', 'n'}, [c('b', 'B2'), c('n', 'New')]);
    expect(merged.map((item) => '${item.id}:${item.name}'), ['n:New', 'a:A', 'b:B2']);
  });
}
