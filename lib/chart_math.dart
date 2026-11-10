import 'dart:math' as math;

/// Calculations behind the analysis chart. Same rules as the web client
/// (`brainy_web_app/lib/chart-math.ts`), so both draw the same chart.
class ChartPoint {
  const ChartPoint({
    required this.group,
    required this.label,
    required this.value,
    required this.count,
  });

  factory ChartPoint.fromRow(Map<String, dynamic> row) {
    final parsed = double.tryParse(row['value'] as String? ?? '');
    return ChartPoint(
      group: row['group'] as String,
      label: (row['label'] ?? row['group']) as String,
      value: parsed != null && parsed.isFinite ? parsed : 0,
      count: (row['count'] as num?)?.toInt() ?? 0,
    );
  }

  final String group;
  final String label;
  final double value;
  final int count;
}

class ChartSlot {
  const ChartSlot({
    required this.key,
    required this.label,
    this.main,
    this.comparison,
    this.delta,
  });

  final String key;
  final String label;
  final ChartPoint? main;
  final ChartPoint? comparison;
  final double? delta;
}

class ChartScale {
  const ChartScale(this.low, this.high, this.ticks);

  final double low;
  final double high;

  /// From the highest graduation to the lowest.
  final List<double> ticks;
}

class AxisTick {
  const AxisTick(this.index, this.label);

  final int index;
  final String label;
}

enum PeriodKind { month, day }

final _month = RegExp(r'^\d{4}-\d{2}$');
final _day = RegExp(r'^\d{4}-\d{2}-\d{2}');

DateTime? _periodDate(String label) {
  if (_month.hasMatch(label)) {
    return DateTime.tryParse('$label-01T00:00:00Z');
  }
  if (_day.hasMatch(label)) {
    return DateTime.tryParse('${label.substring(0, 10)}T00:00:00Z');
  }
  return null;
}

/// A period axis only when every known group is a month, or every one a date.
PeriodKind? periodKind(Iterable<String> labels) {
  final known = labels.where((label) => label != 'Missing date').toList();
  if (known.isEmpty) return null;
  if (known.every(_month.hasMatch)) return PeriodKind.month;
  return known.every(_day.hasMatch) ? PeriodKind.day : null;
}

/// Relative change from the previous value; null when there is no base.
double? deltaPercent(double current, double? previous) {
  if (previous == null || previous == 0) return null;
  return (current - previous) / previous.abs() * 100;
}

/// Periods line up by position, categories by key. A key found only in the
/// compared period keeps its own slot, so no result disappears from the chart.
List<ChartSlot> alignSeries(List<ChartPoint> rows, List<ChartPoint> comparison) {
  final byPosition =
      periodKind([...rows, ...comparison].map((row) => row.label)) != null;
  final compared = <String, ChartPoint>{
    for (var index = 0; index < comparison.length; index++)
      byPosition ? '$index' : comparison[index].group: comparison[index],
  };
  final slots = <ChartSlot>[];
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final key = byPosition ? '$index' : row.group;
    slots.add(
      ChartSlot(
        key: key,
        label: row.label,
        main: row,
        comparison: compared.remove(key),
        delta: deltaPercent(row.value, index > 0 ? rows[index - 1].value : null),
      ),
    );
  }
  compared.forEach((key, row) {
    slots.add(ChartSlot(key: key, label: row.label, comparison: row));
  });
  return slots;
}

/// Largest-Triangle-Three-Buckets: indices that keep peaks, troughs and trend.
List<int> lttbIndices(List<double> values, int threshold) {
  final count = values.length;
  if (threshold >= count || threshold < 3) {
    return List<int>.generate(count, (index) => index);
  }
  final kept = <int>[0];
  final bucket = (count - 2) / (threshold - 2);
  var anchor = 0;
  for (var index = 0; index < threshold - 2; index++) {
    final nextStart = ((index + 1) * bucket).floor() + 1;
    final nextEnd = math.min(((index + 2) * bucket).floor() + 1, count);
    var averageX = 0.0;
    var averageY = 0.0;
    for (var cursor = nextStart; cursor < nextEnd; cursor++) {
      averageX += cursor;
      averageY += values[cursor];
    }
    final size = math.max(1, nextEnd - nextStart);
    averageX /= size;
    averageY /= size;
    var best = (index * bucket).floor() + 1;
    var bestArea = -1.0;
    for (var cursor = (index * bucket).floor() + 1; cursor < nextStart; cursor++) {
      final area =
          ((anchor - averageX) * (values[cursor] - values[anchor]) -
                  (anchor - cursor) * (averageY - values[anchor]))
              .abs();
      if (area > bestArea) {
        bestArea = area;
        best = cursor;
      }
    }
    kept.add(best);
    anchor = best;
  }
  kept.add(count - 1);
  return kept;
}

