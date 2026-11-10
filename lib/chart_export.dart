import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Chart exports (T23/6), the Flutter side of `analysis-chart-export.ts`.
/// Images are meant for reports: always the light palette, title above,
/// legend below, twice the pixel density. CSV holds every value, never only
/// the simplified points on screen. Flutter paints on a canvas, so there is
/// no vector (SVG) export here.
const chartExportWidth = 960.0;
const _header = 40.0;
const _footer = 34.0;

class ChartReportLegendItem {
  const ChartReportLegendItem(this.label, this.color, {this.dashed = false});
  final String label;
  final Color color;
  final bool dashed;
}

/// Writes `bytes` where the person chooses; false when they cancel.
/// Tests replace it to avoid the native dialog.
Future<bool> Function(String name, Uint8List bytes) saveChartExport = (name, bytes) async =>
    await FilePicker.saveFile(fileName: name, bytes: bytes) != null;

String chartExportBaseName([DateTime? now]) => 'brainy-chart-${(now ?? DateTime.now()).toIso8601String().substring(0, 10)}';

String _csvText(String value) {
  final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(value) ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}

/// Same columns and quoting as `chartCsv` on the web; UTF-8 BOM for spreadsheets.
String chartCsv(List<Map<String, dynamic>> rows, List<Map<String, dynamic>> comparison, String? unit, bool french) {
  final compared = comparison.isNotEmpty;
  final header = [
    ...(french ? ['Groupe', 'Libellé', 'Valeur', 'Unité', 'Nombre'] : ['Group', 'Label', 'Value', 'Unit', 'Count']),
    if (compared) french ? 'Série' : 'Series',
  ];
  String line(Map<String, dynamic> row, String series) => [
    _csvText('${row['group'] ?? ''}'),
    _csvText('${row['label'] ?? row['group'] ?? ''}'),
    '"${row['value']}"',
    _csvText(unit ?? ''),
    '${row['count'] ?? 0}',
    if (compared) _csvText(series),
  ].join(',');
  final main = french ? 'Période principale' : 'Main period';
  final other = french ? 'Période comparée' : 'Comparison period';
  return '﻿${[header.map(_csvText).join(','), ...rows.map((row) => line(row, main)), ...comparison.map((row) => line(row, other))].join('\r\n')}';
}

Uint8List csvBytes(String csv) => Uint8List.fromList(utf8.encode(csv));

TextPainter _text(String text, double size, Color color, {FontWeight weight = FontWeight.w400, double maxWidth = double.infinity}) => TextPainter(
  text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
  textDirection: TextDirection.ltr,
  maxLines: 1,
  ellipsis: '…',
)..layout(maxWidth: maxWidth);

/// A PNG of the plot at twice its size, with the report frame around it.
Future<Uint8List> chartReportPng({
  required String title,
  required Size plot,
  required List<ChartReportLegendItem> legend,
  required void Function(Canvas canvas, Size size) paintPlot,
}) async {
  final colors = ChartColors.of(Brightness.light);
  final width = plot.width;
  final height = _header + plot.height + _footer;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(2);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = colors.surface);
  final heading = _text(title, 16, colors.ink, weight: FontWeight.w600, maxWidth: width - 32);
  heading.paint(canvas, Offset(16, 26 - heading.height * 0.8));
  heading.dispose();
  canvas
    ..save()
    ..translate(0, _header)
    ..clipRect(Rect.fromLTWH(0, 0, width, plot.height));
  paintPlot(canvas, plot);
  canvas.restore();
  var x = 16.0;
  final y = height - 14;
  for (final item in legend) {
    if (x > width - 80) break;
    final key = Paint()
      ..color = item.color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (item.dashed) {
      for (var start = x; start < x + 22; start += 11) {
        canvas.drawLine(Offset(start, y - 4), Offset(start + 6, y - 4), key);
      }
    } else {
      canvas.drawLine(Offset(x, y - 4), Offset(x + 22, y - 4), key);
    }
    final label = _text(item.label, 13, colors.muted, maxWidth: (width - x - 28).clamp(40, 220));
    label.paint(canvas, Offset(x + 28, y - label.height * 0.8));
    x += 28 + label.width + 24;
    label.dispose();
  }
  final image = await recorder.endRecording().toImage((width * 2).round(), (height * 2).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) throw StateError('The chart image could not be encoded');
  return bytes.buffer.asUint8List();
}

enum ChartExportKind { png, csv }

/// The export menu shared by the result charts: image or data.
class ChartExportMenu extends StatelessWidget {
  const ChartExportMenu({super.key, required this.french, required this.onExport});

  final bool french;
  final ValueChanged<ChartExportKind> onExport;

  @override
  Widget build(BuildContext context) {
    final label = french ? 'Exporter le graphique' : 'Export chart';
    return PopupMenuButton<ChartExportKind>(
      key: const ValueKey('chart-export-menu'),
      tooltip: label,
      onSelected: onExport,
      icon: const Icon(Icons.download_rounded, size: 20),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const ValueKey('chart-export-png'),
          value: ChartExportKind.png,
          child: ListTile(dense: true, leading: const Icon(Icons.image_outlined), title: Text(french ? 'Image haute définition (PNG)' : 'High-resolution image (PNG)')),
        ),
        PopupMenuItem(
          key: const ValueKey('chart-export-csv'),
          value: ChartExportKind.csv,
          child: ListTile(dense: true, leading: const Icon(Icons.table_chart_outlined), title: Text(french ? 'Données (CSV)' : 'Data (CSV)')),
        ),
      ],
    );
  }
}

class ChartExportOutcome {
  const ChartExportOutcome(this.message, {this.failed = false});
  final String message;
  final bool failed;
}

/// Runs an export and tells what happened; a cancelled dialog says nothing.
Future<ChartExportOutcome?> runChartExport(bool french, Future<Uint8List> Function() bytes, String name) async {
  try {
    final saved = await saveChartExport(name, await bytes());
    return saved ? ChartExportOutcome(french ? 'Fichier enregistré' : 'File saved') : null;
  } catch (_) {
    return ChartExportOutcome(french ? 'Export impossible. Réessayez.' : 'Export failed. Please try again.', failed: true);
  }
}

/// The line under the toolbar after an export; nothing when there is nothing to say.
class ChartExportNote extends StatelessWidget {
  const ChartExportNote(this.outcome, {super.key});
  final ChartExportOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final note = outcome;
    if (note == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        note.message,
        key: const ValueKey('chart-export-note'),
        style: TextStyle(fontSize: 13, color: note.failed ? theme.colorScheme.error : ChartColors.of(theme.brightness).muted),
      ),
    );
  }
}
