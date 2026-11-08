import 'dart:math' as math;

/// Web Mercator (EPSG:3857) arithmetic for the map, identical to the web client
/// (`brainy_web_app/lib/map-math.ts`). World coordinates run from 0 to 1.
const tileSize = 256.0;
const maxMapZoom = 19.0;
const _maxLatitude = 85.05112878;
const _fitMaxZoom = 15.0;
const _singlePointZoom = 13.0;

class WorldPoint {
  const WorldPoint(this.x, this.y);

  final double x;
  final double y;
}

class MapView {
  const MapView(this.x, this.y, this.zoom);

  final double x;
  final double y;
  final double zoom;

  static MapView lerp(MapView a, MapView b, double t) => MapView(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.zoom + (b.zoom - a.zoom) * t,
  );
}

class MapTile {
  const MapTile({
    required this.key,
    required this.url,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String key;
  final String url;
  final double left;
  final double top;
  final double width;
  final double height;
}

double _log2(double value) => math.log(value) / math.ln2;
double _power2(double value) => math.pow(2, value).toDouble();

WorldPoint projectToWorld(double latitude, double longitude) {
  final bounded = latitude.clamp(-_maxLatitude, _maxLatitude).toDouble();
  final radians = bounded * math.pi / 180;
  return WorldPoint(
    (longitude + 180) / 360,
    (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) / 2,
  );
}

double worldSize(double zoom) => tileSize * _power2(zoom);

/// The closest zoom at which the world still fills the viewport.
double minZoomFor(double width, double height) =>
    math.max(0, _log2(math.max(math.max(width, height), 1) / tileSize));

MapView clampView(MapView view, double width, double height) {
  final zoom = view.zoom.clamp(minZoomFor(width, height), maxMapZoom).toDouble();
  final size = worldSize(zoom);
  double bound(double value, double viewport) {
    final half = viewport / 2 / size;
    return half >= 0.5 ? 0.5 : value.clamp(half, 1 - half).toDouble();
  }

  return MapView(bound(view.x, width), bound(view.y, height), zoom);
}

({double left, double top}) toScreen(WorldPoint point, MapView view, double width, double height) {
  final size = worldSize(view.zoom);
  return (
    left: (point.x - view.x) * size + width / 2,
    top: (point.y - view.y) * size + height / 2,
  );
}

MapView panBy(MapView view, double dx, double dy) {
  final size = worldSize(view.zoom);
  return MapView(view.x - dx / size, view.y - dy / size, view.zoom);
}

/// Changes the zoom while the world point under (left, top) stays under it.
MapView zoomAround(MapView view, double zoom, double left, double top, double width, double height) {
  final size = worldSize(view.zoom);
  final worldX = view.x + (left - width / 2) / size;
  final worldY = view.y + (top - height / 2) / size;
  final next = worldSize(zoom);
  return MapView(worldX - (left - width / 2) / next, worldY - (top - height / 2) / next, zoom);
}

/// The view that contains every point, with room for the marker pins.
MapView fitBounds(List<WorldPoint> points, double width, double height, {double padding = 56}) {
  if (points.isEmpty) return clampView(const MapView(0.5, 0.5, 0), width, height);
  final xs = points.map((point) => point.x);
  final ys = points.map((point) => point.y);
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  double fit(double span, double viewport) => span > 0
      ? _log2(math.max(1, viewport - padding * 2) / (tileSize * span))
      : double.infinity;
  final zoom = math.min(fit(maxX - minX, width), fit(maxY - minY, height));
  return clampView(
    MapView(
      (minX + maxX) / 2,
      (minY + maxY) / 2,
      zoom.isFinite ? math.min(_fitMaxZoom, zoom) : _singlePointZoom,
    ),
    width,
    height,
  );
}

int tileLevel(double zoom) => zoom.round().clamp(0, maxMapZoom.toInt());

String tileUrl(int z, int x, int y) => 'https://tile.openstreetmap.org/$z/$x/$y.png';

/// The tiles of one level that cover the viewport, on whole pixels so that no seam shows.
List<MapTile> visibleTiles(MapView view, int z, double width, double height) {
  final count = 1 << z;
  final world = worldSize(view.zoom);
  final span = world / count;
  int first(double center, double viewport) => ((center * world - viewport / 2) / span).floor();
  int last(double center, double viewport) => ((center * world + viewport / 2) / span).floor();
  final tiles = <MapTile>[];
  for (var y = math.max(0, first(view.y, height)); y <= math.min(count - 1, last(view.y, height)); y++) {
    for (var x = math.max(0, first(view.x, width)); x <= math.min(count - 1, last(view.x, width)); x++) {
      final start = toScreen(WorldPoint(x / count, y / count), view, width, height);
      final end = toScreen(WorldPoint((x + 1) / count, (y + 1) / count), view, width, height);
      final left = start.left.roundToDouble(), top = start.top.roundToDouble();
      tiles.add(
        MapTile(
          key: '$z/$x/$y',
          url: tileUrl(z, x, y),
          left: left,
          top: top,
          width: end.left.roundToDouble() - left,
          height: end.top.roundToDouble() - top,
        ),
      );
    }
  }
  return tiles;
}