const maxChartPoints = 100;

List<ChartSlot> sampleSlots(List<ChartSlot> slots) {
  if (slots.length <= maxChartPoints) return slots;
  final values = [
    for (final slot in slots) slot.main?.value ?? slot.comparison?.value ?? 0.0,
  ];
  return [for (final index in lttbIndices(values, maxChartPoints)) slots[index]];
}

/// Round graduations around zero, so that bars keep their baseline.
ChartScale niceScale(List<double> values, {int intervals = 4}) {
  final minimum = values.fold<double>(0, math.min);
  final maximum = values.fold<double>(0, math.max);
  final range = maximum - minimum == 0 ? 1.0 : maximum - minimum;
  final rough = range / intervals;
  final power = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final multiplier = const [
    1.0,
    2.0,
    2.5,
    5.0,
    10.0,
  ].firstWhere((item) => item * power >= rough * (1 - 1e-9), orElse: () => 10);
  final step = multiplier * power;
  final low = (minimum / step).floorToDouble() * step;
  final high = maximum == minimum
      ? step * intervals
      : (maximum / step).ceilToDouble() * step;
  final ticks = <double>[];
  for (var index = 0; low + index * step <= high + step / 2; index++) {
    ticks.add(double.parse((low + index * step).toStringAsPrecision(12)));
  }
  return ChartScale(ticks.first, ticks.last, ticks.reversed.toList());
}

const _monthsShortFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _monthsShortEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsFr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String _shortYear(DateTime date) => '${date.year % 100}'.padLeft(2, '0');

String _dayText(DateTime date, bool french) => french
    ? '${date.day} ${_monthsShortFr[date.month - 1]}'
    : '${_monthsShortEn[date.month - 1]} ${date.day}';

String _monthText(DateTime date, bool french) =>
    '${(french ? _monthsShortFr : _monthsShortEn)[date.month - 1]} ${_shortYear(date)}';

/// The complete name of a group, for the tooltip.
String fullChartLabel(String label, bool french) {
  final date = _periodDate(label);
  if (date == null) return label;
  final name = (french ? _monthsFr : _monthsEn)[date.month - 1];
  if (_month.hasMatch(label)) return '$name ${date.year}';
  return french ? '${date.day} $name ${date.year}' : '$name ${date.day}, ${date.year}';
}

enum _TickStyle { day, month, year }

class _Grid {
  const _Grid(this.bucket, this.style);

  final int Function(DateTime) bucket;
  final _TickStyle style;
}

int _dayNumber(DateTime date) =>
    (date.millisecondsSinceEpoch / Duration.millisecondsPerDay).round();
// 1970-01-05 is a Monday, day 4 of the epoch.
int _weekNumber(DateTime date) => ((_dayNumber(date) - 4) / 7).floor();
int _monthNumber(DateTime date) => date.year * 12 + date.month - 1;
_Grid _everyMonths(int step, [_TickStyle style = _TickStyle.month]) =>
    _Grid((date) => (_monthNumber(date) / step).floor(), style);

final _monthGrids = [
  _everyMonths(1),
  _everyMonths(2),
  _everyMonths(3),
  _everyMonths(6),
  _everyMonths(12, _TickStyle.year),
  _everyMonths(24, _TickStyle.year),
  _everyMonths(60, _TickStyle.year),
];
final _dayGrids = [
  _Grid(_dayNumber, _TickStyle.day),
  _Grid(_weekNumber, _TickStyle.day),
  _Grid((date) => (_weekNumber(date) / 2).floor(), _TickStyle.day),
  _everyMonths(1),
  _everyMonths(3),
  _everyMonths(6),
  _everyMonths(12, _TickStyle.year),
  _everyMonths(60, _TickStyle.year),
];

String _tickText(DateTime date, _TickStyle style, bool french) => switch (style) {
  _TickStyle.year => '${date.year}',
  _TickStyle.month => _monthText(date, french),
  _TickStyle.day => _dayText(date, french),
};

String _shorten(String text, int limit) => text.characters.length > limit
    ? '${text.characters.take(math.max(1, limit - 1))}…'
    : text;

