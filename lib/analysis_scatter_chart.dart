// Scatter plot (T23/1), as on the web: one point per entry with two numbers, the trend line
// and the correlation in plain words. Entries are read page by page, so protected values stay hidden.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chart_export.dart';
import 'chart_math.dart';
import 'chart_scatter_radar.dart';
import 'collections_api.dart';
import 'design_tokens.dart';
import 'number_units.dart';

const _maxPages = 10; // 10 pages of 100 entries
const _plotHeight = 300.0;
const _pad = (left: 58.0, right: 12.0, top: 12.0, bottom: 40.0);

class AnalysisScatterChart extends StatefulWidget {
  const AnalysisScatterChart({super.key, required this.api, required this.collection, required this.format, required this.french, required this.onOpenEntry});
  final CollectionsApi api;
  final BrainyCollection collection;
  final BrainyFormat format;
  final bool french;
  final Future<void> Function(String entryId) onOpenEntry;

  @override
  State<AnalysisScatterChart> createState() => _AnalysisScatterChartState();
}

class _AnalysisScatterChartState extends State<AnalysisScatterChart> {
  late final List<BrainyField> _numeric = widget.format.fields.where(isScatterField).toList();
  late String? _xId = _numeric.isNotEmpty ? _numeric[0].id : null;
  late String? _yId = _numeric.length > 1 ? _numeric[1].id : null;
  final _focus = FocusNode(debugLabel: 'scatter');
  List<BrainyEntry>? _entries;
  bool _more = false, _busy = false;
  String? _error;
  int? _active;
  ChartExportOutcome? _exported;

