import 'package:flutter/material.dart';

import 'duration.dart';

/// Unit of a duration field in the data format editor (seconds to weeks, or the classic hours:minutes).
class DurationUnitDropdown extends StatelessWidget {
  const DurationUnitDropdown({super.key, required this.value, required this.french, required this.onChanged});
  final String value;
  final bool french;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: isDurationUnit(value) ? value : '',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: french ? 'Unité' : 'Unit',
          helperText: french ? 'Unité de saisie et d’affichage ; les calculs restent exacts si elle change.' : 'Unit to type and show it in; calculations stay exact if it changes.',
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(value: '', child: Text(french ? 'Heures:minutes (1:30)' : 'Hours:minutes (1:30)', overflow: TextOverflow.ellipsis)),
          for (final unit in durationUnits.keys) DropdownMenuItem(value: unit, child: Text(durationUnitLabel(unit, french), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (unit) => onChanged(unit ?? ''),
      );
}
