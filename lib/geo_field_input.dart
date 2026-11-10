import 'dart:convert';

import 'package:flutter/material.dart';

import 'collections_api.dart';
import 'device_location.dart';
import 'map_math.dart' show roundCoordinate;
import 'osm_map.dart';

class GeoFieldInput extends StatefulWidget {
  const GeoFieldInput({super.key, required this.field, required this.controller, required this.french, this.locate = locateDevice, this.tileProvider});
  final BrainyField field;
  final TextEditingController controller;
  final bool french;

  /// Device position (T38/3); replaced in tests.
  final LocateDevice locate;

  /// Map tiles; replaced in tests.
  final ImageProvider<Object> Function(String url)? tileProvider;
  @override State<GeoFieldInput> createState() => _GeoFieldInputState();
}

class _GeoFieldInputState extends State<GeoFieldInput> {
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  final accuracy = TextEditingController();
  final radius = TextEditingController();
  final vertices = TextEditingController();
  String shape = 'Circle';
  bool picking = false;
  bool locating = false;
  String? notice;
  String t(String fr, String en) => widget.french ? fr : en;

  bool get pointable => widget.field.kind == BrainyFieldKind.position || shape == 'Circle';

  /// A tapped or located point replaces the coordinates; accuracy comes only from a device.
  void place(double lat, double lon, [double? metres]) {
    setState(() {
      latitude.text = '${roundCoordinate(lat)}';
      longitude.text = '${roundCoordinate(lon)}';
      accuracy.text = metres == null ? '' : '${metres.round()}';
    });
    emit();
  }

  Future<void> locate() async {
    setState(() { locating = true; notice = t('Localisation en cours…', 'Locating…'); });
    final found = await widget.locate();
    if (!mounted) return;
    setState(() => locating = false);
    if (found.failure == null) {
      place(found.latitude, found.longitude, found.accuracy);
      setState(() => notice = t('Position enregistrée, précise à ${found.accuracy.round()} m.', 'Position set, accurate to ${found.accuracy.round()} m.'));
      return;
    }
    setState(() => notice = switch (found.failure!) {
      LocationFailure.serviceOff => t('La localisation de l’appareil est désactivée. Activez-la ou choisissez sur la carte.', 'Device location is off. Turn it on or pick on the map.'),
      LocationFailure.denied => t('Accès à la position refusé. Choisissez sur la carte ou réessayez.', 'Location access was denied. Pick on the map or try again.'),
      LocationFailure.deniedForever => t('Accès à la position refusé. Autorisez-le dans les réglages de l’appareil ou choisissez sur la carte.', 'Location access was denied. Allow it in the device settings or pick on the map.'),
      LocationFailure.timeout => t('La position n’a pas été trouvée à temps. Réessayez.', 'The position took too long. Please try again.'),
      LocationFailure.unavailable => t('Position indisponible. Réessayez ou choisissez sur la carte.', 'Position unavailable. Try again or pick on the map.'),
    });
  }

  void picked(double lat, double lon) {
    place(lat, lon);
    setState(() => notice = t('Position choisie sur la carte.', 'Position picked on the map.'));
  }

  List<MapMarker> get current {
    final lat = read(latitude.text), lon = read(longitude.text);
    return lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180 ? const [] : [MapMarker(id: 'position', title: widget.field.name, latitude: lat, longitude: lon)];
  }

