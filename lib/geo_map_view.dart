import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'collections_api.dart';

Future<bool> showGeoMapView(BuildContext context, CollectionsApi api, BrainyCollection collection, {required bool french, String? initialSearch, String? filterFieldId, String? filterOperator, String? filterValue, String? viewId, required Future<void> Function(String) onOpenEntry}) async {
  await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => GeoMapView(api: api, collection: collection, french: french, initialSearch: initialSearch, filterFieldId: filterFieldId, filterOperator: filterOperator, filterValue: filterValue, viewId: viewId, onOpenEntry: onOpenEntry)));
  return true;
}

class GeoMapView extends StatefulWidget {
  const GeoMapView({super.key, required this.api, required this.collection, required this.french, this.initialSearch, this.filterFieldId, this.filterOperator, this.filterValue, this.viewId, required this.onOpenEntry});
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool french;
  final String? initialSearch;
  final String? filterFieldId;
  final String? filterOperator;
  final String? filterValue;
  final String? viewId;
  final Future<void> Function(String) onOpenEntry;
  @override State<GeoMapView> createState() => _GeoMapViewState();
}

class _GeoMapViewState extends State<GeoMapView> {
  late final positions = [for (final format in widget.collection.formats) for (final field in format.fields) if (field.kind == BrainyFieldKind.position) (format: format, field: field)];
  late final zones = [for (final format in widget.collection.formats) for (final field in format.fields) if (field.kind == BrainyFieldKind.zone) (format: format, field: field)];
  int chosen = 0;
  int? zoneChosen;
  String? after;
  final history = <String?>[];
  final search = TextEditingController();
  Map<String, dynamic>? page;
  List<Map<String, dynamic>> zoneCounts = [];
  final selected = <String>[];
  String? distance;
  String? error;
  String? notice;
  String? importText;
  String kind = 'GEOJSON';
  Map<String, dynamic>? preview;
  bool busy = false;
  bool changed = false;
  bool includeSensitive = false;
  String t(String fr, String en) => widget.french ? fr : en;

  @override void initState() { super.initState(); search.text = widget.initialSearch ?? ''; if (positions.isNotEmpty) load(); }
  @override void dispose() { search.dispose(); super.dispose(); }

  Future<void> load() async {
    if (positions.isEmpty) return;
    final target = positions[chosen];
    setState(() { busy = true; error = null; zoneCounts = []; });
    try { final result = await widget.api.geoPage(widget.collection.id, target.format.id, target.field.id, after: after, search: search.text.isEmpty ? null : search.text, filterFieldId: widget.filterFieldId, filterOperator: widget.filterOperator, filterValue: widget.filterValue, viewId: widget.viewId); if (mounted) setState(() { page = result; busy = false; }); }
    catch (cause) { if (mounted) setState(() { error = '$cause'; busy = false; }); }
  }

  Future<void> select(String id) async {
    setState(() { if (selected.contains(id)) selected.remove(id); else { if (selected.length == 2) selected.removeAt(0); selected.add(id); } distance = null; });
    if (selected.length == 2) try {
      final target = positions[chosen];
      final result = await widget.api.geoDistance(widget.collection.id, target.format.id, target.field.id, selected[0], selected[1]);
      if (mounted) setState(() => distance = '${(double.tryParse(result['value'] as String? ?? '') ?? 0).toStringAsFixed(2)} km');
    } catch (cause) { if (mounted) setState(() => error = '$cause'); }
  }

  Future<void> importPoints(bool commit) async {
    if (importText == null || positions.isEmpty) return;
    final target = positions[chosen];
    setState(() { busy = true; error = null; });
    try {
      final result = commit ? await widget.api.importGeoPoints(widget.collection.id, target.format.id, target.field.id, importText!, kind, DateTime.now().microsecondsSinceEpoch.toString()) : await widget.api.previewGeoImport(widget.collection.id, target.format.id, target.field.id, importText!, kind);
      if (!mounted) return;
      setState(() { preview = result; busy = false; if (commit && (result['errors'] as List<dynamic>).isEmpty) { changed = true; notice = t('${result['count']} points importés', '${result['count']} points imported'); after = null; history.clear(); } });
      if (commit && (result['errors'] as List<dynamic>).isEmpty) await load();
    } catch (cause) { if (mounted) setState(() { error = '$cause'; busy = false; }); }
  }

