import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data_format_colors.dart';
import 'design_tokens.dart';
import 'map_math.dart';

const _tilesPreference = 'brainy:map:osm-tiles';
// The OpenStreetMap tile policy asks every application to identify itself.
const _userAgent = 'Brainy/1.0 (Flutter map client)';
const _pinSize = 44.0;

ImageProvider<Object> _networkTile(String url) => NetworkImage(url, headers: const {'User-Agent': _userAgent});

/// Claims a pointer at once: dragging the map must not scroll the page around it.
class _EagerScaleRecognizer extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class MapMarker {
  const MapMarker({required this.id, required this.title, required this.latitude, required this.longitude, this.accuracy});

  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final double? accuracy;
}

/// Slippy map. No tile is requested until the person turns the OpenStreetMap
/// background on (product rule 13); without it the points stay fully usable.
class OsmMap extends StatefulWidget {
  const OsmMap({
    super.key,
    required this.markers,
    required this.french,
    required this.onOpenEntry,
    this.formatColor,
    this.selected = const [],
    this.tileProvider = _networkTile,
    this.storage = const FlutterSecureStorage(),
  });

  final List<MapMarker> markers;
  final bool french;
  final String? formatColor;
  final List<String> selected;
  final void Function(String id) onOpenEntry;
  final ImageProvider<Object> Function(String url) tileProvider;
  final FlutterSecureStorage storage;

  @override
  State<OsmMap> createState() => _OsmMapState();
}

class _OsmMapState extends State<OsmMap> with SingleTickerProviderStateMixin {
  final _focus = FocusNode(debugLabel: 'map');
  final _markerFocus = <String, FocusNode>{};
  final _reported = <String>{};
  final _succeeded = <String>{};
  late final AnimationController _animation;
  MapView _view = const MapView(0.5, 0.5, 0);
  MapView _from = const MapView(0.5, 0.5, 0);
  MapView _to = const MapView(0.5, 0.5, 0);
  Size _size = Size.zero;
  bool _needsFit = true;
  bool _tilesOn = false;
  bool _showFocus = false;
  int? _tileZ;
  int? _previousZ;
  int _failed = 0;
  int _retry = 0;
  double _moved = 0;
  double _gestureZoom = 0;
  String? _openId;
  String? _roveId;
  Timer? _levelTimer;
  Timer? _backdropTimer;