  Widget pickTools(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 10),
    Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton.icon(key: const ValueKey('geo-locate'), onPressed: locating ? null : locate, icon: const Icon(Icons.my_location_rounded), label: Text(t('Utiliser ma position', 'Use my location'))),
      OutlinedButton.icon(key: const ValueKey('geo-pick'), onPressed: () => setState(() => picking = !picking), icon: Icon(picking ? Icons.close_rounded : Icons.add_location_alt_outlined), label: Text(picking ? t('Fermer la carte', 'Close the map') : t('Choisir sur la carte', 'Pick on the map'))),
    ]),
    if (notice != null) Padding(padding: const EdgeInsets.only(top: 8), child: Semantics(liveRegion: true, child: Text(notice!, style: Theme.of(context).textTheme.bodySmall))),
    if (picking) ...[
      const SizedBox(height: 8),
      Text(t('Touchez l’endroit voulu ; au clavier, Entrée choisit le centre.', 'Tap the place; with the keyboard, Enter picks the centre.'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      // The map sizes itself to the screen.
      widget.tileProvider == null
          ? OsmMap(markers: current, french: widget.french, selected: const ['position'], onOpenEntry: (_) {}, onPick: picked)
          : OsmMap(markers: current, french: widget.french, selected: const ['position'], onOpenEntry: (_) {}, tileProvider: widget.tileProvider!, onPick: picked),
    ],
  ]);

  @override void initState() {
    super.initState();
    try {
      final data = jsonDecode(widget.controller.text) as Map<String, dynamic>;
      latitude.text = '${data['latitude'] ?? (data['center'] is List ? data['center'][1] : '')}';
      longitude.text = '${data['longitude'] ?? (data['center'] is List ? data['center'][0] : '')}';
      accuracy.text = '${data['accuracy'] ?? ''}';
      radius.text = '${data['radiusMeters'] ?? ''}';
      shape = data['type'] == 'Polygon' ? 'Polygon' : 'Circle';
      if (data['coordinates'] is List) vertices.text = (data['coordinates'] as List).map((item) => (item as List).join(', ')).join('\n');
    } catch (_) {}
  }

  @override void dispose() { latitude.dispose(); longitude.dispose(); accuracy.dispose(); radius.dispose(); vertices.dispose(); super.dispose(); }
  double? read(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  void emit() {
    final lat = read(latitude.text), lon = read(longitude.text);
    if (widget.field.kind == BrainyFieldKind.position) {
      if (lat == null || lon == null) { widget.controller.text = latitude.text.trim().isEmpty && longitude.text.trim().isEmpty ? '' : '{'; return; }
      widget.controller.text = jsonEncode({'latitude': lat, 'longitude': lon, if (accuracy.text.trim().isNotEmpty) 'accuracy': read(accuracy.text)});
    } else if (shape == 'Circle') {
      final value = read(radius.text);
      if (lat == null || lon == null || value == null) { widget.controller.text = latitude.text.trim().isEmpty && longitude.text.trim().isEmpty && radius.text.trim().isEmpty ? '' : '{'; return; }
      widget.controller.text = jsonEncode({'type': 'Circle', 'center': [lon, lat], 'radiusMeters': value});
    } else {
      final points = vertices.text.split('\n').where((line) => line.trim().isNotEmpty).map((line) => line.split(RegExp(r'[;,]')).map((part) => read(part)).toList()).toList();
      if (points.length < 3 || points.any((point) => point.length != 2 || point.any((value) => value == null))) { widget.controller.text = vertices.text.trim().isEmpty ? '' : '{'; return; }
      widget.controller.text = jsonEncode({'type': 'Polygon', 'coordinates': points});
    }
  }

  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('${widget.field.name} · ${widget.field.kind == BrainyFieldKind.position ? t('Position WGS84', 'WGS84 position') : t('Zone', 'Zone')}', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 10),
    if (widget.field.kind == BrainyFieldKind.zone) DropdownButtonFormField<String>(isExpanded: true, initialValue: shape, decoration: InputDecoration(labelText: t('Forme', 'Shape'), border: const OutlineInputBorder()), items: [DropdownMenuItem(value: 'Circle', child: Text(t('Cercle', 'Circle'), maxLines: 1, overflow: TextOverflow.ellipsis)), DropdownMenuItem(value: 'Polygon', child: Text(t('Polygone', 'Polygon'), maxLines: 1, overflow: TextOverflow.ellipsis))], onChanged: (value) { setState(() => shape = value ?? 'Circle'); emit(); }),
    if (widget.field.kind == BrainyFieldKind.position || shape == 'Circle') ...[
      const SizedBox(height: 10), TextField(controller: latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: t('Latitude (−90 à 90)', 'Latitude (−90 to 90)'), border: const OutlineInputBorder()), onChanged: (_) => emit()),
      const SizedBox(height: 10), TextField(controller: longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: t('Longitude (−180 à 180)', 'Longitude (−180 to 180)'), border: const OutlineInputBorder()), onChanged: (_) => emit()),
      pickTools(context),
    ],
    const SizedBox(height: 10),
    if (widget.field.kind == BrainyFieldKind.position) TextField(controller: accuracy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('Précision en mètres (facultative)', 'Accuracy in metres (optional)'), border: const OutlineInputBorder()), onChanged: (_) => emit())
    else if (shape == 'Circle') TextField(controller: radius, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('Rayon en mètres', 'Radius in metres'), border: const OutlineInputBorder()), onChanged: (_) => emit())
    else TextField(controller: vertices, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: t('Sommets : longitude, latitude par ligne', 'Vertices: longitude, latitude per line'), border: const OutlineInputBorder()), onChanged: (_) => emit()),
    const SizedBox(height: 10), Text(t('Ces coordonnées restent dans Brainy. La carte ne charge le fond OpenStreetMap qu’avec votre accord.', 'These coordinates stay in Brainy. The map loads the OpenStreetMap background only with your consent.'), style: Theme.of(context).textTheme.bodySmall),
  ]))));
}
