import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Most entries a data format accepts: null = no limit (empty text), otherwise a whole number from 1.
/// Returns `(ok: false)` when the text is not a valid limit.
({bool ok, int? value}) parseMaxEntries(String text) {
  final clean = text.trim();
  if (clean.isEmpty) return (ok: true, value: null);
  final value = int.tryParse(clean);
  if (value == null || value < 1 || value > 1000000) return (ok: false, value: null);
  return (ok: true, value: value);
}

String maxEntriesError(bool french) => french
    ? 'Le nombre d’entrées doit être un nombre entier à partir de 1, ou rester vide.'
    : 'The number of entries must be a whole number from 1, or stay empty.';

/// Data format setting: how many entries it may hold. Left empty, there is no limit.
class MaxEntriesField extends StatelessWidget {
  const MaxEntriesField({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final parsed = parseMaxEntries(value.text);
        return TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: fr ? 'Nombre maximal d’entrées' : 'Maximum number of entries',
            hintText: fr ? 'Sans limite' : 'No limit',
            prefixIcon: const Icon(Icons.format_list_numbered),
            errorText: parsed.ok ? null : maxEntriesError(fr),
            helperText: !parsed.ok
                ? null
                : parsed.value == 1
                ? (fr ? 'Une seule entrée, par exemple une couverture ou une préface.' : 'A single entry, for example a cover or a preface.')
                : (fr ? 'Laissez vide pour ne fixer aucune limite.' : 'Leave empty for no limit.'),
          ),
        );
      },
    );
  }
}

/// Field setting: an entry must fill this field. Off unless chosen.
class FieldRequiredSwitch extends StatelessWidget {
  const FieldRequiredSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = AppStrings.of(context).isFrench ? 'Obligatoire' : 'Required';
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: value, onChanged: onChanged),
              const SizedBox(width: 4),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Field setting: this field's value shows in the entry rows (3 at most per data format).
class FieldListSwitch extends StatelessWidget {
  const FieldListSwitch({super.key, required this.value, required this.enabled, required this.onChanged});
  final bool value, enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    return Tooltip(
      message: enabled ? '' : (fr ? 'Trois champs au plus s’affichent dans la liste.' : 'At most three fields show in the list.'),
      child: MergeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? () => onChanged(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: value, onChanged: enabled ? onChanged : null),
                const SizedBox(width: 4),
                Flexible(child: Text(fr ? 'Afficher dans la liste' : 'Show in the list', maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The field name as shown in an entry form: a required field carries " *".
String requiredLabel(String name, bool required) => required ? '$name *' : name;

/// The message for required fields left empty, or null when all are filled.
String? missingRequiredMessage(Iterable<({String name, bool required, bool filled})> fields, bool french) {
  final missing = [for (final field in fields) if (field.required && !field.filled) field.name];
  if (missing.isEmpty) return null;
  return french ? 'Champs obligatoires à remplir : ${missing.join(', ')}.' : 'Fill in the required fields: ${missing.join(', ')}.';
}