  String t(String fr, String en) => widget.french ? fr : en;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() {
        setState(() => _view = MapView.lerp(_from, _to, Curves.easeOutCubic.transform(_animation.value)));
      });
    _readPreference();
  }

  Future<void> _readPreference() async {
    try {
      final saved = await widget.storage.read(key: _tilesPreference);
      if (mounted && saved == 'on') setState(() => _tilesOn = true);
    } catch (_) {
      // Without a readable choice, the background stays off.
    }
  }

  @override
  void didUpdateWidget(covariant OsmMap old) {
    super.didUpdateWidget(old);
    final key = _markersKey(widget.markers);
    if (key != _markersKey(old.markers)) {
      _needsFit = true;
      _openId = null;
    }
  }

  String _markersKey(List<MapMarker> markers) => markers.map((item) => '${item.id}:${item.latitude}:${item.longitude}').join('|');

  @override
  void dispose() {
    _levelTimer?.cancel();
    _backdropTimer?.cancel();
    _animation.dispose();
    _focus.dispose();
    for (final node in _markerFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  List<WorldPoint> get _worldPoints => [for (final item in widget.markers) projectToWorld(item.latitude, item.longitude)];

  MapView get _clamped => clampView(_view, _size.width, _size.height);

  void _scheduleLevel() {
    final target = tileLevel(_clamped.zoom);
    if (target == _tileZ) {
      _levelTimer?.cancel();
      return;
    }
    if (_levelTimer?.isActive ?? false) _levelTimer!.cancel();
    // Tiles of a new level are only requested once the zoom pauses.
    _levelTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() {
        _previousZ = _tileZ;
        _tileZ = tileLevel(_clamped.zoom);
        _resetFailures();
      });
      _backdropTimer?.cancel();
      _backdropTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _previousZ = null);
      });
    });
  }

  void _resetFailures() {
    _failed = 0;
    _reported.clear();
  }

  void _setView(MapView next) {
    _animation.stop();
    setState(() => _view = next);
    _scheduleLevel();
  }

  void _animateTo(MapView target) {
    if (_failed > 0) {
      _retry++;
      _resetFailures();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _setView(target);
      return;
    }
    _from = _clamped;
    _to = target;
    _animation.forward(from: 0);
    _levelTimer?.cancel();
    Future<void>.delayed(const Duration(milliseconds: 230), () {
      if (mounted) _scheduleLevel();
    });
  }

  void _zoomBy(double amount) {
    final view = _clamped;
    _animateTo(zoomAround(view, view.zoom + amount, _size.width / 2, _size.height / 2, _size.width, _size.height));
  }

  void _fitAll() {
    setState(() => _openId = null);
    _animateTo(fitBounds(_worldPoints, _size.width, _size.height));
  }

  void _closePopup() {
    final id = _openId;
    setState(() => _openId = null);
    if (id != null) _markerFocus[id]?.requestFocus();
  }

  Future<void> _changeTiles(bool enabled) async {
    setState(() {
      _tilesOn = enabled;
      _resetFailures();
    });
    try {
      if (enabled) {
        await widget.storage.write(key: _tilesPreference, value: 'on');
      } else {
        await widget.storage.delete(key: _tilesPreference);
      }
    } catch (_) {
      // The choice then lasts for this visit only.
    }
  }

  KeyEventResult _onMapKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    const step = 80.0;
    final view = _clamped;
    if (key == LogicalKeyboardKey.arrowLeft) _animateTo(panBy(view, step, 0));
    if (key == LogicalKeyboardKey.arrowRight) _animateTo(panBy(view, -step, 0));
    if (key == LogicalKeyboardKey.arrowUp) _animateTo(panBy(view, 0, step));
    if (key == LogicalKeyboardKey.arrowDown) _animateTo(panBy(view, 0, -step));
    if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add || key == LogicalKeyboardKey.numpadAdd) _zoomBy(1);
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) _zoomBy(-1);
    final handled = <LogicalKeyboardKey>{
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.equal,
      LogicalKeyboardKey.add,
      LogicalKeyboardKey.numpadAdd,
      LogicalKeyboardKey.minus,
      LogicalKeyboardKey.numpadSubtract,
    }.contains(key);
    if (handled) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.escape && _openId != null) {
      _closePopup();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onMarkerKey(KeyEvent event, int index, List<_Placed> onScreen) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final step = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown
        ? 1
        : key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowUp
        ? -1
        : 0;
    if (step == 0) return KeyEventResult.ignored;
    final next = onScreen[(index + step + onScreen.length) % onScreen.length].marker.id;
    setState(() => _roveId = next);
    _markerFocus[next]?.requestFocus();
    return KeyEventResult.handled;
  }

  void _onTileLoaded(String key) {
    if (!_succeeded.add(key) || _failed == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(_resetFailures);
    });
  }

  void _onTileFailed(String key) {
    if (!_reported.add(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failed++);
    });
  }

  Widget _tile(MapTile tile, {required bool report}) => Positioned(
    key: ValueKey('${tile.key}#$_retry'),
    left: tile.left,
    top: tile.top,
    width: tile.width,
    height: tile.height,
    child: Image(
      image: widget.tileProvider(tile.url),
      fit: BoxFit.fill,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sync) {
        if (frame != null && report) _onTileLoaded(tile.key);
        return child;
      },
      errorBuilder: (context, error, stack) {
        if (report) _onTileFailed(tile.key);
        return const SizedBox.shrink();
      },
    ),
  );

  Widget _surface(MapView view, List<MapTile> tiles, List<MapTile> backdrop, ChartColors colors) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
          final scroll = resolved as PointerScrollEvent;
          final current = _clamped;
          _setView(zoomAround(current, current.zoom - scroll.scrollDelta.dy / 400, scroll.localPosition.dx, scroll.localPosition.dy, _size.width, _size.height));
        });
      },
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _EagerScaleRecognizer: GestureRecognizerFactoryWithHandlers<_EagerScaleRecognizer>(
            _EagerScaleRecognizer.new,
            (recognizer) {
              recognizer
                ..onStart = (details) {
                  _animation.stop();
                  _gestureZoom = _clamped.zoom;
                  _moved = 0;
                  _focus.requestFocus();
                }
                ..onUpdate = (details) {
                  _moved += details.focalPointDelta.distance;
                  final current = _clamped;
                  final zoom = details.pointerCount > 1 || details.scale != 1
                      ? _gestureZoom + math.log(details.scale) / math.ln2
                      : current.zoom;
                  final zoomed = zoomAround(current, zoom, details.localFocalPoint.dx, details.localFocalPoint.dy, _size.width, _size.height);
                  _setView(panBy(zoomed, details.focalPointDelta.dx, details.focalPointDelta.dy));
                }
                ..onEnd = (details) {
                  if (_moved < 5 && _openId != null) setState(() => _openId = null);
                };
            },
          ),
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _NeutralBackground(colors)),
            ...backdrop.map((tile) => _tile(tile, report: false)),
            ...tiles.map((tile) => _tile(tile, report: true)),
          ],
        ),
      ),
    );
  }

  Widget _marker(_Placed item, int index, List<_Placed> onScreen, bool tabbable, Color pin) {
    final marker = item.marker;
    final node = _markerFocus.putIfAbsent(marker.id, () => FocusNode(debugLabel: marker.id));
    node.canRequestFocus = true;
    node.skipTraversal = !tabbable;
    final selected = widget.selected.contains(marker.id);
    return Positioned(
      key: ValueKey('map-marker-${marker.id}'),
      left: item.left - _pinSize / 2,
      top: item.top - _pinSize,
      width: _pinSize,
      height: _pinSize,
      child: Semantics(
        button: true,
        label: marker.title,
        child: Focus(
          onKeyEvent: (_, event) => _onMarkerKey(event, index, onScreen),
          skipTraversal: true,
          child: InkWell(
            focusNode: node,
            customBorder: const CircleBorder(),
            onFocusChange: (focused) {
              if (focused) _roveId = marker.id;
            },
            onTap: () => setState(() => _openId = marker.id),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                alignment: Alignment.bottomCenter,
                scale: selected ? 1.2 : (_openId == marker.id ? 1.12 : 1),
                child: CustomPaint(size: const Size(27, 36), painter: _PinPainter(pin, selected)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _control(String label, IconData icon, VoidCallback? onPressed, ChartColors colors) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: IconButton.filledTonal(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: colors.surface,
        foregroundColor: colors.ink,
        side: BorderSide(color: colors.line),
      ),
      icon: Icon(icon, size: 20),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ChartColors.of(theme.brightness);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = (screenHeight * 0.56).clamp(300.0, 480.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) => _map(constraints.biggest, colors, theme.brightness == Brightness.dark),
            ),
          ),
        ),
        if (_tilesOn)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _changeTiles(false),
              child: Text(t('Désactiver le fond de carte', 'Turn off map background')),
            ),
          ),
      ],
    );
  }

  Widget _map(Size size, ChartColors colors, bool dark) {
    _size = size;
    if (_needsFit && size.width > 0) {
      _needsFit = false;
      _view = fitBounds(_worldPoints, size.width, size.height);
      _tileZ = tileLevel(_view.zoom);
      _previousZ = null;
    }
    final view = _clamped;
    final level = _tileZ ?? tileLevel(view.zoom);
    final tiles = _tilesOn ? visibleTiles(view, level, size.width, size.height) : const <MapTile>[];
    final backdrop = _tilesOn && _previousZ != null && _previousZ != level ? visibleTiles(view, _previousZ!, size.width, size.height) : const <MapTile>[];
    final offline = _tilesOn && _failed >= math.min(3, tiles.isEmpty ? 1 : tiles.length);
    final pin = DataFormatColors.marker(widget.formatColor ?? '', dark && !(_tilesOn && !offline));
    final onScreen = <_Placed>[];
    for (final marker in widget.markers) {
      final at = toScreen(projectToWorld(marker.latitude, marker.longitude), view, size.width, size.height);
      if (at.left > -_pinSize && at.left < size.width + _pinSize && at.top > -_pinSize && at.top < size.height + _pinSize) {
        onScreen.add(_Placed(marker, at.left, at.top));
      }
    }
    final tabbable = onScreen.any((item) => item.marker.id == _roveId) ? _roveId : onScreen.firstOrNull?.marker.id;
    final open = onScreen.where((item) => item.marker.id == _openId).firstOrNull;
    return Semantics(
      container: true,
      label: t('Carte, ${widget.markers.length} points', 'Map, ${widget.markers.length} points'),
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onMapKey,
        onFocusChange: (focused) => setState(
          () => _showFocus = focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _surface(view, tiles, backdrop, colors),
            for (var index = 0; index < onScreen.length; index++)
              _marker(onScreen[index], index, onScreen, onScreen[index].marker.id == tabbable, pin),
            if (_showFocus)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                ),
              ),
            if (open != null)
              CustomSingleChildLayout(
                delegate: _PopupLayout(Offset(open.left, open.top)),
                child: _popup(open.marker, colors),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                children: [
                  _control(t('Zoom avant', 'Zoom in'), Icons.add, () => _zoomBy(1), colors),
                  _control(t('Zoom arrière', 'Zoom out'), Icons.remove, () => _zoomBy(-1), colors),
                  _control(t('Afficher tous les points', 'Show all points'), Icons.fit_screen_outlined, widget.markers.isEmpty ? null : _fitAll, colors),
                ],
              ),
            ),
            if (!_tilesOn)
              Positioned(left: 8, bottom: 8, right: 64, child: _consent(colors)),
            if (offline)
              Positioned(
                left: 6,
                bottom: 4,
                child: _Label(t('Fond de carte hors-ligne', 'Map background offline'), color: colors.muted, background: colors.surface),
              ),
            if (_tilesOn && !offline)
              Positioned(
                right: 4,
                bottom: 4,
                child: Semantics(
                  link: true,
                  child: GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication),
                    child: const _Label('© OpenStreetMap', color: BrainyColors.lightInk, background: Color(0xE6FFFFFF)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _consent(ChartColors colors) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 340),
    child: Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.line)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Le fond OpenStreetMap transmet à ce service votre adresse IP et les zones consultées. Vos points restent visibles sans lui.', 'The OpenStreetMap background sends this service your IP address and the areas you view. Your points stay visible without it.'),
              style: TextStyle(color: colors.ink, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 6),
            FilledButton.tonal(
              onPressed: () => _changeTiles(true),
              child: Text(t('Activer le fond de carte', 'Turn on map background')),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _popup(MapMarker marker, ChartColors colors) => Material(
    key: const ValueKey('map-popup'),
    color: colors.surface,
    elevation: 6,
    shadowColor: Colors.black45,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.line)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(marker.title, style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600))),
              IconButton(tooltip: t('Fermer', 'Close'), onPressed: _closePopup, icon: const Icon(Icons.close, size: 18)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${marker.latitude}, ${marker.longitude}${marker.accuracy == null ? '' : ' ±${marker.accuracy!.toString().replaceFirst(RegExp(r'.0$'), '')} m'}',
              style: TextStyle(color: colors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: () => widget.onOpenEntry(marker.id),
              child: Text(t('Ouvrir la fiche', 'Open entry')),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Placed {
  const _Placed(this.marker, this.left, this.top);

  final MapMarker marker;
  final double left;
  final double top;
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    ),
  );
}

