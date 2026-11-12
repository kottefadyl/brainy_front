// Scatter plot and radar (T23/1): the same logic as the web (`lib/chart-scatter-radar.ts`).
import 'dart:math' as math;

import 'collections_api.dart';

class ScatterPoint {
  const ScatterPoint({required this.entryId, required this.x, required this.y, required this.label});
  final String entryId;
  final double x;
  final double y;
  final String label;
}

/// Fields a scatter axis can use: plain numbers and measures.
bool isScatterField(BrainyField field) => field.kind == BrainyFieldKind.number || field.kind == BrainyFieldKind.measure;

/// One point per entry holding both numbers; entries missing either value are counted apart.
({List<ScatterPoint> points, int skipped}) scatterPoints(List<BrainyEntry> entries, String xFieldId, String yFieldId, {String? labelFieldId}) {
  final points = <ScatterPoint>[];
  var skipped = 0;
  for (final entry in entries) {
    final x = double.tryParse(entry.values[xFieldId] ?? ''), y = double.tryParse(entry.values[yFieldId] ?? '');
    if (x == null || y == null || !x.isFinite || !y.isFinite) {
      skipped++;
      continue;
    }
    points.add(ScatterPoint(entryId: entry.id, x: x, y: y, label: labelFieldId == null ? '' : entry.values[labelFieldId] ?? ''));
  }
  return (points: points, skipped: skipped);
}

/// Pearson correlation; null with fewer than 3 points or when one axis never varies.
double? pearson(List<ScatterPoint> points) {
  final n = points.length;
  if (n < 3) return null;
  final mx = points.fold<double>(0, (sum, point) => sum + point.x) / n;
  final my = points.fold<double>(0, (sum, point) => sum + point.y) / n;
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (final point in points) {
    sxy += (point.x - mx) * (point.y - my);
    sxx += math.pow(point.x - mx, 2);
    syy += math.pow(point.y - my, 2);
  }
  if (sxx == 0 || syy == 0) return null;
  return (sxy / math.sqrt(sxx * syy)).clamp(-1.0, 1.0);
}

/// Least-squares line y = slope·x + intercept; null when x never varies.
({double slope, double intercept})? linearFit(List<ScatterPoint> points) {
  final n = points.length;
  if (n < 2) return null;
  final mx = points.fold<double>(0, (sum, point) => sum + point.x) / n;
  final my = points.fold<double>(0, (sum, point) => sum + point.y) / n;
  var sxy = 0.0, sxx = 0.0;
  for (final point in points) {
    sxy += (point.x - mx) * (point.y - my);
    sxx += math.pow(point.x - mx, 2);
  }
  if (sxx == 0) return null;
  final slope = sxy / sxx;
  return (slope: slope, intercept: my - slope * mx);
}

/// The strength of a correlation in plain words, with the usual thresholds (0.3 and 0.7).
String correlationWords(double? r, {required bool french}) {
  if (r == null) return french ? 'Pas assez de points variés pour mesurer un lien.' : 'Not enough varied points to measure a link.';
  final size = r.abs();
  final strength = size >= 0.7 ? (french ? 'fort' : 'strong') : size >= 0.3 ? (french ? 'modéré' : 'moderate') : (french ? 'faible ou absent' : 'weak or none');
  if (size < 0.3) return french ? 'Lien $strength.' : 'Link: $strength.';
  final direction = r > 0
      ? (french ? 'quand l’un augmente, l’autre augmente aussi' : 'when one rises, the other tends to rise')
      : (french ? 'quand l’un augmente, l’autre diminue' : 'when one rises, the other tends to fall');
  return french ? 'Lien $strength : $direction.' : '${strength[0].toUpperCase()}${strength.substring(1)} link: $direction.';
}

/// Axis bounds around the data, not forced to zero: a weight between 79 and 82 kg stays readable.
({double low, double high, List<double> ticks}) tightScale(List<double> values) {
  var min = values.reduce(math.min), max = values.reduce(math.max);
  if (min == max) {
    min -= 1;
    max += 1;
  }
  final raw = (max - min) / 4;
  final power = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final unit = raw / power;
  final step = (unit <= 1 ? 1 : unit <= 2 ? 2 : unit <= 5 ? 5 : 10) * power;
  final low = (min / step).floorToDouble() * step, high = (max / step).ceilToDouble() * step;
  final ticks = <double>[];
  for (var value = low; value <= high + step / 2; value += step) {
    ticks.add(double.parse(value.toStringAsPrecision(12)));
  }
  return (low: low, high: high, ticks: ticks);
}

/// Radar axes are spread clockwise from the top; the point of `ratio` (0..1) on axis `index`.
({double x, double y}) radarPoint(int index, int count, double ratio, double cx, double cy, double radius) {
  final angle = -math.pi / 2 + 2 * math.pi * index / count;
  return (x: cx + math.cos(angle) * radius * ratio, y: cy + math.sin(angle) * radius * ratio);
}

/// A radar needs 3 to 12 categories or objects, none negative, and something above zero.
bool canRadar(List<double> values, String? groupBy) =>
    (groupBy == 'CATEGORY' || groupBy == 'OBJECT' || groupBy == 'PERSON') && values.length >= 3 && values.length <= 12 && values.every((value) => value.isFinite && value >= 0) && values.any((value) => value > 0);

/// CSV of the plotted points, with the same protection against formulas as the other exports.
String scatterCsv(List<ScatterPoint> points, String xName, String yName, {required bool french}) {
  String cell(String value) => '"${(RegExp(r'^[=+\-@\t\r]').hasMatch(value) ? "'$value" : value).replaceAll('"', '""')}"';
  String number(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  return [
    [cell(french ? 'Entrée' : 'Entry'), cell(xName), cell(yName)].join(','),
    for (final point in points) [cell(point.label.isEmpty ? point.entryId : point.label), number(point.x), number(point.y)].join(','),
  ].join('\r\n');
}
