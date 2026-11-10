import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Map tiles already seen stay available offline (T38/2). Nothing is fetched
/// ahead: the OpenStreetMap tile policy forbids bulk downloads. Each tile
/// keeps the server's own rules: fresh for `max-age`, then refreshed from the
/// network; when the network fails, still shown for `stale-if-error`.
/// Same rules as `brainy_web_app/lib/tile-cache.ts`.
const maxCachedTiles = 2000;

@immutable
class TilePolicy {
  const TilePolicy(this.maxAge, this.staleIfError);

  /// Seconds from a Cache-Control header; one day fresh and a week on error when it says nothing.
  factory TilePolicy.parse(String? cacheControl) {
    int seconds(String name, int fallback) {
      final match = RegExp('(?:^|,)\\s*$name=(\\d+)', caseSensitive: false).firstMatch(cacheControl ?? '');
      return match == null ? fallback : int.parse(match.group(1)!);
    }
    return TilePolicy(seconds('max-age', 86400), seconds('stale-if-error', 604800));
  }

  final int maxAge;
  final int staleIfError;

  /// What a cached tile of [ageSeconds] may still be used for.
  TileUse use(double ageSeconds) => ageSeconds <= maxAge
      ? TileUse.fresh
      : ageSeconds <= maxAge + staleIfError
      ? TileUse.offlineOnly
      : TileUse.expired;
}

enum TileUse { fresh, offlineOnly, expired }

/// Where tiles are written; replaced in tests.
typedef TileDirectory = Future<Directory> Function();
Future<Directory> _defaultDirectory() async => Directory('${(await getApplicationCacheDirectory()).path}${Platform.pathSeparator}osm-tiles');

class TileCache {
  TileCache({TileDirectory? directory, http.Client? client, DateTime Function()? clock})
    : _directory = directory ?? _defaultDirectory,
      _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  static final shared = TileCache();

  final TileDirectory _directory;
  final http.Client _client;
  final DateTime Function() _clock;
  int _writes = 0;

  /// "https://tile.openstreetmap.org/3/4/2.png" → "3_4_2.png".
  static String fileName(String url) => Uri.parse(url).pathSegments.join('_');

  /// Tile bytes from the cache when allowed, else from the network; throws when neither works.
  Future<Uint8List> load(String url, Map<String, String> headers) async {
    final folder = await _directory();
    final file = File('${folder.path}${Platform.pathSeparator}${fileName(url)}');
    final meta = File('${file.path}.meta');
    Uint8List? cached;
    var use = TileUse.expired;
    if (await file.exists() && await meta.exists()) {
      final lines = (await meta.readAsString()).split('\n');
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(int.tryParse(lines.first) ?? 0);
      use = TilePolicy.parse(lines.length > 1 ? lines[1] : null).use(_clock().difference(fetchedAt).inMilliseconds / 1000);
      if (use != TileUse.expired) cached = await file.readAsBytes();
    }
    if (cached != null && use == TileUse.fresh) return cached;
    try {
      final response = await _client.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw HttpException('Tile ${response.statusCode}', uri: Uri.parse(url));
      await folder.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      await meta.writeAsString('${_clock().millisecondsSinceEpoch}\n${response.headers['cache-control'] ?? ''}');
      if (++_writes % 50 == 0) unawaited(_trim(folder));
      return response.bodyBytes;
    } catch (_) {
      if (cached != null && use == TileUse.offlineOnly) return cached;
      rethrow;
    }
  }

  /// Keeps the most recently written [maxCachedTiles] tiles.
  Future<void> _trim(Directory folder) async {
    try {
      final tiles = await folder.list().where((item) => item is File && !item.path.endsWith('.meta')).cast<File>().toList();
      if (tiles.length <= maxCachedTiles) return;
      final dated = [for (final tile in tiles) (tile, await tile.lastModified())]..sort((a, b) => a.$2.compareTo(b.$2));
      for (final (tile, _) in dated.take(tiles.length - maxCachedTiles)) {
        await tile.delete();
        final meta = File('${tile.path}.meta');
        if (await meta.exists()) await meta.delete();
      }
    } catch (_) {
      // A full or locked cache only means tiles are fetched again.
    }
  }
}

/// A map tile read through [TileCache].
@immutable
class CachedTileImage extends ImageProvider<CachedTileImage> {
  const CachedTileImage(this.url, {this.headers = const {}, this.cache});

  final String url;
  final Map<String, String> headers;
  final TileCache? cache;

  @override
  Future<CachedTileImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CachedTileImage key, ImageDecoderCallback decode) => MultiFrameImageStreamCompleter(
    codec: (cache ?? TileCache.shared).load(url, headers).then((bytes) async => decode(await ui.ImmutableBuffer.fromUint8List(bytes))),
    scale: 1,
    debugLabel: url,
  );

  @override
  bool operator ==(Object other) => other is CachedTileImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
