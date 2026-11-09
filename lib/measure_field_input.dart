import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'entry_editor_pickers.dart';

/// Measure value with its status and optional details, like the web form.
class MeasureFieldInput extends StatefulWidget {
  const MeasureFieldInput({
    super.key,
    required this.label,
    required this.controller,
    required this.french,
    required this.onChanged,
    this.unit,
    this.initial,
  });

  final String label;
  final String? unit;
  final TextEditingController controller;
  final bool french;
  final Map<String, String>? initial;
  final ValueChanged<Map<String, String>> onChanged;

  @override
  State<MeasureFieldInput> createState() => _MeasureFieldInputState();
}

class _MeasureFieldInputState extends State<MeasureFieldInput> {
  late String _status = widget.initial?['status'] ?? 'MEASURED';
  late String _uncertaintyType = widget.initial?['uncertaintyType'] ?? 'ABSOLUTE';
  late final _uncertainty = TextEditingController(text: widget.initial?['uncertainty'] ?? '');
  late final _quality = TextEditingController(text: widget.initial?['quality'] ?? '');
  late final _instrument = TextEditingController(text: widget.initial?['instrument'] ?? '');
  late final _observedAt = TextEditingController(text: widget.initial?['observedAt'] ?? '');

  bool get fr => widget.french;
  bool get _absent => _status == 'ABSENT';

  @override
  void initState() {
    super.initState();
    for (final controller in [_uncertainty, _quality, _instrument, _observedAt]) {
      controller.addListener(_emit);
    }
  }

  @override
  void dispose() {
    for (final controller in [_uncertainty, _quality, _instrument, _observedAt]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final uncertainty = _uncertainty.text.trim();
    final quality = _quality.text.trim();
    final instrument = _instrument.text.trim();
    final observedAt = _observedAt.text.trim();
    widget.onChanged({
      'status': _status,
      if (uncertainty.isNotEmpty) ...{
        'uncertainty': uncertainty,
        'uncertaintyType': _uncertaintyType,
      },
      if (quality.isNotEmpty) 'quality': quality,
      if (instrument.isNotEmpty) 'instrument': instrument,
      if (observedAt.isNotEmpty) 'observedAt': observedAt,
    });
  }

  void _setStatus(String? value) {
    if (value == null) return;
    setState(() => _status = value);
    _emit();
  }

  void _setUncertaintyType(String? value) {
    if (value == null) return;
    setState(() => _uncertaintyType = value);
    _emit();
  }

  DropdownMenuItem<String> _item(String value, String label) => DropdownMenuItem(
    value: value,
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final hasDetails = initial != null &&
        ['uncertainty', 'quality', 'instrument', 'observedAt'].any(initial.containsKey);
    final value = TextField(
      controller: widget.controller,
      enabled: !_absent,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: _absent ? (fr ? 'Valeur absente' : 'Absent value') : (fr ? 'Ex. 12,5' : 'E.g. 12.5'),
        suffixText: widget.unit,
      ),
    );
    final status = DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _status,
      decoration: InputDecoration(labelText: fr ? 'Statut' : 'Status'),
      items: [
        _item('MEASURED', fr ? 'Mesurée' : 'Measured'),
        _item('ESTIMATED', fr ? 'Estimée' : 'Estimated'),
        _item('CALCULATED', fr ? 'Calculée' : 'Calculated'),
        _item('ABSENT', fr ? 'Absente' : 'Absent'),
      ],
      onChanged: _setStatus,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 420
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [value, const SizedBox(height: 12), status],
                  )
                : Row(
                    children: [
                      Expanded(flex: 3, child: value),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: status),
                    ],
                  ),
          ),
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
            initiallyExpanded: hasDetails,
            title: Text(
              fr
                  ? 'Détails de mesure (incertitude, instrument, qualité)'
                  : 'Measurement details (uncertainty, instrument, quality)',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _uncertainty,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: fr ? 'Incertitude' : 'Uncertainty',
                        hintText: fr ? '0,05' : '0.05',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 84,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _uncertaintyType,
                      decoration: InputDecoration(labelText: fr ? 'Type' : 'Type'),
                      items: [_item('ABSOLUTE', '±'), _item('RELATIVE', '%')],
                      onChanged: _setUncertaintyType,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quality,
                decoration: InputDecoration(
                  labelText: fr ? 'Qualité' : 'Quality',
                  hintText: fr ? 'ex. A, Étalonné' : 'e.g. A, Calibrated',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instrument,
                decoration: InputDecoration(
                  labelText: 'Instrument / Source',
                  hintText: fr ? 'ex. Capteur PT100' : 'e.g. Sensor PT100',
                ),
              ),
              const SizedBox(height: 12),
              LocalizedDateField(
                controller: _observedAt,
                kind: StoredDateKind.dateTime,
                label: fr ? "Date d'observation" : 'Observed at',
                onPick: () => pickEntryDateTime(context, _observedAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
