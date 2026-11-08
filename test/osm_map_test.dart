import 'dart:convert';

import 'package:brainy/map_math.dart';
import 'package:brainy/osm_map.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _markers = [
  MapMarker(id: 'p0', title: 'Chantier Nord', latitude: 50.63, longitude: 3.06),
  MapMarker(id: 'p1', title: 'Tournée Paris', latitude: 48.8566, longitude: 2.3522, accuracy: 12),
  MapMarker(id: 'p2', title: 'Enquête Lyon', latitude: 45.764, longitude: 4.8357),
  MapMarker(id: 'p3', title: 'Dépôt Marseille', latitude: 43.2965, longitude: 5.3698),
];

final Uint8List _pixel = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

ImageProvider<Object> _goodTile(String url) => MemoryImage(_pixel);
ImageProvider<Object> _badTile(String url) => NetworkImage(url);

final _requested = <String>[];
ImageProvider<Object> _recordingTile(String url) {
  _requested.add(url);
  return MemoryImage(_pixel);
}

Future<void> _mount(
  WidgetTester tester, {
  double width = 320,
  bool french = true,
  ImageProvider<Object> Function(String) tile = _goodTile,
  void Function(String)? onOpen,
}) async {
  tester.view.physicalSize = Size(width, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            OsmMap(markers: _markers, french: french, selected: const ['p3'], formatColor: '#EEF5FF', tileProvider: tile, onOpenEntry: onOpen ?? (_) {}),
            const SizedBox(height: 900),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 900));
}

Finder get _tiles => find.descendant(of: find.byType(OsmMap), matching: find.byType(Image));
Finder _marker(String id) => find.byKey(ValueKey('map-marker-$id'));

Future<void> _accept(WidgetTester tester, {bool french = true}) async {
  await tester.tap(find.text(french ? 'Activer le fond de carte' : 'Turn on map background'));
  await _settle(tester);
}