extension on String {
  _Characters get characters => _Characters(this);
}

class _Characters {
  _Characters(String text) : _runes = text.runes.toList();
  final List<int> _runes;
  int get length => _runes.length;
  String take(int count) => String.fromCharCodes(_runes.take(count));
}

/// Periods land on calendar boundaries; other labels are evenly spaced. The
/// finest grid whose labels do not touch is kept.
List<AxisTick> chooseAxisTicks(
  List<String> labels,
  List<double> positions,
  bool french, {
  double characterWidth = 7,
}) {
  final kind = periodKind(labels);
  if (kind != null) {
    final dates = labels.map(_periodDate).toList();
    for (final grid in kind == PeriodKind.month ? _monthGrids : _dayGrids) {
      final hits = <int>[];
      int? previous;
      for (var index = 0; index < dates.length; index++) {
        final date = dates[index];
        if (date == null) continue;
        final bucket = grid.bucket(date);
        if (bucket != previous) hits.add(index);
        previous = bucket;
      }
      final texts = [
        for (final index in hits) _tickText(dates[index]!, grid.style, french),
      ];
      final longest = texts.fold<int>(0, (size, text) => math.max(size, text.length));
      final gap = longest * characterWidth + 12;
      var fits = hits.length >= 2;
      for (var order = 1; fits && order < hits.length; order++) {
        fits = positions[hits[order]] - positions[hits[order - 1]] >= gap;
      }
      if (fits) {
        return [
          for (var order = 0; order < hits.length; order++)
            AxisTick(hits[order], texts[order]),
        ];
      }
    }
  }
  final rendered = [
    for (final label in labels)
      switch (kind) {
        PeriodKind.month => _periodDate(label) == null ? label : _monthText(_periodDate(label)!, french),
        PeriodKind.day => _periodDate(label) == null ? label : _dayText(_periodDate(label)!, french),
        null => label,
      },
  ];
  final longest = math.min(
    14,
    rendered.fold<int>(0, (size, text) => math.max(size, text.length)),
  );
  final slotGap = longest * characterWidth + 12;
  final span = positions.last - positions.first;
  final fit = math.max(2, (span / slotGap).floor() + 1);
  final step = math.max(1, ((positions.length - 1) / (fit - 1)).ceil());
  return [
    for (var index = 0; index < positions.length; index += step)
      AxisTick(index, _shorten(rendered[index], longest)),
  ];
}

const _currencies = {'EUR', 'USD', 'GBP', 'NGN'};

