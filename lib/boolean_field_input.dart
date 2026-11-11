import 'package:flutter/material.dart';

/// T49: a yes/no field is a checkbox. Unchecking keeps "false" only when the field already had a value,
/// so an untouched box stays empty (no answer) instead of becoming "no".
class BooleanFieldInput extends StatelessWidget {
  const BooleanFieldInput({super.key, required this.label, required this.value, required this.onChanged, required this.french});
  final String label, value;
  final ValueChanged<String> onChanged;
  final bool french;

  @override
  Widget build(BuildContext context) {
    final checked = value == 'true';
    final state = checked ? (french ? 'Oui' : 'Yes') : value == 'false' ? (french ? 'Non' : 'No') : '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: checked,
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(state),
          onChanged: (next) => onChanged(next == true ? 'true' : value.isEmpty ? '' : 'false'),
        ),
      ),
    );
  }
}
