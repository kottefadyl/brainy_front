import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'collections_api.dart';

typedef DayRange = ({String from, String to});

String isoDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Current week (Monday to Sunday), month and year, in the device's calendar.
({DayRange week, DayRange month, DayRange year}) periodRanges(DateTime today) {
  final sinceMonday = today.weekday - 1;
  return (
    week: (
      from: isoDay(DateTime(today.year, today.month, today.day - sinceMonday)),
      to: isoDay(DateTime(today.year, today.month, today.day - sinceMonday + 6)),
    ),
    month: (
      from: isoDay(DateTime(today.year, today.month)),
      to: isoDay(DateTime(today.year, today.month + 1, 0)),
    ),
    year: (from: '${today.year}-01-01', to: '${today.year}-12-31'),
  );
}

/// Accepts "12 500", "12500,50" or "12500.50"; null when it is not an amount.
String? parseAmount(String text) {
  final compact = text.replaceAll(RegExp(r'\s'), '').replaceFirst(',', '.');
  return RegExp(r'^\d+(\.\d+)?$').hasMatch(compact) ? compact : null;
}

/// Groups thousands on the text itself, so a total stays exact.
String formatAmount(String value, {required bool french}) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(value);
  if (match == null) return value;
  final whole = match.group(2)!.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => french ? ' ' : ',',
  );
  final decimals = match.group(3);
  return '${match.group(1)}$whole${decimals == null ? '' : '${french ? ',' : '.'}$decimals'}';
}

class PeriodTotalsPanel extends StatefulWidget {
  const PeriodTotalsPanel({
    super.key,
    required this.api,
    required this.collection,
    required this.entries,
    required this.french,
    required this.onSaved,
  });

  final CollectionsApi api;
  final BrainyCollection collection;
  final List<BrainyEntry> entries;
  final bool french;
  final VoidCallback onSaved;

  @override
  State<PeriodTotalsPanel> createState() => _PeriodTotalsPanelState();
}

class _PeriodTotalsPanelState extends State<PeriodTotalsPanel> {
  final _amount = TextEditingController();
  final _date = TextEditingController(text: isoDay(DateTime.now()));
  ({String week, String month, String year})? _totals;
  int _generation = 0;
  bool _failed = false, _busy = false;
  String? _error, _notice;

  bool get _fr => widget.french;

  BrainyFormat? get _format {
    final config = widget.collection.periodTotals;
    return widget.collection.formats
        .where((item) => item.id == config?.formatId)
        .firstOrNull;
  }

  BrainyField? _field(String? id) =>
      _format?.fields.where((item) => item.id == id).firstOrNull;
  BrainyField? get _dateField =>
      _field(widget.collection.periodTotals?.dateFieldId);
  BrainyField? get _amountField =>
      _field(widget.collection.periodTotals?.amountFieldId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PeriodTotalsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Entries are paginated, so the sums come from the API; any change to the list refreshes them.
    if (oldWidget.collection.id != widget.collection.id ||
        !identical(oldWidget.entries, widget.entries)) {
      _load();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final format = _format, date = _dateField, amount = _amountField;
    if (format == null || date == null || amount == null) return;
    final generation = ++_generation;
    Future<String> sum(DayRange range) async {
      final result = await widget.api.analyse(widget.collection.id, {
        'formatId': format.id,
        'fieldId': amount.id,
        'dateFieldId': date.id,
        'groupBy': 'NONE',
        'operation': 'SUM',
        'measureKind': 'EVENT',
        'from': range.from,
        'to': range.to,
      });
      final rows = result['rows'] as List<dynamic>? ?? const [];
      return rows.isEmpty
          ? '0'
          : (rows.first as Map<String, dynamic>)['value'] as String;
    }

    final ranges = periodRanges(DateTime.now());
    try {
      final values = await Future.wait([
        sum(ranges.week),
        sum(ranges.month),
        sum(ranges.year),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _totals = (week: values[0], month: values[1], year: values[2]);
        _failed = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date.text) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (day != null && mounted) _date.text = isoDay(day);
  }

  Future<void> _save() async {
    final stored = parseAmount(_amount.text);
    if (stored == null) {
      setState(() {
        _notice = null;
        _error = _fr
            ? 'Saisissez un montant, par exemple 12500.'
            : 'Enter an amount, for example 12500.';
      });
      return;
    }
    if (_date.text.isEmpty) {
      setState(() {
        _notice = null;
        _error = _fr ? 'Choisissez la date.' : 'Choose the date.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.api.saveEntry(widget.collection.id, {
        _dateField!.id: _date.text,
        _amountField!.id: stored,
      }, formatId: _format!.id);
      if (!mounted) return;
      final shown = '${formatAmount(stored, french: _fr)}$_unit';
      setState(() {
        _notice = _fr ? 'Enregistré : $shown' : 'Saved: $shown';
        _amount.clear();
        _date.text = isoDay(DateTime.now());
      });
      widget.onSaved();
    } catch (cause) {
      if (mounted) {
        setState(
          () => _error = _fr
              ? 'Enregistrement impossible : $cause'
              : 'Could not save: $cause',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _unit {
    final unit = _amountField?.unit;
    return unit == null || unit.isEmpty ? '' : ' $unit';
  }

  String _shown(String? value) =>
      value == null ? '…' : '${formatAmount(value, french: _fr)}$_unit';

  Widget _figures(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const tabular = [FontFeature.tabularFigures()];
    Widget tile(String label, String? value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _shown(value),
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: tabular,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _fr ? 'Ce mois-ci' : 'This month',
          style: text.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _shown(_totals?.month),
          style: text.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: tabular,
          ),
        ),
        Text(
          MaterialLocalizations.of(context).formatMonthYear(DateTime.now()),
          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile(_fr ? 'Cette semaine' : 'This week', _totals?.week),
            const SizedBox(width: 8),
            tile(_fr ? 'Cette année' : 'This year', _totals?.year),
          ],
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _fr
                      ? 'Les totaux n’ont pas pu être chargés.'
                      : 'The totals could not be loaded.',
                ),
                TextButton(
                  onPressed: _load,
                  child: Text(_fr ? 'Réessayer' : 'Retry'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _form(BuildContext context, BrainyField date, BrainyField amount) {
    final colors = Theme.of(context).colorScheme;
    final unit = amount.unit == null || amount.unit!.isEmpty
        ? ''
        : ' · ${amount.unit}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _fr ? 'Bilan du jour' : 'Today’s sales',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '${amount.name}$unit'),
        ),
        const SizedBox(height: 12),
        LocalizedDateField(
          controller: _date,
          kind: StoredDateKind.date,
          label: date.name,
          clearable: false,
          onPick: _pickDate,
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _busy ? null : _save,
          child: Text(
            _busy
                ? _fr
                      ? 'Enregistrement…'
                      : 'Saving…'
                : _fr
                ? 'Enregistrer'
                : 'Save',
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error!, style: TextStyle(color: colors.error)),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _notice!,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _dateField, amount = _amountField;
    if (date == null || amount == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: _fr ? 'Totaux des ventes' : 'Sales totals',
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final figures = _figures(context);
            final form = _form(context, date, amount);
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [figures, const SizedBox(height: 20), form],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: figures),
                const SizedBox(width: 24),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }
}
