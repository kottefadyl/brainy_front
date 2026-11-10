import 'dart:convert';
import 'dart:typed_data';

import 'package:brainy/collections_api.dart';
import 'package:brainy/device_location.dart';
import 'package:brainy/geo_field_input.dart';
import 'package:brainy/map_math.dart';
import 'package:brainy/osm_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// A 1×1 transparent PNG.
final _pixel = Uint8List.fromList(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));
ImageProvider<Object> _tile(String url) => MemoryImage(_pixel);

Future<TextEditingController> _mount(WidgetTester tester, LocateDevice locate, {double width = 390, bool french = true}) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = TextEditingController(text: jsonEncode({'latitude': 6.524412, 'longitude': 3.379206}));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GeoFieldInput(
          field: const BrainyField(id: 'where', name: 'Lieu', kind: BrainyFieldKind.position),
          controller: controller,
          french: french,
          locate: locate,
          tileProvider: _tile,
        ),
      ),
    ),
  ));
  await tester.pump();
  return controller;
}

Map<String, dynamic> _value(TextEditingController controller) => jsonDecode(controller.text) as Map<String, dynamic>;

void main() {
  test('screen and world coordinates round-trip', () {
    final world = projectToWorld(6.524412, 3.379206);
    final back = unprojectWorld(world);
    expect(roundCoordinate(back.latitude), 6.524412);
    expect(roundCoordinate(back.longitude), 3.379206);
    const view = MapView(0.5, 0.5, 3);
    final screen = fromScreen(200, 150, view, 400, 300);
    expect(screen.x, closeTo(0.5, 1e-12));
    expect(screen.y, closeTo(0.5, 1e-12));
  });

  testWidgets('the device position fills the field with its accuracy', (tester) async {
    final controller = await _mount(tester, () async => const DeviceLocation.found(48.8566123, 2.3522219, 12.6));
    await tester.tap(find.byKey(const ValueKey('geo-locate')));
    await tester.pumpAndSettle();
    expect(_value(controller), {'latitude': 48.856612, 'longitude': 2.352222, 'accuracy': 13.0});
    expect(find.textContaining('précise à 13 m'), findsOneWidget);
  });

  testWidgets('a refused permission explains itself and keeps the value', (tester) async {
    final controller = await _mount(tester, () async => const DeviceLocation.failed(LocationFailure.deniedForever), french: false);
    await tester.tap(find.byKey(const ValueKey('geo-locate')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Allow it in the device settings'), findsOneWidget);
    expect(_value(controller)['latitude'], 6.524412);
  });

  testWidgets('a tap on the map picks the place under it, without accuracy', (tester) async {
    final controller = await _mount(tester, () async => const DeviceLocation.failed(LocationFailure.unavailable), width: 320);
    expect(find.byType(OsmMap), findsNothing, reason: 'the map opens only on request');
    await tester.tap(find.byKey(const ValueKey('geo-pick')));
    await tester.pumpAndSettle();
    expect(find.byType(OsmMap), findsOneWidget);
    final box = tester.getRect(find.descendant(of: find.byType(OsmMap), matching: find.byType(RawGestureDetector)).first);
    // Top left, clear of the consent box and of the zoom buttons.
    await tester.tapAt(Offset(box.left + box.width * 0.2, box.top + box.height * 0.2));
    await tester.pumpAndSettle();
    final value = _value(controller);
    expect(value['latitude'], greaterThan(6.524412));
    expect(value['longitude'], lessThan(3.379206));
    expect(value.containsKey('accuracy'), isFalse);
    expect(find.text('Position choisie sur la carte.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