double _zoomOf(WidgetTester tester) => tester.getSize(_tiles.last).width;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    _requested.clear();
  });

  group('map math matches the web client', () {
    test('Web Mercator projection', () {
      expect(projectToWorld(0, 0).x, closeTo(0.5, 1e-9));
      expect(projectToWorld(0, 0).y, closeTo(0.5, 1e-9));
      expect(projectToWorld(85.05112878, 0).y, closeTo(0, 1e-6));
      expect(projectToWorld(-90, 0).y, closeTo(1, 1e-6));
      final paris = projectToWorld(48.8566, 2.3522);
      expect([(paris.x * 256).floor(), (paris.y * 256).floor()], [129, 88]);
    });

    test('zoom keeps the point under the cursor', () {
      const view = MapView(0.3, 0.4, 5);
      final zoomed = zoomAround(view, 7, 100, 50, 800, 400);
      final world = WorldPoint(view.x + (100 - 400) / worldSize(5), view.y + (50 - 200) / worldSize(5));
      expect(toScreen(world, zoomed, 800, 400).left, closeTo(100, 1e-6));
      expect(toScreen(world, zoomed, 800, 400).top, closeTo(50, 1e-6));
    });

    test('the view never shows beyond the world', () {
      final edge = clampView(const MapView(0, 0, 3), 800, 400);
      expect(edge.x * worldSize(3), greaterThanOrEqualTo(400 - 1e-6));
      expect(edge.y * worldSize(3), greaterThanOrEqualTo(200 - 1e-6));
      expect(minZoomFor(512, 256), closeTo(1, 1e-9));
    });

    test('fit contains every point', () {
      final points = [projectToWorld(48.85, 2.35), projectToWorld(43.3, 5.37), projectToWorld(50.63, 3.06)];
      final fit = fitBounds(points, 800, 400);
      for (final point in points) {
        final at = toScreen(point, fit, 800, 400);
        expect(at.left, inInclusiveRange(55, 745));
        expect(at.top, inInclusiveRange(55, 345));
      }
      expect(fitBounds([projectToWorld(10, 10)], 800, 400).zoom, 13);
      expect(fitBounds(const [], 800, 400).zoom, greaterThanOrEqualTo(minZoomFor(800, 400)));
    });

    test('only the visible tiles are listed, on whole pixels', () {
      final tiles = visibleTiles(const MapView(0.5, 0.5, 4.4), 4, 800, 400);
      expect(tiles.length, lessThanOrEqualTo(20));
      expect(tiles.first.url, matches(RegExp(r'^https://tile\.openstreetmap\.org/4/\d+/\d+\.png$')));
      for (final tile in tiles) {
        expect(tile.left, tile.left.roundToDouble());
      }
      expect([tileLevel(3.4), tileLevel(3.6), tileLevel(25)], [3, 4, 19]);
    });
  });

  group('OsmMap', () {
    testWidgets('no tile is requested before consent and points stay visible', (tester) async {
      await _mount(tester, tile: _recordingTile);
      await _settle(tester);
      expect(_requested, isEmpty, reason: 'rule 13: nothing goes to OpenStreetMap without a choice');
      expect(_tiles, findsNothing);
      expect(find.textContaining('adresse IP'), findsOneWidget);
      for (final id in ['p0', 'p1', 'p2', 'p3']) {
        expect(_marker(id), findsOneWidget);
      }
      await _accept(tester);
      expect(_requested, isNotEmpty);
      expect(_tiles, findsWidgets);
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the choice is remembered and can be undone', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'brainy:map:osm-tiles': 'on'});
      await _mount(tester);
      await _settle(tester);
      expect(_tiles, findsWidgets);
      expect(find.text('Activer le fond de carte'), findsNothing);
      await tester.ensureVisible(find.text('Désactiver le fond de carte'));
      await tester.pump();
      await tester.tap(find.text('Désactiver le fond de carte'));
      await _settle(tester);
      expect(_tiles, findsNothing);
      expect(await const FlutterSecureStorage().read(key: 'brainy:map:osm-tiles'), isNull);
    });

    testWidgets('dragging moves the map and does not scroll the page', (tester) async {
      await _mount(tester);
      await _settle(tester);
      final map = tester.getRect(find.byType(OsmMap));
      final before = tester.getTopLeft(_marker('p1'));
      await tester.dragFrom(map.topLeft + const Offset(40, 140), const Offset(-30, 60));
      await tester.pump();
      final after = tester.getTopLeft(_marker('p1'));
      expect(after.dy - before.dy, closeTo(60, 12));
      expect(after.dx - before.dx, closeTo(-30, 12));
      expect(tester.getRect(find.byType(OsmMap)).top, map.top, reason: 'the page stayed in place');
      await _settle(tester);
    });

    testWidgets('pinch zooms in around the fingers', (tester) async {
      await _mount(tester);
      await _accept(tester);
      final before = _zoomOf(tester);
      final map = tester.getRect(find.byType(OsmMap));
      final center = map.topLeft + Offset(map.width / 2, 150);
      final first = await tester.startGesture(center - const Offset(20, 0), pointer: 1);
      final second = await tester.startGesture(center + const Offset(20, 0), pointer: 2);
      await tester.pump();
      await first.moveTo(center - const Offset(40, 0));
      await second.moveTo(center + const Offset(40, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump();
      expect(_zoomOf(tester), greaterThan(before * 1.3));
      await _settle(tester);
    });

    testWidgets('the wheel zooms and the page keeps its place', (tester) async {
      await _mount(tester, width: 1000);
      await _accept(tester);
      final map = tester.getRect(find.byType(OsmMap));
      final before = tester.getTopLeft(_marker('p1'));
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(map.topLeft + Offset(map.width / 2, 150)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -200)));
      await tester.pump();
      expect(tester.getRect(find.byType(OsmMap)).top, map.top);
      expect(tester.getTopLeft(_marker('p1')), isNot(before));
      await _settle(tester);
    });

    testWidgets('plus, minus and fit change the view', (tester) async {
      await _mount(tester, width: 1000, french: false);
      await _accept(tester, french: false);
      for (final id in ['p0', 'p3']) {
        expect(_marker(id), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Zoom in'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Zoom in'));
      await _settle(tester);
      expect(_marker('p0').evaluate().length + _marker('p3').evaluate().length, lessThan(2), reason: 'zooming far enough leaves a marker out');
      await tester.tap(find.byTooltip('Show all points'));
      await _settle(tester);
      for (final id in ['p0', 'p1', 'p2', 'p3']) {
        expect(_marker(id), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a marker shows its popup and opens the entry at 320 px', (tester) async {
      final opened = <String>[];
      await _mount(tester, onOpen: opened.add);
      await _settle(tester);
      await tester.tap(_marker('p0'));
      await tester.pump();
      expect(find.text('Chantier Nord'), findsOneWidget);
      final map = tester.getRect(find.byType(OsmMap));
      final popup = tester.getRect(find.byKey(const ValueKey('map-popup')));
      expect(popup.left, greaterThanOrEqualTo(map.left));
      expect(popup.right, lessThanOrEqualTo(map.right));
      await tester.tap(find.text('Ouvrir la fiche'));
      await tester.pump();
      expect(opened, ['p0']);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pump();
      expect(find.byKey(const ValueKey('map-popup')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failing tiles show a discreet mention and the points stay', (tester) async {
      await _mount(tester, tile: _badTile, french: false);
      await tester.tap(find.text('Turn on map background'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await _settle(tester);
      expect(find.text('Map background offline'), findsOneWidget);
      expect(find.text('© OpenStreetMap'), findsNothing);
      expect(_marker('p1'), findsOneWidget);
      tester.takeException();
    });

    testWidgets('keyboard pans the map and Escape closes the popup', (tester) async {
      await _mount(tester, width: 1000);
      await _settle(tester);
      final map = tester.getRect(find.byType(OsmMap));
      await tester.tapAt(map.topLeft + const Offset(30, 30));
      await tester.pump();
      final before = tester.getTopLeft(_marker('p1'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(tester.getTopLeft(_marker('p1')).dx - before.dx, closeTo(80, 3));
      await tester.tap(_marker('p1'));
      await tester.pump();
      expect(find.byKey(const ValueKey('map-popup')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const ValueKey('map-popup')), findsNothing);
    });

    testWidgets('doubled text does not overflow at 320 px', (tester) async {
      tester.view.physicalSize = const Size(320, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 820), textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: OsmMap(markers: _markers, french: true, tileProvider: _goodTile, onOpenEntry: (_) {}),
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(_marker('p0'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