String _withSeparators(String digits, bool french) {
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(french ? ' ' : ',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String formatChartNumber(double value, bool french, {int? fixed, int maximum = 6}) {
  var text = value.abs().toStringAsFixed(fixed ?? maximum);
  if (fixed == null && text.contains('.')) {
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  final parts = text.split('.');
  final whole = _withSeparators(parts[0], french);
  final decimals = parts.length > 1 ? '${french ? ',' : '.'}${parts[1]}' : '';
  final zero = double.parse(text) == 0;
  return '${value < 0 && !zero ? '-' : ''}$whole$decimals';
}

/// Value and unit as the tooltip shows them: `13 800,00 EUR`.
String formatChartValue(double value, String? unit, bool french) {
  final number = formatChartNumber(
    value,
    french,
    fixed: _currencies.contains(unit) ? 2 : null,
  );
  return unit == null || unit.isEmpty ? number : '$number $unit';
}

/// Axis graduation: `12 k`, `1,5 M` in French, `12K`, `1.5M` in English.
String compactChartNumber(double value, bool french) {
  final size = value.abs();
  final (divider, suffix) = size >= 1e9
      ? (1e9, french ? ' Md' : 'B')
      : size >= 1e6
      ? (1e6, french ? ' M' : 'M')
      : size >= 1e3
      ? (1e3, french ? ' k' : 'K')
      : (1.0, '');
  final scaled = value / divider;
  if (scaled == 0) return '0';
  final digits = math.max(0, 2 - (math.log(scaled.abs()) / math.ln10).floor());
  final rounded = double.parse(scaled.toStringAsFixed(digits));
  return '${formatChartNumber(rounded, french, maximum: digits)}$suffix';
}

String formatDelta(double delta, bool french) {
  final rounded = double.parse(delta.toStringAsFixed(1));
  final sign = rounded > 0 ? '+' : rounded < 0 ? '-' : '';
  return '$sign${formatChartNumber(rounded.abs(), french, maximum: 1)} %';
}

String entryCount(int count, bool french) {
  final number = _withSeparators('$count', french);
  if (french) return '$number ${count > 1 ? 'entrées' : 'entrée'}';
  return '$number ${count == 1 ? 'entry' : 'entries'}';
}

/// Up to this many series are drawn from a cross-tabulation (T23/2).
const maxChartSeries = 4;

class ChartSeries {
  const ChartSeries({required this.key, required this.label, required this.total, required this.points});

  final String key;
  final String label;
  final double total;

  /// One slot per period; null when the category has no value in that period.
  final List<ChartPoint?> points;
}

class MultiSeries {
  const MultiSeries({required this.periods, required this.series, required this.hiddenSeries, required this.skippedRows});

  final List<String> periods;
  final List<ChartSeries> series;
  final int hiddenSeries;
  final int skippedRows;
}

/// Turns a cross-tabulation of periods × categories into one series per
/// category, all in the same unit. The categories with the largest totals are
/// drawn; the table keeps every cell. Null when the result has no period axis.
MultiSeries? splitCrossTab(List<Map<String, dynamic>> rows, String? groupBy, String? secondaryGroupBy) {
  const periodGroups = {'DAY', 'MONTH'};
  const seriesGroups = {'CATEGORY', 'OBJECT'};
  final periodFirst = periodGroups.contains(groupBy) && seriesGroups.contains(secondaryGroupBy);
  final periodSecond = seriesGroups.contains(groupBy) && periodGroups.contains(secondaryGroupBy);
  if (!periodFirst && !periodSecond) return null;
  final cells = <({String period, String key, String label, ChartPoint point})>[];
  var skippedRows = 0;
  for (final row in rows) {
    final rowKey = row['rowKey'] as String?;
    final columnKey = row['columnKey'] as String?;
    if (rowKey == null || columnKey == null) return null;
    final period = periodFirst ? rowKey : columnKey;
    final key = periodFirst ? columnKey : rowKey;
    if (_periodDate(period) == null) {
      skippedRows += 1;
      continue;
    }
    // The API writes "<row label> × <column label>"; a period is written as its own key.
    final full = (row['label'] ?? row['group']) as String;
    final label = periodFirst
        ? (full.startsWith('$period × ') ? full.substring(period.length + 3) : key)
        : (full.endsWith(' × $period') ? full.substring(0, full.length - period.length - 3) : key);
    cells.add((period: period, key: key, label: label, point: ChartPoint.fromRow(row)));
  }
  final periods = {for (final cell in cells) cell.period}.toList()..sort();
  if (periods.length < 2) return null;
  final totals = <String, ({String label, double total})>{};
  for (final cell in cells) {
    final current = totals[cell.key];
    totals[cell.key] = (label: current?.label ?? cell.label, total: (current?.total ?? 0) + cell.point.value.abs());
  }
  final chosen = totals.entries.toList()
    ..sort((a, b) {
      final byTotal = b.value.total.compareTo(a.value.total);
      return byTotal != 0 ? byTotal : a.value.label.compareTo(b.value.label);
    });
  final position = {for (var index = 0; index < periods.length; index++) periods[index]: index};
  final series = [
    for (final entry in chosen.take(maxChartSeries))
      ChartSeries(
        key: entry.key,
        label: entry.value.label,
        total: entry.value.total,
        points: () {
          final points = List<ChartPoint?>.filled(periods.length, null);
          for (final cell in cells) {
            if (cell.key == entry.key) points[position[cell.period]!] = cell.point;
          }
          return points;
        }(),
      ),
  ];
  return MultiSeries(periods: periods, series: series, hiddenSeries: totals.length - series.length, skippedRows: skippedRows);
}

/// Running tops of stacked series (T23/1): `tops[order][i]` is the sum of the
/// first `order + 1` series at `indices[i]`; a missing or negative value counts
/// as 0. Same as `stackedTops` on the web.
List<List<double>> stackedTops(List<ChartSeries> series, List<int> indices) {
  final tops = <List<double>>[];
  var previous = List<double>.filled(indices.length, 0);
  for (final item in series) {
    final current = [
      for (var order = 0; order < indices.length; order++) previous[order] + math.max(0, item.points[indices[order]]?.value ?? 0),
    ];
    tops.add(current);
    previous = current;
  }
  return tops;
}
