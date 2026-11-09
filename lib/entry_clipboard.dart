import 'dart:convert';

import 'app_strings.dart';
import 'collections_api.dart';
import 'number_units.dart';

String entryClipboardText(
  BrainyCollection collection,
  BrainyEntry entry,
  AppStrings copy,
) {
  final lines = <String>[];
  final fields = collection.formatFor(entry).fields;
  final titleField = fields
      .where((field) => field.kind == BrainyFieldKind.title)
      .firstOrNull;
  final title = titleField == null ? null : entry.values[titleField.id]?.trim();
  if (title != null && title.isNotEmpty) lines.add(title);

  for (final field in fields) {
    if (field.id == titleField?.id) continue;
    final value = entry.values[field.id]?.trim();
    if (value == null || value.isEmpty) continue;
    if (field.kind == BrainyFieldKind.objectRef) {
      final snapshots =
          entry.objectSnapshots[field.id] ?? const <Map<String, dynamic>>[];
      final names = snapshots.map((item) {
        final properties = (item['properties'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        return properties
                    .where((property) => property['kind'] == 'TITLE')
                    .firstOrNull?['value']
                as String? ??
            item['objectId'] as String;
      }).toList();
      lines.add('${field.name}: ${names.join(', ')}');
      continue;
    }
    final displayValue = displayEntryValue(
      field,
      value,
      copy,
      snapshot: entry.unitSnapshots[field.id],
      collection: collection,
    );
    lines.add('${field.name}: $displayValue');
  }
  return lines.join('\n');
}

const _monthsFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _dayLabel(int year, int month, int day, AppStrings copy) => copy.isFrench
    ? '$day ${_monthsFr[month - 1]} $year'
    : '${_monthsEn[month - 1]} $day, $year';

/// Shows a stored `YYYY-MM-DD` date in the app language, as the web client does.
String displayStoredDate(String value, AppStrings copy) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  final month = int.tryParse(match?[2] ?? '') ?? 0;
  if (match == null || month < 1 || month > 12) return value;
  return _dayLabel(int.parse(match[1]!), month, int.parse(match[3]!), copy);
}

String _displayStoredDateTime(String value, AppStrings copy) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  final minutes = parsed.minute.toString().padLeft(2, '0');
  final time = copy.isFrench
      ? '${parsed.hour.toString().padLeft(2, '0')}:$minutes'
      : '${parsed.hour % 12 == 0 ? 12 : parsed.hour % 12}:$minutes ${parsed.hour < 12 ? 'AM' : 'PM'}';
  return '${_dayLabel(parsed.year, parsed.month, parsed.day, copy)}, $time';
}

String displayEntryValue(
  BrainyField field,
  String value,
  AppStrings copy, {
  BrainyUnitSnapshot? snapshot,
  BrainyCollection? collection,
}) {
  if (field.kind == BrainyFieldKind.code) {
    final list = collection?.codeLists.where((item) => item['id'] == field.codeListId).firstOrNull;
    final code = (list?['codes'] as List<dynamic>? ?? []).where((item) => item['code'] == value).firstOrNull;
    if (code is Map<String, dynamic>) return '${code[copy.isFrench ? 'labelFr' : 'labelEn']} ($value)${code['active'] == true ? '' : copy.isFrench ? ' · obsolète' : ' · obsolete'}';
  }
  if (field.kind == BrainyFieldKind.position) {
    try { final point = jsonDecode(value) as Map<String, dynamic>; return '${point['latitude']}, ${point['longitude']}${point['accuracy'] == null ? '' : ' ±${point['accuracy']} m'}'; } catch (_) { return value; }
  }
  if (field.kind == BrainyFieldKind.zone) {
    try { final zone = jsonDecode(value) as Map<String, dynamic>; return zone['type'] == 'Circle' ? copy.isFrench ? 'Cercle' : 'Circle' : copy.isFrench ? 'Polygone' : 'Polygon'; } catch (_) { return value; }
  }
  if (field.kind == BrainyFieldKind.number) {
    if (snapshot != null) {
      final number = copy.isFrench ? value.replaceAll('.', ',') : value;
      return snapshot.dimension == 'CURRENCY'
          ? '${snapshot.symbol} $number'
          : '$number ${snapshot.symbol}';
    }
    return formatFieldNumber(value, field.unit, copy);
  }
  if (field.kind == BrainyFieldKind.date) return displayStoredDate(value, copy);
  if (field.kind == BrainyFieldKind.datetime) return _displayStoredDateTime(value, copy);
  if (field.kind == BrainyFieldKind.boolean) {
    return copy.text(value == 'true' ? 'Yes' : 'No');
  }
  if (field.kind == BrainyFieldKind.multiSelect) {
    try {
      return (jsonDecode(value) as List<dynamic>).join(', ');
    } catch (_) {
      return value;
    }
  }
  if (field.kind == BrainyFieldKind.objectRef) {
    try {
      final count = (jsonDecode(value) as List<dynamic>).length;
      return copy.isFrench ? '$count objet(s)' : '$count object(s)';
    } catch (_) {
      return value;
    }
  }
  if (field.kind == BrainyFieldKind.datetime) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date != null) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return copy.isFrench
          ? '$day/$month/${date.year} $hour:$minute'
          : '$month/$day/${date.year} $hour:$minute';
    }
  }
  return value;
}
