import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/brainy_theme.dart';
import 'package:brainy/osm_map.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Native review of the map with synthetic points and real OpenStreetMap tiles:
/// no account, no API. `flutter build windows --debug --no-pub --target
/// tool/map_preview.dart --dart-define=VISUAL_OUTPUT=C:/absolute/path`.
void main() => runApp(const _Preview());

const _markers = [
  MapMarker(id: 'p0', title: 'Chantier Nord', latitude: 50.63, longitude: 3.06),
  MapMarker(id: 'p1', title: 'Tournée Paris', latitude: 48.8566, longitude: 2.3522, accuracy: 12),
  MapMarker(id: 'p2', title: 'Enquête Lyon', latitude: 45.764, longitude: 4.8357),
  MapMarker(id: 'p3', title: 'Dépôt Marseille', latitude: 43.2965, longitude: 5.3698),
];

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  var _dark = false;
  var _width = 320.0;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _save(String name, Duration wait) async {
    await Future<void>.delayed(wait);
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    const requested = String.fromEnvironment('VISUAL_OUTPUT');
    final directory = Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/brainy-map');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  }

  void _tapMarker(String id) {
    Element? found;
    void visit(Element element) {
      if (element.widget.key == ValueKey('map-marker-$id')) found = element;
      element.visitChildElements(visit);
    }

    (_boundary.currentContext! as Element).visitChildElements(visit);
    final box = found!.renderObject! as RenderBox;
    final position = box.localToGlobal(box.size.center(Offset.zero));
    GestureBinding.instance
      ..handlePointerEvent(PointerDownEvent(pointer: 77, position: position))
      ..handlePointerEvent(PointerUpEvent(pointer: 77, position: position));
  }

  Future<void> _capture() async {
    const storage = FlutterSecureStorage();
    await Future<void>.delayed(const Duration(seconds: 3));
    for (final width in Platform.isAndroid ? [320.0, 390.0] : [320.0, 1000.0]) {
      for (final dark in [false, true]) {
        final tag = '${width.toInt()}-${dark ? 'dark' : 'light'}';
        await storage.delete(key: 'brainy:map:osm-tiles');
        setState(() {
          _width = width;
          _dark = dark;
          _generation++;
        });
        await _save('$tag-consent', const Duration(milliseconds: 900));
        await storage.write(key: 'brainy:map:osm-tiles', value: 'on');
        setState(() => _generation++);
        await _save('$tag-tiles', const Duration(seconds: 4));
        _tapMarker('p1');
        await _save('$tag-popup', const Duration(milliseconds: 500));
      }
    }
    debugPrint('MAP_REVIEW_COMPLETE ${Directory.systemTemp.path}');
    if (!Platform.isAndroid) exit(0);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    themeAnimationDuration: Duration.zero,
    theme: _dark ? BrainyTheme.dark : BrainyTheme.light,
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _boundary,
        child: SizedBox(
          width: _width,
          height: 560,
          child: Material(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: OsmMap(
                key: ValueKey(_generation),
                markers: _markers,
                french: true,
                formatColor: '#EDF9F3',
                selected: const ['p3'],
                onOpenEntry: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