class _PopupLayout extends SingleChildLayoutDelegate {
  const _PopupLayout(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(maxWidth: math.min(260.0, constraints.maxWidth - 16));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (anchor.dx - childSize.width / 2).clamp(8.0, math.max(8.0, size.width - childSize.width - 8)).toDouble();
    final above = anchor.dy - _pinSize - childSize.height - 2;
    return Offset(left, above >= 8 ? above : math.max(8.0, math.min(anchor.dy + 6, size.height - childSize.height - 8)));
  }

  @override
  bool shouldRelayout(covariant _PopupLayout old) => old.anchor != anchor;
}

class _NeutralBackground extends CustomPainter {
  const _NeutralBackground(this.colors);

  final ChartColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Color.alphaBlend(colors.line.withValues(alpha: 0.35), colors.surface));
    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (double x = 64; x < size.width; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 64; y < size.height; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _NeutralBackground old) => old.colors != colors;
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.color, this.selected);

  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 24;
    final path = Path()
      ..moveTo(12 * unit, 31 * unit)
      ..cubicTo(12 * unit, 31 * unit, 23 * unit, 18.5 * unit, 23 * unit, 11.5 * unit)
      ..arcToPoint(Offset(1 * unit, 11.5 * unit), radius: Radius.circular(11 * unit), largeArc: true, clockwise: false)
      ..cubicTo(1 * unit, 18.5 * unit, 12 * unit, 31 * unit, 12 * unit, 31 * unit)
      ..close();
    canvas.drawShadow(path, Colors.black, 2, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * unit,
    );
    canvas.drawCircle(Offset(12 * unit, 11.5 * unit), 4 * unit, Paint()..color = selected ? const Color(0xFFC8202F) : Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) => old.color != color || old.selected != selected;
}