  Future<void> exportPoints(String exportKind) async {
    final target = positions[chosen];
    setState(() { busy = true; error = null; });
    try {
      final content = await widget.api.exportGeoPoints(widget.collection.id, target.format.id, target.field.id, exportKind, includeSensitive: includeSensitive);
      await FilePicker.saveFile(fileName: '${widget.collection.name}.${exportKind == 'CSV' ? 'csv' : 'geojson'}', bytes: Uint8List.fromList(utf8.encode(content)));
    } catch (cause) { if (mounted) setState(() => error = '$cause'); } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> groupZones() async {
    if (zoneChosen == null) return;
    final point = positions[chosen], zone = zones[zoneChosen!];
    try { final result = await widget.api.geoZoneSummary(widget.collection.id, point.format.id, point.field.id, zone.format.id, zone.field.id, search: search.text, filterFieldId: widget.filterFieldId, filterOperator: widget.filterOperator, filterValue: widget.filterValue, viewId: widget.viewId); if (mounted) setState(() => zoneCounts = result); }
    catch (cause) { if (mounted) setState(() => error = '$cause'); }
  }

  @override Widget build(BuildContext context) {
    final points = (page?['points'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return Scaffold(appBar: AppBar(title: Text(t('Carte des positions', 'Position map')), leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: t('Retour', 'Back'), onPressed: () => Navigator.pop(context, changed))), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: ListView(padding: const EdgeInsets.all(16), children: [
      Text(t('Grille WGS84 locale, sans fond de carte externe ni envoi des coordonnées à un tiers.', 'Local WGS84 grid, with no external map tiles or coordinate sharing.')),
      const SizedBox(height: 16),
      if (positions.isEmpty) Text(t('Ajoutez un champ position à un format de données.', 'Add a position field to a data format.')) else ...[
        DropdownButtonFormField<int>(initialValue: chosen, decoration: InputDecoration(labelText: t('Champ position', 'Position field'), border: const OutlineInputBorder()), items: [for (var i = 0; i < positions.length; i++) DropdownMenuItem(value: i, child: Text('${positions[i].format.name} · ${positions[i].field.name}'))], onChanged: (value) { if (value == null) return; setState(() { chosen = value; after = null; history.clear(); page = null; selected.clear(); }); load(); }),
        const SizedBox(height: 10), TextField(controller: search, decoration: InputDecoration(labelText: t('Rechercher', 'Search'), suffixIcon: IconButton(icon: const Icon(Icons.search), tooltip: t('Rechercher', 'Search'), onPressed: () { setState(() { after = null; history.clear(); }); load(); }), border: const OutlineInputBorder()), onSubmitted: (_) { setState(() { after = null; history.clear(); }); load(); }),
        const SizedBox(height: 14), AspectRatio(aspectRatio: 2, child: Semantics(label: t('Carte des points de la page', 'Map of points on this page'), child: CustomPaint(painter: _GridPainter(points: points, selected: selected, dark: Theme.of(context).brightness == Brightness.dark)))),
        const SizedBox(height: 10), Text(t('Sélectionnez deux lignes pour mesurer la distance.', 'Select two rows to measure distance.')),
        if (distance != null) Text(distance!, style: Theme.of(context).textTheme.titleMedium),
        if (busy) const LinearProgressIndicator(),
        for (final point in points) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(selected.contains(point['entryId']) ? Icons.check_circle : Icons.location_on_outlined), title: Text((point['name'] as String?)?.isNotEmpty == true ? point['name'] as String : point['entryId'] as String), subtitle: Text('${point['latitude']}, ${point['longitude']}${point['accuracy'] == null ? '' : ' ±${point['accuracy']} m'}'), onTap: () => select(point['entryId'] as String), trailing: IconButton(icon: const Icon(Icons.open_in_new), tooltip: t('Ouvrir', 'Open'), onPressed: () => widget.onOpenEntry(point['entryId'] as String))),
        if (page != null && points.isEmpty) Text(t('Aucun point pour ces filtres.', 'No points for these filters.')),
        Wrap(spacing: 8, children: [OutlinedButton(onPressed: history.isEmpty ? null : () { setState(() => after = history.removeLast()); load(); }, child: Text(t('Précédent', 'Previous'))), OutlinedButton(onPressed: page?['hasMore'] == true ? () { history.add(after); setState(() => after = page?['nextCursor'] as String?); load(); } : null, child: Text(t('Page suivante', 'Next page')))]),
        if (zones.isNotEmpty) ExpansionTile(title: Text(t('Regrouper par zone', 'Group by zone')), children: [DropdownButtonFormField<int>(decoration: InputDecoration(labelText: t('Champ zone', 'Zone field')), initialValue: zoneChosen, items: [for (var i = 0; i < zones.length; i++) DropdownMenuItem(value: i, child: Text('${zones[i].format.name} · ${zones[i].field.name}'))], onChanged: (value) => setState(() => zoneChosen = value)), OutlinedButton(onPressed: zoneChosen == null ? null : groupZones, child: Text(t('Calculer', 'Calculate'))), for (final row in zoneCounts) ListTile(title: Text(row['label'] as String), trailing: Text('${row['count']}'))]),
        CheckboxListTile(value: includeSensitive, title: Text(t('Inclure explicitement les positions sensibles', 'Explicitly include sensitive positions')), onChanged: busy ? null : (value) => setState(() => includeSensitive = value ?? false)),
        ExpansionTile(title: Text(t('Importer ou exporter des points', 'Import or export points')), children: [Wrap(spacing: 8, children: [OutlinedButton(onPressed: busy ? null : () => exportPoints('GEOJSON'), child: const Text('GeoJSON')), OutlinedButton(onPressed: busy ? null : () => exportPoints('CSV'), child: const Text('CSV'))]), OutlinedButton(onPressed: busy ? null : () async { final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['geojson', 'json', 'csv']); if (file == null) return; final bytes = await file.readAsBytes(); if (bytes.length > 2000000) { setState(() => error = t('Fichier trop grand', 'File is too large')); return; } setState(() { importText = utf8.decode(bytes); kind = file.name.toLowerCase().endsWith('.csv') ? 'CSV' : 'GEOJSON'; preview = null; }); }, child: Text(t('Choisir un fichier', 'Choose file'))), if (importText != null) Text('$kind · ${t('500 points maximum', '500 points maximum')}'), OutlinedButton(onPressed: importText == null || busy ? null : () => importPoints(false), child: Text(t('Aperçu', 'Preview'))), if (preview != null) Text('${preview!['count']} ${t('points valides', 'valid points')}'), for (final row in (preview?['errors'] as List<dynamic>? ?? [])) Text('${t('Ligne', 'Row')} ${row['row']}: ${row['message']}', style: TextStyle(color: Theme.of(context).colorScheme.error)), FilledButton(onPressed: preview != null && (preview!['errors'] as List<dynamic>).isEmpty && preview!['count'] != 0 && !busy ? () => importPoints(true) : null, child: Text(t('Confirmer l’import', 'Confirm import')))]),
      ],
      if (notice != null) Text(notice!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]))));
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.points, required this.selected, required this.dark});
  final List<Map<String, dynamic>> points;
  final List<String> selected;
  final bool dark;
  @override void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? const Color(0xFF24272E) : const Color(0xFFF5F6F8));
    final grid = Paint()..color = dark ? const Color(0xFF596273) : const Color(0xFFCBD5E1);
    grid.strokeWidth = 1;
    for (var x = 1; x < 6; x++) canvas.drawLine(Offset(size.width * x / 6, 0), Offset(size.width * x / 6, size.height), grid);
    for (var y = 1; y < 6; y++) canvas.drawLine(Offset(0, size.height * y / 6), Offset(size.width, size.height * y / 6), grid);
    for (final point in points) {
      final longitude = (point['longitude'] as num).toDouble(), latitude = (point['latitude'] as num).toDouble();
      canvas.drawCircle(Offset((longitude + 180) / 360 * size.width, (90 - latitude) / 180 * size.height), selected.contains(point['entryId']) ? 6 : 4, Paint()..color = selected.contains(point['entryId']) ? const Color(0xFFB34242) : const Color(0xFF2463CE));
    }
  }
  @override bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.points != points || oldDelegate.selected != selected || oldDelegate.dark != dark;
}