  bool get fr => widget.french;
  BrainyField? _field(String? id) => widget.format.fields.where((field) => field.id == id).firstOrNull;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    setState(() { _busy = true; _error = null; _active = null; });
    try {
      final loaded = <BrainyEntry>[];
      String? after;
      var pages = 0;
      var more = false;
      do {
        final page = await widget.api.entriesPage(widget.collection.id, formatId: widget.format.id, after: after, first: 100);
        loaded.addAll(page.entries);
        after = page.hasMore ? page.nextCursor : null;
        pages++;
        more = after != null;
      } while (after != null && pages < _maxPages);
      if (mounted) setState(() { _entries = loaded; _more = more; });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _unit(String? unit) {
    if (unit == null || unit.isEmpty) return '';
    final local = widget.collection.units.where((item) => 'local:${item.id}' == unit || item.id == unit).firstOrNull;
    return local?.symbol ?? numberUnit(unit)?.symbol ?? unit;
  }

  String _axisName(BrainyField? field) => field == null ? '' : '${field.name}${_unit(field.unit).isEmpty ? '' : ' · ${_unit(field.unit)}'}';
  String _number(double value) => formatChartValue(value, null, fr);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ChartColors.of(theme.brightness);
    if (_numeric.length < 2) {
      return Text(fr ? 'Un nuage de points compare deux champs nombre d’un même format de données ; celui-ci n’en a pas deux.' : 'A scatter plot compares two number fields of one data format; this one does not have two.', style: TextStyle(color: colors.muted));
    }
    final xField = _field(_xId), yField = _field(_yId);
    final titleId = widget.format.fields.where((field) => field.kind == BrainyFieldKind.title).firstOrNull?.id;
    final data = _entries == null || _xId == null || _yId == null ? (points: <ScatterPoint>[], skipped: 0) : scatterPoints(_entries!, _xId!, _yId!, labelFieldId: titleId);
    final ordered = [...data.points]..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    final r = pearson(data.points), fit = linearFit(data.points);
    final current = _active == null || _active! >= ordered.length ? null : ordered[_active!];
    String valueOf(BrainyField? field, double value) => formatChartValue(value, field?.unit == null ? null : _unit(field!.unit), fr);
    final sep = fr ? ' : ' : ': ';
    String describe(ScatterPoint point) => '${point.label}, ${xField?.name}$sep${valueOf(xField, point.x)}, ${yField?.name}$sep${valueOf(yField, point.y)}';

    DropdownButtonFormField<String> axis(String label, String? value, ValueChanged<String?> onChanged, Key key) => DropdownButtonFormField<String>(
      key: key,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [for (final field in _numeric) DropdownMenuItem(value: field.id, child: Text(field.name, overflow: TextOverflow.ellipsis))],
      onChanged: onChanged,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
          SizedBox(width: 200, child: axis(fr ? 'Axe horizontal (X)' : 'Horizontal axis (X)', _xId, (value) => setState(() { _xId = value; _active = null; }), const Key('scatter-x'))),
          SizedBox(width: 200, child: axis(fr ? 'Axe vertical (Y)' : 'Vertical axis (Y)', _yId, (value) => setState(() { _yId = value; _active = null; }), const Key('scatter-y'))),
          FilledButton(
            key: const Key('scatter-draw'),
            onPressed: _busy || _xId == null || _yId == null ? null : _draw,
            child: Text(_busy ? (fr ? 'Chargement…' : 'Loading…') : _entries != null ? (fr ? 'Actualiser' : 'Refresh') : (fr ? 'Tracer le nuage' : 'Draw the scatter plot')),
          ),
        ]),
        if (_xId != null && _xId == _yId) Padding(padding: const EdgeInsets.only(top: 8), child: Text(fr ? 'Choisissez deux champs différents.' : 'Choose two different fields.', style: TextStyle(color: colors.muted))),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(child: Text('${fr ? 'Les entrées n’ont pas pu être lues : ' : 'The entries could not be read: '}$_error', style: TextStyle(color: theme.colorScheme.error))),
              TextButton(onPressed: _draw, child: Text(fr ? 'Réessayer' : 'Retry')),
            ]),
          ),
        if (_entries != null && _xId != _yId) ...[
          const SizedBox(height: 12),
          if (ordered.isEmpty)
            Text(fr ? 'Aucune entrée n’a ces deux valeurs.' : 'No entry has both values.', style: TextStyle(color: colors.muted))
          else ...[
            Focus(
              focusNode: _focus,
              onKeyEvent: (node, event) {
                if (event is KeyUpEvent) return KeyEventResult.ignored;
                final last = ordered.length - 1;
                final key = event.logicalKey;
                int? next;
                if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) next = ((_active ?? -1) + 1).clamp(0, last);
                if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowUp) next = ((_active ?? 1) - 1).clamp(0, last);
                if (key == LogicalKeyboardKey.home) next = 0;
                if (key == LogicalKeyboardKey.end) next = last;
                if (next != null) { setState(() => _active = next); return KeyEventResult.handled; }
                if (key == LogicalKeyboardKey.escape) { setState(() => _active = null); return KeyEventResult.handled; }
                if (key == LogicalKeyboardKey.enter && current != null) { widget.onOpenEntry(current.entryId); return KeyEventResult.handled; }
                return KeyEventResult.ignored;
              },
              child: Semantics(
                label: fr ? '${yField?.name} selon ${xField?.name}, ${ordered.length} points' : '${yField?.name} by ${xField?.name}, ${ordered.length} points',
                // Screen readers need the next and previous values whenever one is announced.
                value: current == null ? null : describe(current),
                increasedValue: current == null ? null : describe(ordered[(_active! + 1).clamp(0, ordered.length - 1)]),
                decreasedValue: current == null ? null : describe(ordered[(_active! - 1).clamp(0, ordered.length - 1)]),
                onIncrease: () => setState(() => _active = ((_active ?? -1) + 1).clamp(0, ordered.length - 1)),
                onDecrease: () => setState(() => _active = ((_active ?? 1) - 1).clamp(0, ordered.length - 1)),
                child: LayoutBuilder(builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, _plotHeight);
                  final layout = _ScatterLayout(ordered, size);
                  return GestureDetector(
                    key: const Key('scatter-plot'),
                    onTapDown: (details) {
                      _focus.requestFocus();
                      final index = layout.nearest(details.localPosition);
                      if (index == null) return;
                      if (index == _active) { widget.onOpenEntry(ordered[index].entryId); } else { setState(() => _active = index); }
                    },
                    child: CustomPaint(size: size, painter: _ScatterPainter(layout: layout, fit: fit, active: _active, colors: colors, xName: _axisName(xField), yName: _axisName(yField), number: _number)),
                  );
                }),
              ),
            ),
            if (current != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${current.label.isEmpty ? (fr ? 'Entrée sans titre' : 'Untitled entry') : current.label} · ${xField?.name}$sep${valueOf(xField, current.x)} · ${yField?.name}$sep${valueOf(yField, current.y)} · ${fr ? 'touchez de nouveau ou Entrée pour ouvrir' : 'tap again or Enter to open'}',
                  key: const Key('scatter-selection'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 10),
            Text('${ordered.length} points${data.skipped > 0 ? ' · ${data.skipped} ${fr ? 'entrées sans les deux valeurs, non tracées' : 'entries without both values, not plotted'}' : ''}${_more ? ' · ${fr ? 'les 1 000 premières entrées seulement' : 'first 1,000 entries only'}' : ''}'),
            Text(r == null ? correlationWords(null, french: fr) : '${fr ? 'Corrélation' : 'Correlation'} r = ${formatChartValue(double.parse(r.toStringAsFixed(2)), null, fr)} · ${correlationWords(r, french: fr)}', key: const Key('scatter-correlation')),
            if (fit != null) Text('${fr ? 'Tendance (pointillé)' : 'Trend (dashed)'}$sep${yField?.name} ≈ ${_number(double.parse(fit.slope.toStringAsPrecision(3)))} × ${xField?.name} ${fit.intercept < 0 ? '−' : '+'} ${_number(double.parse(fit.intercept.abs().toStringAsPrecision(3)))}'),
            Text(fr ? 'Un lien entre deux valeurs ne prouve pas que l’une cause l’autre.' : 'A link between two values does not prove that one causes the other.', style: TextStyle(color: colors.muted, fontSize: 13)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(fr ? 'Télécharger les points (CSV)' : 'Download the points (CSV)'),
              onPressed: () async {
                final outcome = await runChartExport(fr, () async => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(scatterCsv(ordered, xField?.name ?? 'X', yField?.name ?? 'Y', french: fr))]), '${chartExportBaseName()}-scatter.csv');
                if (mounted) setState(() => _exported = outcome);
              },
            ),
            ChartExportNote(_exported),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(fr ? 'Voir les points' : 'View the points'),
              children: [
                for (final point in ordered.take(200))
                  ListTile(
                    dense: true,
                    title: Text(point.label.isEmpty ? point.entryId : point.label),
                    subtitle: Text('${xField?.name}$sep${valueOf(xField, point.x)} · ${yField?.name}$sep${valueOf(yField, point.y)}'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => widget.onOpenEntry(point.entryId),
                  ),
                if (ordered.length > 200) Text(fr ? '200 points affichés sur ${ordered.length} ; le CSV les contient tous.' : '200 of ${ordered.length} points shown; the CSV holds them all.', style: TextStyle(color: colors.muted)),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Positions of the points in the drawing, shared by the painter and the tap search.
class _ScatterLayout {
  _ScatterLayout(this.points, this.size)
      : xs = tightScale(points.isEmpty ? [0, 1] : points.map((point) => point.x).toList()),
        ys = tightScale(points.isEmpty ? [0, 1] : points.map((point) => point.y).toList());
  final List<ScatterPoint> points;
  final Size size;
  final ({double low, double high, List<double> ticks}) xs, ys;
  double get plotW => size.width - _pad.left - _pad.right;
  double get plotH => size.height - _pad.top - _pad.bottom;
  double px(double value) => _pad.left + (value - xs.low) / (xs.high - xs.low) * plotW;
  double py(double value) => _pad.top + plotH - (value - ys.low) / (ys.high - ys.low) * plotH;
  Offset at(ScatterPoint point) => Offset(px(point.x), py(point.y));

  /// The point nearest a tap, within 24 px (a comfortable finger target).
  int? nearest(Offset position) {
    int? best;
    var bestDistance = 24.0;
    for (var index = 0; index < points.length; index++) {
      final distance = (at(points[index]) - position).distance;
      if (distance <= bestDistance) { best = index; bestDistance = distance; }
    }
    return best;
  }
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter({required this.layout, required this.fit, required this.active, required this.colors, required this.xName, required this.yName, required this.number});
  final _ScatterLayout layout;
  final ({double slope, double intercept})? fit;
  final int? active;
  final ChartColors colors;
  final String xName, yName;
  final String Function(double) number;

  void _text(Canvas canvas, String text, Offset at, {TextAlign align = TextAlign.left, bool bold = false, double size = 12, Color? color}) {
    final painter = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color ?? colors.muted, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)), textDirection: TextDirection.ltr)..layout();
    final dx = align == TextAlign.right ? at.dx - painter.width : align == TextAlign.center ? at.dx - painter.width / 2 : at.dx;
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    final grid = Paint()..color = colors.line..strokeWidth = 1;
    for (final tick in l.ys.ticks) {
      canvas.drawLine(Offset(_pad.left, l.py(tick)), Offset(size.width - _pad.right, l.py(tick)), grid);
      _text(canvas, number(tick), Offset(_pad.left - 8, l.py(tick)), align: TextAlign.right);
    }
    for (var index = 0; index < l.xs.ticks.length; index++) {
      if (size.width < 420 && index.isOdd) continue;
      _text(canvas, number(l.xs.ticks[index]), Offset(l.px(l.xs.ticks[index]), size.height - _pad.bottom + 14), align: TextAlign.center);
    }
    final axis = Paint()..color = colors.muted.withValues(alpha: .6)..strokeWidth = 1;
    canvas.drawLine(Offset(_pad.left, _pad.top + l.plotH), Offset(size.width - _pad.right, _pad.top + l.plotH), axis);
    canvas.drawLine(Offset(_pad.left, _pad.top), Offset(_pad.left, _pad.top + l.plotH), axis);
    _text(canvas, xName, Offset(_pad.left + l.plotW / 2, size.height - 8), align: TextAlign.center, bold: true, color: colors.ink, size: 12.5);
    canvas.save();
    canvas.translate(12, _pad.top + l.plotH / 2);
    canvas.rotate(-1.5707963267948966);
    _text(canvas, yName, Offset.zero, align: TextAlign.center, bold: true, color: colors.ink, size: 12.5);
    canvas.restore();
    final line = fit;
    if (line != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(_pad.left, _pad.top, l.plotW, l.plotH));
      final start = Offset(l.px(l.xs.low), l.py(line.slope * l.xs.low + line.intercept));
      final end = Offset(l.px(l.xs.high), l.py(line.slope * l.xs.high + line.intercept));
      final trend = Paint()..color = colors.comparison..strokeWidth = 2;
      // Dashed so the trend never depends on colour alone.
      final length = (end - start).distance, direction = (end - start) / length;
      for (var travelled = 0.0; travelled < length; travelled += 11) {
        canvas.drawLine(start + direction * travelled, start + direction * (travelled + 6).clamp(0, length), trend);
      }
      canvas.restore();
    }
    final fill = Paint()..color = colors.main.withValues(alpha: .75);
    final ring = Paint()..color = colors.surface..style = PaintingStyle.stroke..strokeWidth = 1.2;
    for (var index = 0; index < l.points.length; index++) {
      final at = l.at(l.points[index]);
      final selected = index == active;
      canvas.drawCircle(at, selected ? 7 : 4.5, selected ? (Paint()..color = colors.main) : fill);
      canvas.drawCircle(at, selected ? 7 : 4.5, selected ? (Paint()..color = colors.ink..style = PaintingStyle.stroke..strokeWidth = 2) : ring);
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter old) => old.layout.points != layout.points || old.layout.size != layout.size || old.active != active || old.colors != colors || old.fit != fit;
}
