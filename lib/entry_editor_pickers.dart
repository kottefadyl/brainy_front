
import 'package:flutter/material.dart';

Future<void> pickEntryDate(
  BuildContext context,
  TextEditingController controller,
) async {
  final current = DateTime.tryParse(controller.text);
  final value = await showDatePicker(
    context: context,
    initialDate: current ?? DateTime.now(),
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
  );
  if (value != null) {
    controller.text =
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

Future<void> pickEntryTime(
  BuildContext context,
  TextEditingController controller,
) async {
  final parts = controller.text.split(':');
  final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
  final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
  final value = await showTimePicker(
    context: context,
    initialTime: hour != null && minute != null && hour < 24 && minute < 60
        ? TimeOfDay(hour: hour, minute: minute)
        : TimeOfDay.now(),
  );
  if (value != null) {
    controller.text =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

Future<void> pickEntryDateTime(
  BuildContext context,
  TextEditingController controller,
) async {
  final current =
      DateTime.tryParse(controller.text)?.toLocal() ?? DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (time == null) return;
  controller.text = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).toUtc().toIso8601String();
}
