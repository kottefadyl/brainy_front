import 'package:flutter/material.dart';

/// Forms take the whole screen on a phone and stay centred dialogs elsewhere.
bool isPhoneForm(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

/// Outer surface of a custom form dialog.
class AdaptiveFormShell extends StatelessWidget {
  const AdaptiveFormShell({
    super.key,
    required this.child,
    this.shape,
    this.backgroundColor,
    this.insetPadding,
  });

  final Widget child;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final EdgeInsets? insetPadding;

  @override
  Widget build(BuildContext context) {
    if (isPhoneForm(context)) {
      return Dialog.fullscreen(
        backgroundColor: backgroundColor,
        child: SafeArea(child: child),
      );
    }
    return Dialog(
      shape: shape,
      backgroundColor: backgroundColor,
      insetPadding: insetPadding,
      child: child,
    );
  }
}

/// Same contract as [AlertDialog]; on a phone the title stays on top and the
/// actions stay reachable at the bottom, above the keyboard.
class AdaptiveFormDialog extends StatelessWidget {
  const AdaptiveFormDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.shape,
    this.backgroundColor,
    this.scrollable = false,
  });

  final Widget title, content;
  final List<Widget>? actions;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (!isPhoneForm(context)) {
      return AlertDialog(
        title: title,
        content: content,
        actions: actions,
        shape: shape,
        backgroundColor: backgroundColor,
        scrollable: scrollable,
      );
    }
    final theme = Theme.of(context);
    return Dialog.fullscreen(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  const CloseButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: DefaultTextStyle(
                      style: theme.textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      child: title,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: scrollable
                          ? SingleChildScrollView(child: content)
                          : content,
                    ),
                  ],
                ),
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    overflowAlignment: OverflowBarAlignment.end,
                    children: actions!,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Keeps forms calm: the character count only appears close to the limit.
Widget? quietFormCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) {
  if (maxLength == null || currentLength < maxLength * .8) return null;
  return Text(
    '$currentLength/$maxLength',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
    ),
  );
}

enum StoredDateKind { date, time, dateTime }

/// Reads a stored date or time for display in the interface language.
String localizedStoredDate(
  BuildContext context,
  String stored,
  StoredDateKind kind,
) {
  if (stored.isEmpty) return '';
  final local = MaterialLocalizations.of(context);
  final use24 = MediaQuery.alwaysUse24HourFormatOf(context) ||
      Localizations.localeOf(context).languageCode == 'fr';
  String time(TimeOfDay value) =>
      local.formatTimeOfDay(value, alwaysUse24HourFormat: use24);
  if (kind == StoredDateKind.time) {
    final parts = stored.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (hour == null || minute == null) return stored;
    return time(TimeOfDay(hour: hour, minute: minute));
  }
  final parsed = DateTime.tryParse(stored);
  if (parsed == null) return stored;
  if (kind == StoredDateKind.date) return local.formatCompactDate(parsed);
  final value = parsed.toLocal();
  return '${local.formatCompactDate(value)} ${time(TimeOfDay.fromDateTime(value))}';
}

/// Read-only field opening a picker: shows a local date, stores the raw value.
class LocalizedDateField extends StatefulWidget {
  const LocalizedDateField({
    super.key,
    required this.controller,
    required this.kind,
    required this.label,
    required this.onPick,
    this.enabled = true,
    this.clearable = true,
    this.hint,
  });

  final TextEditingController controller;
  final StoredDateKind kind;
  final String label;
  final VoidCallback onPick;
  final bool enabled, clearable;
  final String? hint;

  @override
  State<LocalizedDateField> createState() => _LocalizedDateFieldState();
}

class _LocalizedDateFieldState extends State<LocalizedDateField> {
  final _display = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LocalizedDateField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _display.dispose();
    super.dispose();
  }

  void _sync() {
    _display.text = localizedStoredDate(context, widget.controller.text, widget.kind);
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.kind == StoredDateKind.time
        ? Icons.schedule_outlined
        : Icons.calendar_today_outlined;
    final hasValue = widget.controller.text.isNotEmpty;
    return TextField(
      controller: _display,
      readOnly: true,
      enabled: widget.enabled,
      onTap: widget.onPick,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: hasValue && widget.enabled && widget.clearable
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () => setState(widget.controller.clear),
                icon: const Icon(Icons.close_rounded, size: 20),
              )
            : Icon(icon),
      ),
    );
  }
}
