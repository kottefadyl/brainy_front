import 'dart:convert';

import 'package:flutter/material.dart';

import 'collections_api.dart';

class GeoFieldInput extends StatefulWidget {
  const GeoFieldInput({super.key, required this.field, required this.controller, required this.french});
  final BrainyField field;
  final TextEditingController controller;
  final bool french;
  @override State<GeoFieldInput> createState() => _GeoFieldInputState();
}

class _GeoFieldInputState extends State<GeoFieldInput> {
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  final accuracy = TextEditingController();
  final radius = TextEditingController();
  final vertices = TextEditingController();
  String shape = 'Circle';
  String t(String fr, String en) => widget.french ? fr : en;

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
    if (widget.field.kind == BrainyFieldKind.zone) DropdownButtonFormField<String>(initialValue: shape, decoration: InputDecoration(labelText: t('Forme', 'Shape'), border: const OutlineInputBorder()), items: [DropdownMenuItem(value: 'Circle', child: Text(t('Cercle', 'Circle'))), DropdownMenuItem(value: 'Polygon', child: Text(t('Polygone', 'Polygon')))], onChanged: (value) { setState(() => shape = value ?? 'Circle'); emit(); }),
    if (widget.field.kind == BrainyFieldKind.position || shape == 'Circle') ...[
      const SizedBox(height: 10), TextField(controller: latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: t('Latitude (−90 à 90)', 'Latitude (−90 to 90)'), border: const OutlineInputBorder()), onChanged: (_) => emit()),
      const SizedBox(height: 10), TextField(controller: longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: t('Longitude (−180 à 180)', 'Longitude (−180 to 180)'), border: const OutlineInputBorder()), onChanged: (_) => emit()),
    ],
    const SizedBox(height: 10),
    if (widget.field.kind == BrainyFieldKind.position) TextField(controller: accuracy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('Précision en mètres (facultative)', 'Accuracy in metres (optional)'), border: const OutlineInputBorder()), onChanged: (_) => emit())
    else if (shape == 'Circle') TextField(controller: radius, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('Rayon en mètres', 'Radius in metres'), border: const OutlineInputBorder()), onChanged: (_) => emit())
    else TextField(controller: vertices, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: t('Sommets : longitude, latitude par ligne', 'Vertices: longitude, latitude per line'), border: const OutlineInputBorder()), onChanged: (_) => emit()),
    const SizedBox(height: 10), Text(t('Aucun fond de carte externe n’est chargé.', 'No external map tiles are loaded.'), style: Theme.of(context).textTheme.bodySmall),
  ]))));
}
