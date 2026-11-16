// "Calculations and statistics": chosen when a collection is created and changeable by its owner in "Manage".
// When off, no maths appears anywhere for that collection, so beginners are never lost in it.
import 'package:flutter/material.dart';

class CalculationsChoice extends StatelessWidget {
  const CalculationsChoice({super.key, required this.value, required this.french, required this.onChanged});
  final bool value, french;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: value,
        onChanged: (checked) => onChanged(checked ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        secondary: Icon(Icons.calculate_outlined, color: scheme.primary),
        title: Text(french ? 'Calculs et statistiques' : 'Calculations and statistics', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(value
            ? (french ? 'Totaux, formules, graphiques, analyses, stock et conversions d’unités seront proposés.' : 'Totals, formulas, charts, analyses, stock and unit conversions will be offered.')
            : (french ? 'Collection simple : aucun calcul ni statistique ne sera affiché. Le propriétaire peut les activer plus tard dans « Gérer ».' : 'Simple collection: no calculations or statistics are shown. The owner can turn them on later in “Manage”.')),
      ),
    );
  }
}
