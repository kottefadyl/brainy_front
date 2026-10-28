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
    );
    lines.add('${field.name}: $displayValue');
  }
  return lines.join('\n');
}

String displayEntryValue(
  BrainyField field,
  String value,
  AppStrings copy, {
  BrainyUnitSnapshot? snapshot,
}) {
  if (field.kind == BrainyFieldKind.number) {
    if (snapshot != null) {
      final number = copy.isFrench ? value.replaceAll('.', ',') : value;
      return snapshot.dimension == 'CURRENCY'
          ? '${snapshot.symbol} $number'
          : '$number ${snapshot.symbol}';
    }
    return formatFieldNumber(value, field.unit, copy);
  }
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
