import 'dart:io';
import 'dart:typed_data';

import 'package:brainy/tile_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _url = 'https://tile.openstreetmap.org/3/4/2.png';

void main() {
  late Directory folder;
  late DateTime now;
  var online = true;
  var requests = 0;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('brainy-tiles');
    now = DateTime.utc(2026, 11, 10, 12);
    online = true;
    requests = 0;
  });
  tearDown(() => folder.delete(recursive: true));

  TileCache cache() => TileCache(
    directory: () async => folder,
    clock: () => now,
    client: MockClient((request) async {
      requests++;
      if (!online) throw const SocketException('offline');
      expect(request.headers['User-Agent'], 'Brainy test');
      return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200, headers: {'cache-control': 'max-age=86400, stale-if-error=604800'});
    }),
  );
  Future<Uint8List> load(TileCache tiles) => tiles.load(_url, const {'User-Agent': 'Brainy test'});

  test('reads the server rules, with OpenStreetMap-like defaults', () {
    const policy = TilePolicy(86400, 604800);
    expect(TilePolicy.parse('max-age=87228, stale-while-revalidate=604800, stale-if-error=604800').maxAge, 87228);
    expect(TilePolicy.parse(null).staleIfError, 604800);
    expect(policy.use(3600), TileUse.fresh);
    expect(policy.use(2 * 86400), TileUse.offlineOnly);
    expect(policy.use(9 * 86400), TileUse.expired);
    expect(TileCache.fileName(_url), '3_4_2.png');
  });

  test('a fresh tile is served without a request, a seen tile survives offline for a week', () async {
    final tiles = cache();
    expect(await load(tiles), [1, 2, 3]);
    expect(requests, 1);
    now = now.add(const Duration(hours: 2));
    expect(await load(tiles), [1, 2, 3]);
    expect(requests, 1, reason: 'fresh tiles need no request');
    online = false;
    now = now.add(const Duration(days: 3));
    expect(await load(tiles), [1, 2, 3], reason: 'stale-if-error allows the seen tile offline');
    now = now.add(const Duration(days: 7));
    await expectLater(load(tiles), throwsA(isA<SocketException>()), reason: 'past a week the tile is not shown');
  });

  test('a tile never seen is not available offline', () async {
    online = false;
    await expectLater(load(cache()), throwsA(isA<SocketException>()));
  });
}
