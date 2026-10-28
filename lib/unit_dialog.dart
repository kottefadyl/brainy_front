import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';
import 'number_units.dart';

class UnitDialog extends StatefulWidget {
  const UnitDialog({super.key, required this.collection, required this.api});
  final BrainyCollection collection;
  final CollectionsApi api;

  @override
  State<UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<UnitDialog> {
  late BrainyCollection _collection = widget.collection;
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  final _dimension = TextEditingController(text: 'COUNT');
  final _factor = TextEditingController(text: '1');
  final _amount = TextEditingController(text: '20');
  final _rate = TextEditingController();
  List<BrainyUnit> _available = [];
  BrainyUnit? _editing;
  String? _base;
  String? _objectFormatId;
  String _from = 'm';
  String _to = 'km';
  String _rateFrom = 'EUR';
  String _rateTo = 'USD';
  DateTime _date = DateTime.now();
  String? _result;
  String? _error;
  bool _busy = false;

  String _t(String value) => AppStrings.of(context).text(value);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final available = await widget.api.availableUnits(_collection.id);
      if (mounted) setState(() => _available = available);
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _symbol,
      _dimension,
      _factor,
      _amount,
      _rate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _edit(BrainyUnit? unit) {
    setState(() {
      _editing = unit;
      _name.text = unit?.name ?? '';
      _symbol.text = unit?.symbol ?? '';
      _dimension.text = unit?.dimension ?? 'COUNT';
      _base = unit?.baseUnitId;
      _factor.text = unit?.factor ?? '1';
      _objectFormatId = unit?.objectFormatId;
      _error = null;
    });
  }

  Future<void> _saveUnit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.api.saveUnit(_collection.id, {
        'name': _name.text.trim(),
        'symbol': _symbol.text.trim(),
        'dimension': _dimension.text.trim().toUpperCase(),
        'factor': normalizeFieldNumber(_factor.text),
        if (_base != null) 'baseUnitId': _base,
        if (_objectFormatId != null) 'objectFormatId': _objectFormatId,
        if (_editing != null) 'expectedVersion': _editing!.version,
      }, unitId: _editing?.id);
      if (!mounted) return;
      setState(() => _collection = updated);
      _edit(null);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.convertQuantity(
        _collection.id,
        normalizeFieldNumber(_amount.text),
        _from,
        _to,
        asOf: DateTime(_date.year, _date.month, _date.day, 23, 59, 59).toUtc(),
      );
      if (mounted) {
        setState(
          () => _result =
              '${_amount.text} ${result.fromSymbol} = ${result.value} ${result.toSymbol}',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveRate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.api.recordExchangeRate(_collection.id, {
        'from': _rateFrom,
        'to': _rateTo,
        'rate': normalizeFieldNumber(_rate.text),
        'effectiveAt': DateTime.utc(
          _date.year,
          _date.month,
          _date.day,
        ).toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        _collection = updated;
        _rate.clear();
        _result = _t('Exchange rate saved');
      });
    } catch (error) {
      if (mounted) setState(() => _error = AppStrings.of(context).error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String _label(BrainyUnit unit) {
    final standard = numberUnit(unit.id);
    return standard == null
        ? '${unit.name} (${unit.symbol})'
        : unitChoiceLabel(AppStrings.of(context), standard);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseOptions = _available
        .where(
          (unit) =>
              unit.dimension == _dimension.text.trim().toUpperCase() &&
              unit.id != _editing?.id,
        )
        .toList();
    final currencies = _available
        .where((unit) => unit.dimension == 'CURRENCY')
        .toList();
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: dark ? const Color(0xFFEEF0F2) : const Color(0xFF252B36),
    );
    return AlertDialog(
      backgroundColor: dark ? const Color(0xFF1C1F23) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(_t('Units and conversions')),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExpansionTile(
                initiallyExpanded: false,
                title: Text(_t('Units in this collection')),
                leading: const Icon(Icons.straighten_rounded),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final unit in _collection.units)
                        ActionChip(
                          label: Text('${unit.name} · ${unit.symbol}'),
                          onPressed: _busy ? null : () => _edit(unit),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _edit(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(_t('New unit')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: _t('Unit name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _symbol,
                          decoration: InputDecoration(
                            labelText: _t('Symbol'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _dimension,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() => _base = null),
                          decoration: InputDecoration(
                            labelText: _t('Dimension'),
                            hintText: 'COUNT',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: baseOptions.any((item) => item.id == _base)
                        ? _base
                        : null,
                    decoration: InputDecoration(
                      labelText: _t('Base unit'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(_t('No base unit')),
                      ),
                      for (final unit in baseOptions)
                        DropdownMenuItem(
                          value: unit.id,
                          child: Text(
                            _label(unit),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _base = value;
                            if (value == null) _factor.text = '1';
                          }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _factor,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _t('Factor'),
                      helperText: _t('One carton of 12 bottles has factor 12.'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_dimension.text.trim().toUpperCase() == 'COUNT') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _objectFormatId,
                      decoration: InputDecoration(
                        labelText: _t('Object data format'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(_t('Any item')),
                        ),
                        for (final format in _collection.formats)
                          DropdownMenuItem(
                            value: format.id,
                            child: Text(
                              format.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _objectFormatId = value),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _busy ? null : _saveUnit,
                    child: Text(_t('Save unit')),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(_t('Convert'), style: labelStyle),
              const SizedBox(height: 6),
              Text(
                AppStrings.of(context).isFrench
                    ? 'Choisissez une quantité et deux unités compatibles.'
                    : 'Choose an amount and two compatible units.',
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFB4B2B8)
                      : const Color(0xFF63758E),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t('Amount'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _available.any((unit) => unit.id == _from)
                          ? _from
                          : null,
                      decoration: InputDecoration(
                        labelText: _t('From'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final unit in _available)
                          DropdownMenuItem(
                            value: unit.id,
                            child: Text(
                              _label(unit),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _from = value ?? _from),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _available.any((unit) => unit.id == _to)
                          ? _to
                          : null,
                      decoration: InputDecoration(
                        labelText: _t('To'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final unit in _available)
                          DropdownMenuItem(
                            value: unit.id,
                            child: Text(
                              _label(unit),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _to = value ?? _to),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 17),
                label: Text(
                  '${_t('As of')}: ${_date.day}/${_date.month}/${_date.year}',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _busy || _available.isEmpty ? null : _convert,
                child: Text(_t('Convert')),
              ),
              const Divider(height: 32),
              ExpansionTile(
                title: Text(_t('Exchange rate')),
                leading: const Icon(Icons.currency_exchange_rounded),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  Text(
                    _t(
                      'Currency rates are dated and do not change older entries.',
                    ),
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFB4B2B8)
                          : const Color(0xFF63758E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
                              currencies.any((unit) => unit.id == _rateFrom)
                              ? _rateFrom
                              : null,
                          decoration: InputDecoration(
                            labelText: _t('From'),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final unit in currencies)
                              DropdownMenuItem(
                                value: unit.id,
                                child: Text(
                                  _label(unit),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _rateFrom = value ?? _rateFrom),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
                              currencies.any((unit) => unit.id == _rateTo)
                              ? _rateTo
                              : null,
                          decoration: InputDecoration(
                            labelText: _t('To'),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final unit in currencies)
                              DropdownMenuItem(
                                value: unit.id,
                                child: Text(
                                  _label(unit),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _rateTo = value ?? _rateTo),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _t('Rate'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _busy || currencies.length < 2
                        ? null
                        : _saveRate,
                    child: Text(_t('Save rate')),
                  ),
                ],
              ),
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _result!,
                    style: const TextStyle(
                      color: Color(0xFF245B9B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, _collection),
          child: Text(_t('Close')),
        ),
      ],
    );
  }
}
