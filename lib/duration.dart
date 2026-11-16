// Durations: one exact number of seconds, typed in a unit chosen on the field (same rules as the API's duration.ts).
// Months are left out: 28 to 31 days long, they cannot be added up exactly.
const durationUnits = {'s': 1, 'min': 60, 'h': 3600, 'd': 86400, 'w': 604800};
const _order = ['w', 'd', 'h', 'min', 's'];
const _max = 999999 * 3600;
final _words = <RegExp, String>{
  RegExp(r'^(w|wk|wks|week|weeks|sem|sems|semaine|semaines)$'): 'w',
  RegExp(r'^(d|day|days|j|jr|jrs|jour|jours)$'): 'd',
  RegExp(r'^(h|hr|hrs|hour|hours|heure|heures)$'): 'h',
  RegExp(r'^(m|mn|min|mins|minute|minutes)$'): 'min',
  RegExp(r'^(s|sec|secs|second|seconds|seconde|secondes)$'): 's',
};

bool isDurationUnit(String? unit) => unit != null && durationUnits.containsKey(unit);

String durationUnitLabel(String unit, bool french) => switch (unit) {
      's' => french ? 'Secondes' : 'Seconds',
      'min' => 'Minutes',
      'h' => french ? 'Heures' : 'Hours',
      'd' => french ? 'Jours' : 'Days',
      'w' => french ? 'Semaines' : 'Weeks',
      _ => unit,
    };

/// Seconds in "45" (field unit; hours without one), "1:30", "2 h 30", "1d 4h", "1,5 h", "3 j", "2 sem"; null otherwise.
int? parseDuration(String text, [String? unit]) {
  final clean = text.trim().toLowerCase().replaceAll(',', '.');
  if (clean.isEmpty || clean.length > 80) return null;
  final clock = RegExp(r'^(\d{1,6}):([0-5]\d)(?::([0-5]\d))?$').firstMatch(clean);
  double seconds;
  if (clock != null) {
    seconds = int.parse(clock.group(1)!) * 3600.0 + int.parse(clock.group(2)!) * 60 + int.parse(clock.group(3) ?? '0');
  } else if (RegExp(r'^\d+(\.\d+)?$').hasMatch(clean)) {
    seconds = double.parse(clean) * durationUnits[isDurationUnit(unit) ? unit! : 'h']!;
  } else {
    final parts = RegExp(r'\d+(?:\.\d+)?|[a-zéè]+').allMatches(clean).map((match) => match.group(0)!).toList();
    if (parts.isEmpty || parts.join() != clean.replaceAll(RegExp(r'\s+'), '')) return null;
    seconds = 0;
    String? last;
    for (var index = 0; index < parts.length; index++) {
      final amount = double.tryParse(parts[index]);
      if (amount == null) return null;
      final word = index + 1 < parts.length ? parts[index + 1] : null;
      String? found;
      if (word != null && !RegExp(r'^\d').hasMatch(word)) {
        found = _words.entries.where((entry) => entry.key.hasMatch(word)).firstOrNull?.value;
        if (found == null) return null;
        index++;
      } else if (last != null && last != 's') {
        found = _order[_order.indexOf(last) + 1];
      } else {
        return null;
      }
      if (last != null && _order.indexOf(found) <= _order.indexOf(last)) return null;
      seconds += amount * durationUnits[found]!;
      last = found;
    }
  }
  final rounded = seconds.round();
  return seconds.isFinite && rounded >= 0 && rounded <= _max ? rounded : null;
}

/// "1 wk 2 d 3 h 30 min" / "1 sem 2 j 3 h 30 min"; at most the two largest parts when [short].
String formatDuration(int seconds, bool french, {bool short = false}) {
  final symbols = {'w': french ? 'sem' : 'wk', 'd': french ? 'j' : 'd', 'h': 'h', 'min': 'min', 's': 's'};
  if (seconds <= 0) return '0 min';
  var rest = seconds;
  final parts = <String>[];
  for (final key in _order) {
    final count = rest ~/ durationUnits[key]!;
    if (count > 0) {
      parts.add('$count ${symbols[key]}');
      rest -= count * durationUnits[key]!;
    }
  }
  return (short ? parts.take(2) : parts).join(' ');
}

/// Readable text of a stored duration; a field without a unit keeps its hours:minutes look.
String displayDuration(String value, String? unit, bool french) {
  if (!isDurationUnit(unit)) return value;
  final seconds = parseDuration(value, unit);
  return seconds == null ? value : formatDuration(seconds, french);
}

/// Example shown in an empty duration input.
String durationPlaceholder(String? unit, bool french) => switch (unit) {
      's' => french ? '90 ou 1 min 30' : '90 or 1 min 30',
      'min' => french ? '45 ou 1 h 30' : '45 or 1 h 30',
      'h' => french ? '2 ou 1 h 30' : '2 or 1 h 30',
      'd' => french ? '3 ou 1 j 4 h' : '3 or 1 d 4 h',
      'w' => french ? '2 ou 1 sem 3 j' : '2 or 1 wk 3 d',
      _ => '1:30',
    };

/// Help under a duration input: how to type it, then the understood value as soon as something is typed.
String durationHelp(String text, String? unit, bool french) {
  if (text.trim().isEmpty) {
    return isDurationUnit(unit)
        ? (french ? 'En ${durationUnitLabel(unit!, true).toLowerCase()}, ou avec des mots : 1 h 30, 2 j' : 'In ${durationUnitLabel(unit!, false).toLowerCase()}, or with words: 1 h 30, 2 d')
        : (french ? 'Heures:minutes, ou avec des mots : 1 h 30' : 'Hours:minutes, or with words: 1 h 30');
  }
  final seconds = parseDuration(text, unit);
  return seconds == null ? (french ? 'Durée non comprise (les mois ne sont pas acceptés)' : 'Duration not understood (months are not accepted)') : '= ${formatDuration(seconds, french)}';
}
