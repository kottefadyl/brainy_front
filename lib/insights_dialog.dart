import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';

Future<BrainyCollection?> showInsightsDialog(
  BuildContext context,
  CollectionsApi api,
  BrainyCollection collection, {
  required Future<void> Function(String) onOpenEntry,
}) => Navigator.of(context).push<BrainyCollection>(
  MaterialPageRoute(
    builder: (context) => _InsightsDialog(
      api: api,
      collection: collection,
      onOpenEntry: onOpenEntry,
    ),
  ),
);

class _InsightsDialog extends StatefulWidget {
  const _InsightsDialog({
    required this.api,
    required this.collection,
    required this.onOpenEntry,
  });
  final CollectionsApi api;
  final BrainyCollection collection;
  final Future<void> Function(String) onOpenEntry;
  @override
  State<_InsightsDialog> createState() => _InsightsDialogState();
}

class _Source {
  const _Source(this.id, this.label, this.expression);
  final String id;
  final String label;
  final Map<String, dynamic> expression;
}

class _InsightsDialogState extends State<_InsightsDialog> {
  final _resultsKey = GlobalKey();
  late BrainyCollection collection = widget.collection;
  late String formatId = collection.formats.first.id;
  final name = TextEditingController();
  final constant = TextEditingController();
  final filterValue = TextEditingController();
  final percentileCtrl = TextEditingController(text: '95');
  final rateBaseCtrl = TextEditingController(text: '1000');
  final denominatorValueCtrl = TextEditingController();
  final windowSizeCtrl = TextEditingController(text: '3');
  String? left, right, measure, dateFieldId, groupFieldId, zoneFormatId, zoneFieldId;
  int groupDepth = 2;
  String? secondaryGroupFieldId, denominatorFieldId, weightFieldId, counterResetFieldId;
  String secondaryGroupBy = 'MONTH';
  String? formulaFromFieldId, formulaToFieldId;
  String formulaKind = 'arithmetic', formulaDateUnit = 'd';
  String? roundDigits;
  String roundMode = 'HALF_UP';
  String? editingFormulaId;
  int? editingVersion;
  String? from, to, comparisonFrom, comparisonTo;
  String? filterFieldId;
  String filterOperator = 'EQ';
  final List<Map<String, String>> filters = [];
  String operator = 'MULTIPLY',
      operation = 'SUM',
      groupBy = 'DAY',
      measureKind = 'EVENT',
      chart = 'TABLE';
  Map<String, dynamic>? result;
  Map<String, dynamic>? forecastResult;
  String forecastMethod = 'MEAN', forecastFrequency = 'MONTH';
  int forecastHorizon = 3;
  Map<String, dynamic>? lastAnalysisInput;
  String? error;
  bool busy = false;

  BrainyFormat get format =>
      collection.formats.firstWhere((item) => item.id == formatId);
  List<_Source> get sources {
    final values = <_Source>[];
    for (final field in format.fields) {
      if (field.kind == BrainyFieldKind.number) {
        values.add(
          _Source(field.id, field.name, {'kind': 'field', 'fieldId': field.id}),
        );
      }
      if (field.kind == BrainyFieldKind.objectRef && !field.multiple) {
        for (final target in collection.formats.where(
          (item) => item.id == field.targetObjectFormatId,
        )) {
          for (final property in target.fields.where(
            (item) => item.kind == BrainyFieldKind.number,
          )) {
            values.add(
              _Source(
                '${field.id}:${property.id}',
                '${field.variableName ?? field.name}.${property.name}',
                {
                  'kind': 'property',
                  'referenceFieldId': field.id,
                  'propertyFieldId': property.id,
                },
              ),
            );
          }
        }
      }
    }
    for (final formula in formulas) {
      values.add(
        _Source('formula:${formula['id']}', 'ƒ ${formula['name']}', {
          'kind': 'formula',
          'formulaId': formula['id'],
        }),
      );
    }
    return values;
  }

  List<Map<String, dynamic>> get formulas => collection.formulas
      .where((item) => item['formatId'] == formatId)
      .toList();

  @override
  void dispose() {
    name.dispose();
    constant.dispose();
    filterValue.dispose();
    percentileCtrl.dispose();
    rateBaseCtrl.dispose();
    denominatorValueCtrl.dispose();
    windowSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> saveFormula() async {
    if (name.text.trim().isEmpty ||
        (formulaKind == 'arithmetic'
            ? left == null || (right == null && constant.text.trim().isEmpty)
            : formulaFromFieldId == null || formulaToFieldId == null)) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final tree = formulaKind == 'dateDifference'
          ? <String, dynamic>{
              'kind': 'dateDifference',
              'fromFieldId': formulaFromFieldId,
              'toFieldId': formulaToFieldId,
              'unit': formulaDateUnit,
            }
          : <String, dynamic>{
              'kind': 'operation',
              'operator': operator,
              'args': [
                sources.firstWhere((item) => item.id == left).expression,
                right == null
                    ? {
                        'kind': 'number',
                        'value': constant.text.trim().replaceAll(',', '.'),
                      }
                    : sources.firstWhere((item) => item.id == right).expression,
              ],
            };
      final expression = jsonEncode(
        roundDigits == null
            ? tree
            : {
                'kind': 'round',
                'digits': int.parse(roundDigits!),
                'mode': roundMode,
                'value': tree,
              },
      );
      final updated = await widget.api.saveFormula(
        collection.id,
        name.text.trim(),
        format.id,
        expression,
        formulaId: editingFormulaId,
        expectedVersion: editingVersion,
      );
      if (mounted) {
        setState(() {
          collection = updated;
          name.clear();
          constant.clear();
          left = null;
          right = null;
          formulaFromFieldId = null;
          formulaToFieldId = null;
          roundDigits = null;
          editingFormulaId = null;
          editingVersion = null;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = cause.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void editFormula(Map<String, dynamic> formula) {
    try {
      final stored =
          jsonDecode(formula['expression'] as String) as Map<String, dynamic>;
      final tree = stored['kind'] == 'round'
          ? stored['value'] as Map<String, dynamic>
          : stored;
      if (tree['kind'] != 'operation' && tree['kind'] != 'dateDifference') {
        throw const FormatException('Unsupported formula shape');
      }
      String? sourceId(dynamic node) {
        if (node is! Map<String, dynamic>) return null;
        for (final source in sources) {
          if (jsonEncode(source.expression) == jsonEncode(node)) {
            return source.id;
          }
        }
        return null;
      }

      final args = tree['kind'] == 'operation'
          ? (tree['args'] as List<dynamic>)
          : <dynamic>[];
      final first = args.length == 2 ? sourceId(args[0]) : null;
      final second = args.length == 2 ? sourceId(args[1]) : null;
      if (tree['kind'] == 'operation' &&
          (first == null ||
              (second == null &&
                  (args.length != 2 ||
                      (args[1] as Map<String, dynamic>)['kind'] != 'number')))) {
        throw const FormatException('Unsupported formula operands');
      }
      setState(() {
        error = null;
        editingFormulaId = formula['id'] as String;
        editingVersion = formula['version'] as int;
        name.text = formula['name'] as String;
        roundDigits = stored['kind'] == 'round' ? '${stored['digits']}' : null;
        roundMode = stored['kind'] == 'round'
            ? stored['mode'] as String
            : 'HALF_UP';
        formulaKind = tree['kind'] == 'dateDifference'
            ? 'dateDifference'
            : 'arithmetic';
        if (formulaKind == 'dateDifference') {
          formulaFromFieldId = tree['fromFieldId'] as String;
          formulaToFieldId = tree['toFieldId'] as String;
          formulaDateUnit = tree['unit'] as String;
        } else {
          operator = tree['operator'] as String;
          left = first;
          right = second;
          constant.text = second == null
              ? (args[1] as Map<String, dynamic>)['value'] as String
              : '';
        }
      });
    } catch (_) {
      setState(
        () => error = AppStrings.of(context).isFrench
            ? 'Cette formule ne peut pas être modifiée visuellement.'
            : 'This formula cannot be edited visually.',
      );
    }
  }

  Future<void> analyse() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final input = <String, dynamic>{
        'formatId': formatId,
        'operation': operation,
        'groupBy': groupBy,
        'language': AppStrings.of(context).isFrench ? 'fr' : 'en',
        if (groupBy == 'CATEGORY' && format.fields.any((field) => field.id == groupFieldId && field.kind == BrainyFieldKind.code)) 'groupDepth': groupDepth,
        'measureKind': measureKind,
        if (measure?.startsWith('formula:') == true)
          'formulaId': measure!.substring(8)
        else if (measure != null)
          'fieldId': measure,
        if (dateFieldId != null) 'dateFieldId': dateFieldId,
        if (groupFieldId != null || groupBy == 'ZONE') 'groupFieldId': groupFieldId ?? format.fields.where((field) => field.kind == BrainyFieldKind.position).firstOrNull?.id,
        if (groupBy == 'ZONE') ...{'zoneFormatId': zoneFormatId, 'zoneFieldId': zoneFieldId},
        if (operation == 'CROSSTAB') ...{
          'secondaryGroupBy': secondaryGroupBy,
          if (secondaryGroupFieldId != null)
            'secondaryGroupFieldId': secondaryGroupFieldId,
        },
        if (operation == 'PERCENTILE' &&
            double.tryParse(percentileCtrl.text.trim().replaceAll(',', '.')) !=
                null)
          'percentile': double.parse(
            percentileCtrl.text.trim().replaceAll(',', '.'),
          ),
        if (operation == 'RATE_PER_N') ...{
          if (double.tryParse(rateBaseCtrl.text.trim().replaceAll(',', '.')) !=
              null)
            'rateBase': double.parse(
              rateBaseCtrl.text.trim().replaceAll(',', '.'),
            ),
          if (denominatorFieldId != null)
            'denominatorFieldId': denominatorFieldId
          else if (denominatorValueCtrl.text.trim().isNotEmpty)
            'denominatorValue':
                denominatorValueCtrl.text.trim().replaceAll(',', '.'),
        },
        if (weightFieldId != null &&
            const ['SUM', 'AVERAGE', 'RATE_PER_N', 'CROSSTAB']
                .contains(operation))
          'weightFieldId': weightFieldId,
        if (operation == 'MOVING_AVERAGE' &&
            int.tryParse(windowSizeCtrl.text.trim()) != null)
          'windowSize': int.parse(windowSizeCtrl.text.trim()),
        if (operation == 'SUCCESSIVE_DIFF' && counterResetFieldId != null)
          'counterResetFieldId': counterResetFieldId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (comparisonFrom != null) 'comparisonFrom': comparisonFrom,
        if (comparisonTo != null) 'comparisonTo': comparisonTo,
        if (filters.isNotEmpty ||
            (filterFieldId != null && filterValue.text.trim().isNotEmpty))
          'filters': [
            ...filters,
            if (filterFieldId != null && filterValue.text.trim().isNotEmpty)
              {
                'fieldId': filterFieldId,
                'operator': filterOperator,
                'value': filterValue.text.trim(),
              },
          ],
      };
      final data = await widget.api.analyse(collection.id, input);
      if (mounted) {
        setState(() {
          result = data;
          lastAnalysisInput = input;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final resultsContext = _resultsKey.currentContext;
        if (mounted && resultsContext != null) {
          Scrollable.ensureVisible(resultsContext);
        }
      });
    } catch (cause) {
      if (mounted) setState(() => error = cause.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> runForecast() async {
    if (measure == null || measure!.startsWith('formula:') || dateFieldId == null) return;
    setState(() { busy = true; error = null; forecastResult = null; });
    try {
      final data = await widget.api.forecast(collection.id, {'formatId': formatId, 'fieldId': measure, 'dateFieldId': dateFieldId, 'frequency': forecastFrequency, 'method': forecastMethod, 'measureKind': measureKind, if (from != null) 'from': from, if (to != null) 'to': to, 'horizon': forecastHorizon, 'holdout': 2});
      if (mounted) setState(() => forecastResult = data);
    } catch (cause) { if (mounted) setState(() => error = '$cause'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  BrainyFormat? get quickChartFormat {
    for (final candidate in collection.formats) {
      final hasDate = candidate.fields.any(
        (field) =>
            field.kind == BrainyFieldKind.date ||
            field.kind == BrainyFieldKind.datetime,
      );
      final hasMeasure =
          candidate.fields.any(
            (field) => field.kind == BrainyFieldKind.number,
          ) ||
          collection.formulas.any(
            (formula) => formula['formatId'] == candidate.id,
          );
      if (hasDate && hasMeasure) return candidate;
    }
    return null;
  }

  Future<void> quickChart() async {
    final candidate = quickChartFormat;
    if (candidate == null) return;
    final date = candidate.fields.firstWhere(
      (field) =>
          field.kind == BrainyFieldKind.date ||
          field.kind == BrainyFieldKind.datetime,
    );
    final formula = collection.formulas
        .where((item) => item['formatId'] == candidate.id)
        .firstOrNull;
    final numeric = candidate.fields
        .where((item) => item.kind == BrainyFieldKind.number)
        .firstOrNull;
    if (formula == null && numeric == null) return;
    setState(() {
      formatId = candidate.id;
      dateFieldId = date.id;
      measure = formula != null ? 'formula:${formula['id']}' : numeric!.id;
      operation = formula != null ? 'SUM' : 'AVERAGE';
      measureKind = formula != null ? 'EVENT' : 'SNAPSHOT';
      groupBy = 'DAY';
      groupFieldId = null;
      from = null;
      to = null;
      comparisonFrom = null;
      comparisonTo = null;
      filterFieldId = null;
      filterValue.clear();
      filters.clear();
      chart = 'LINE';
      result = null;
    });
    await analyse();
  }

  Future<void> loadMore(String group, {bool comparison = false}) async {
    if (busy || result == null || lastAnalysisInput == null) return;
    final key = comparison ? 'comparisonRows' : 'rows';
    final rows =
        (result![key] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final current = rows.where((row) => row['group'] == group).firstOrNull;
    if (current == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await widget.api.analyse(collection.id, {
        ...lastAnalysisInput!,
        'sourceGroup': group,
        'sourceOffset': (current['sources'] as List<dynamic>).length,
      });
      final nextRows =
          (page[key] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final incoming = nextRows
          .where((row) => row['group'] == group)
          .firstOrNull;
      if (incoming != null && mounted) {
        setState(() {
          final oldSources = (current['sources'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          final seen = oldSources.map((source) => source['entryId']).toSet();
          current['sources'] = [
            ...oldSources,
            for (final source
                in (incoming['sources'] as List<dynamic>)
                    .cast<Map<String, dynamic>>())
              if (seen.add(source['entryId'])) source,
          ];
          current['sourcesHasMore'] = incoming['sourcesHasMore'];
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = cause.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget select(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: items,
    onChanged: changed,
  );
  List<DropdownMenuItem<String>> options(
    List<String> values, {
    Map<String, String> labels = const {},
  }) => [
    for (final value in values)
      DropdownMenuItem(value: value, child: Text(labels[value] ?? value)),
  ];

  Widget dateFilter(
    String label,
    String? value,
    ValueChanged<String?> changed,
  ) => OutlinedButton.icon(
    onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value == null ? DateTime.now() : DateTime.parse(value),
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );
      if (picked != null) {
        changed(
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
        );
      }
    },
    icon: const Icon(Icons.event),
    label: Text('$label: ${value ?? '—'}'),
  );

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final numeric = format.fields
        .where((item) => item.kind == BrainyFieldKind.number)
        .toList();
    final dates = format.fields
        .where(
          (item) =>
              item.kind == BrainyFieldKind.date ||
              item.kind == BrainyFieldKind.datetime,
        )
        .toList();
    dateFieldId ??= dates.firstOrNull?.id;
    final groups = format.fields
        .where(
          (item) => groupBy == 'OBJECT'
              ? item.kind == BrainyFieldKind.objectRef
              : groupBy == 'ZONE'
              ? item.kind == BrainyFieldKind.position
              : item.kind == BrainyFieldKind.select ||
                    item.kind == BrainyFieldKind.text || item.kind == BrainyFieldKind.code,
        )
        .toList();
    final selectedFilter = format.fields
        .where((item) => item.id == filterFieldId)
        .firstOrNull;
    final zoneFormats = collection.formats.where((item) => item.fields.any((field) => field.kind == BrainyFieldKind.zone)).toList();
    zoneFormatId ??= zoneFormats.firstOrNull?.id;
    final zoneFields = zoneFormats.where((item) => item.id == zoneFormatId).firstOrNull?.fields.where((field) => field.kind == BrainyFieldKind.zone).toList() ?? <BrainyField>[];
    zoneFieldId ??= zoneFields.firstOrNull?.id;
    final rows =
        (result?['rows'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final maximum = rows.fold<double>(
      1,
      (current, row) => math.max(
        current,
        double.tryParse(row['value'] as String? ?? '')?.abs() ?? 0,
      ),
    );
    final nonnegative = rows.every(
      (row) => (double.tryParse(row['value'] as String? ?? '') ?? 0) >= 0,
    );
    final pieTotal = rows.fold<double>(
      0,
      (sum, row) => sum + (double.tryParse(row['value'] as String? ?? '') ?? 0),
    );
    final canShowLine = nonnegative && (groupBy == 'DAY' || groupBy == 'MONTH');
    final effectiveChart =
        (chart == 'PIE' && (!nonnegative || pieTotal <= 0)) ||
            (chart == 'LINE' && !canShowLine) ||
            (chart == 'BAR' && !nonnegative)
        ? 'TABLE'
        : chart;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1B1D22) : const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF24272E) : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: fr ? 'Retour à la collection' : 'Back to collection',
          onPressed: () => Navigator.pop(context, collection),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(fr ? 'Calculs et graphiques' : 'Calculations and charts'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 30,
                vertical: 26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF24272E)
                          : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: dark
                            ? const Color(0xFF3E4653)
                            : const Color(0xFFDDE2EA),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: dark
                              ? const Color(0xFF96BDFF)
                              : const Color(0xFF2463CE),
                          size: 28,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          fr
                              ? 'Explorez votre collection'
                              : 'Explore your collection',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          fr
                              ? 'Les résultats ne modifient pas les entrées.'
                              : 'Results do not change entries.',
                        ),
                        if (quickChartFormat != null) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: busy ? null : quickChart,
                            icon: const Icon(Icons.auto_graph_rounded),
                            label: Text(
                              fr ? 'Graphique rapide' : 'Quick chart',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  select(
                    fr ? 'Format de données' : 'Data format',
                    formatId,
                    [
                      for (final item in collection.formats)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                    ],
                    (value) => setState(() {
                      formatId = value!;
                      result = null;
                      measure = null;
                      left = null;
                      right = null;
                      dateFieldId = null;
                      groupFieldId = null;
                      filterFieldId = null;
                      filterValue.clear();
                      filters.clear();
                      editingFormulaId = null;
                      editingVersion = null;
                      name.clear();
                    }),
                  ),
                  const SizedBox(height: 22),
                  ExpansionTile(
                    title: Text(
                      fr
                          ? 'Créer ou modifier une formule'
                          : 'Create or edit a formula',
                    ),
                    leading: const Icon(Icons.calculate_outlined),
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: [
                      TextField(
                        controller: name,
                        decoration: InputDecoration(
                          labelText: fr ? 'Nom du calcul' : 'Calculation name',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      select(
                        fr ? 'Type de calcul' : 'Calculation type',
                        formulaKind,
                        options(
                          ['arithmetic', 'dateDifference'],
                          labels: {
                            'arithmetic': fr ? 'Arithmétique' : 'Arithmetic',
                            'dateDifference': fr
                                ? 'Écart entre deux dates'
                                : 'Difference between dates',
                          },
                        ),
                        (value) => setState(() => formulaKind = value!),
                      ),
                      const SizedBox(height: 8),
                      if (formulaKind == 'arithmetic') ...[
                        select(fr ? 'Première valeur' : 'First value', left, [
                          for (final source in sources)
                            DropdownMenuItem(
                              value: source.id,
                              child: Text(source.label),
                            ),
                        ], (value) => setState(() => left = value)),
                        const SizedBox(height: 8),
                        select(
                          fr ? 'Opération' : 'Operation',
                          operator,
                          options(
                            ['MULTIPLY', 'ADD', 'SUBTRACT', 'DIVIDE'],
                            labels: {
                              'MULTIPLY': '×',
                              'ADD': '+',
                              'SUBTRACT': '−',
                              'DIVIDE': '÷',
                            },
                          ),
                          (value) => setState(() => operator = value!),
                        ),
                        const SizedBox(height: 8),
                        select(
                          fr ? 'Deuxième valeur' : 'Second value',
                          right,
                          [
                            DropdownMenuItem(
                              value: '',
                              child: Text(fr ? 'Nombre fixe' : 'Fixed number'),
                            ),
                            for (final source in sources)
                              DropdownMenuItem(
                                value: source.id,
                                child: Text(source.label),
                              ),
                          ],
                          (value) => setState(
                            () => right = value?.isEmpty == true ? null : value,
                          ),
                        ),
                        if (right == null) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: constant,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: fr ? 'Nombre fixe' : 'Fixed number',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ] else ...[
                        select(
                          fr ? 'Date de début' : 'Start date',
                          formulaFromFieldId,
                          [
                            for (final field in dates)
                              DropdownMenuItem(
                                value: field.id,
                                child: Text(field.name),
                              ),
                          ],
                          (value) => setState(() {
                            formulaFromFieldId = value;
                            formulaToFieldId = null;
                          }),
                        ),
                        const SizedBox(height: 8),
                        select(
                          fr ? 'Date de fin' : 'End date',
                          formulaToFieldId,
                          [
                            for (final field in dates.where(
                              (item) =>
                                  item.kind ==
                                  dates
                                      .where(
                                        (candidate) =>
                                            candidate.id == formulaFromFieldId,
                                      )
                                      .firstOrNull
                                      ?.kind,
                            ))
                              DropdownMenuItem(
                                value: field.id,
                                child: Text(field.name),
                              ),
                          ],
                          (value) => setState(() => formulaToFieldId = value),
                        ),
                        const SizedBox(height: 8),
                        select(
                          fr ? 'Unité' : 'Unit',
                          formulaDateUnit,
                          options(
                            ['d', 'h'],
                            labels: {
                              'd': fr ? 'Jours' : 'Days',
                              'h': fr ? 'Heures' : 'Hours',
                            },
                          ),
                          (value) => setState(() => formulaDateUnit = value!),
                        ),
                      ],
                      const SizedBox(height: 8),
                      select(
                        fr ? 'Décimales du résultat' : 'Result decimal places',
                        roundDigits,
                        [
                          DropdownMenuItem(
                            value: '',
                            child: Text(fr ? 'Aucun arrondi' : 'No rounding'),
                          ),
                          ...options(['0', '1', '2', '3', '4', '5', '6']),
                        ],
                        (value) => setState(
                          () => roundDigits = value?.isEmpty == true
                              ? null
                              : value,
                        ),
                      ),
                      if (roundDigits != null) ...[
                        const SizedBox(height: 8),
                        select(
                          fr ? 'Règle d’arrondi' : 'Rounding rule',
                          roundMode,
                          options(
                            ['HALF_UP', 'HALF_EVEN'],
                            labels: {
                              'HALF_UP': fr ? 'Moitié vers le haut' : 'Half up',
                              'HALF_EVEN': fr
                                  ? 'Moitié vers le pair'
                                  : 'Half even',
                            },
                          ),
                          (value) => setState(() => roundMode = value!),
                        ),
                      ],
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: busy ? null : saveFormula,
                        child: Text(
                          editingFormulaId == null
                              ? (fr ? 'Enregistrer la formule' : 'Save formula')
                              : (fr
                                    ? 'Mettre à jour la formule'
                                    : 'Update formula'),
                        ),
                      ),
                      if (editingFormulaId != null)
                        TextButton(
                          onPressed: () => setState(() {
                            editingFormulaId = null;
                            editingVersion = null;
                            name.clear();
                            constant.clear();
                            left = null;
                            right = null;
                          }),
                          child: Text(
                            fr ? 'Annuler la modification' : 'Cancel editing',
                          ),
                        ),
                      for (final formula in formulas)
                        Row(
                          children: [
                            Expanded(child: Text(formula['name'] as String)),
                            IconButton(
                              tooltip: fr ? 'Modifier' : 'Edit',
                              onPressed: () => editFormula(formula),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: fr ? 'Supprimer' : 'Delete',
                              onPressed: () async {
                                try {
                                  final updated = await widget.api
                                      .deleteFormula(
                                        collection.id,
                                        formula['id'] as String,
                                      );
                                  if (mounted) {
                                    setState(() => collection = updated);
                                  }
                                } catch (cause) {
                                  if (mounted) {
                                    setState(() => error = cause.toString());
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    fr ? 'Analyse' : 'Analysis',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  select(fr ? 'Mesure' : 'Measure', measure, [
                    for (final field in numeric)
                      DropdownMenuItem(
                        value: field.id,
                        child: Text(field.name),
                      ),
                    for (final formula in formulas)
                      DropdownMenuItem(
                        value: 'formula:${formula['id']}',
                        child: Text(formula['name'] as String),
                      ),
                  ], (value) => setState(() => measure = value)),
                  const SizedBox(height: 8),
                  select(
                    fr ? 'Calcul' : 'Calculation',
                    operation,
                    options(
                      [
                        'COUNT',
                        if (groupBy != 'ZONE') ...[
                        'SUM',
                        'AVERAGE',
                        'MIN',
                        'MAX',
                        'MEDIAN',
                        'PERCENTILE',
                        'VARIANCE',
                        'STDDEV',
                        'RANGE',
                        'RATE_PER_N',
                        'CROSSTAB',
                        'CUMULATIVE',
                        'MOVING_AVERAGE',
                        'SUCCESSIVE_DIFF',
                        'SUCCESSIVE_VARIATION',
                        'LINEAR_TREND',
                        ],
                      ],
                      labels: {
                        'COUNT': fr ? 'Nombre' : 'Count',
                        'SUM': fr ? 'Somme' : 'Sum',
                        'AVERAGE': fr ? 'Moyenne' : 'Average',
                        'MEDIAN': fr ? 'Médiane' : 'Median',
                        'PERCENTILE': fr ? 'Centile' : 'Percentile',
                        'VARIANCE': fr ? 'Variance' : 'Variance',
                        'STDDEV': fr ? 'Écart-type' : 'Standard deviation',
                        'RANGE': fr ? 'Étendue (Max − Min)' : 'Range (Max − Min)',
                        'RATE_PER_N': fr ? 'Taux pour N' : 'Rate per N',
                        'CROSSTAB': fr
                            ? 'Tableau croisé (2D)'
                            : 'Cross-tabulation (2D)',
                        'CUMULATIVE': fr ? 'Cumul' : 'Cumulative sum',
                        'MOVING_AVERAGE': fr
                            ? 'Moyenne mobile'
                            : 'Moving average',
                        'SUCCESSIVE_DIFF': fr
                            ? 'Écart successif (compteur)'
                            : 'Successive difference (meter)',
                        'SUCCESSIVE_VARIATION': fr
                            ? 'Variation successive (%)'
                            : 'Successive variation (%)',
                        'LINEAR_TREND': fr
                            ? 'Tendance linéaire'
                            : 'Linear trend',
                      },
                    ),
                    (value) => setState(() => operation = value!),
                  ),
                  const SizedBox(height: 8),
                  select(
                    fr ? 'Nature des valeurs' : 'Value meaning',
                    measureKind,
                    options(
                      groupBy == 'ZONE' ? ['EVENT'] : ['EVENT', 'SNAPSHOT', 'RATE'],
                      labels: {
                        'EVENT': fr ? 'Événements' : 'Events',
                        'SNAPSHOT': fr
                            ? 'Mesures instantanées'
                            : 'Point-in-time measures',
                        'RATE': fr ? 'Taux' : 'Rates',
                      },
                    ),
                    (value) => setState(() => measureKind = value!),
                  ),
                  const SizedBox(height: 8),
                  select(
                    fr ? 'Regrouper par' : 'Group by',
                    groupBy,
                    options(
                      ['NONE', 'DAY', 'MONTH', 'CATEGORY', 'OBJECT', if (zoneFormats.isNotEmpty && format.fields.any((field) => field.kind == BrainyFieldKind.position)) 'ZONE'],
                      labels: {
                        'NONE': fr ? 'Aucun' : 'None',
                        'DAY': fr ? 'Jour' : 'Day',
                        'MONTH': fr ? 'Mois' : 'Month',
                        'CATEGORY': fr ? 'Catégorie' : 'Category',
                        'OBJECT': fr ? 'Objet' : 'Object',
                        'ZONE': fr ? 'Zone' : 'Zone',
                      },
                    ),
                    (value) => setState(() {
                      groupBy = value!;
                      groupFieldId = null;
                      if (groupBy == 'ZONE') { operation = 'COUNT'; measureKind = 'EVENT'; }
                    }),
                  ),
                  if (dates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    select(fr ? 'Champ date' : 'Date field', dateFieldId, [
                      for (final field in dates)
                        DropdownMenuItem(
                          value: field.id,
                          child: Text(field.name),
                        ),
                    ], (value) => setState(() => dateFieldId = value)),
                  ],
                  if (groupBy == 'CATEGORY' || groupBy == 'OBJECT' || groupBy == 'ZONE') ...[
                    const SizedBox(height: 8),
                    select(
                      groupBy == 'ZONE' ? (fr ? 'Champ position' : 'Position field') : (fr ? 'Champ du groupe' : 'Group field'),
                      groupFieldId,
                      [
                        for (final field in groups)
                          DropdownMenuItem(
                            value: field.id,
                            child: Text(field.name),
                          ),
                      ],
                      (value) => setState(() => groupFieldId = value),
                    ),
                    if (groupBy == 'CATEGORY' && format.fields.any((field) => field.id == (groupFieldId ?? groups.firstOrNull?.id) && field.kind == BrainyFieldKind.code)) DropdownButtonFormField<int>(initialValue: groupDepth, decoration: InputDecoration(labelText: fr ? 'Niveau de regroupement' : 'Grouping level'), items: [DropdownMenuItem(value: 0, child: Text(fr ? 'Racine' : 'Root')), DropdownMenuItem(value: 1, child: Text(fr ? 'Intermédiaire' : 'Middle')), DropdownMenuItem(value: 2, child: Text(fr ? 'Code précis' : 'Exact code'))], onChanged: (value) => setState(() => groupDepth = value ?? 2)),
                  ],
                  if (groupBy == 'ZONE') ...[
                    const SizedBox(height: 8),
                    select(fr ? 'Format de données des zones' : 'Zone data format', zoneFormatId, [for (final item in zoneFormats) DropdownMenuItem(value: item.id, child: Text(item.name))], (value) => setState(() { zoneFormatId = value; zoneFieldId = collection.formats.where((item) => item.id == value).firstOrNull?.fields.where((field) => field.kind == BrainyFieldKind.zone).firstOrNull?.id; })),
                    const SizedBox(height: 8),
                    select(fr ? 'Champ zone' : 'Zone field', zoneFieldId, [for (final field in zoneFields) DropdownMenuItem(value: field.id, child: Text(field.name))], (value) => setState(() => zoneFieldId = value)),
                  ],
                  if (operation == 'CROSSTAB') ...[
                    const SizedBox(height: 8),
                    select(
                      fr ? 'Second axe (colonnes)' : 'Secondary group (columns)',
                      secondaryGroupBy,
                      options(
                        ['DAY', 'MONTH', 'CATEGORY', 'OBJECT'],
                        labels: {
                          'DAY': fr ? 'Jour' : 'Day',
                          'MONTH': fr ? 'Mois' : 'Month',
                          'CATEGORY': fr ? 'Catégorie' : 'Category',
                          'OBJECT': fr ? 'Objet' : 'Object',
                        },
                      ),
                      (value) => setState(() {
                        secondaryGroupBy = value!;
                        secondaryGroupFieldId = null;
                      }),
                    ),
                    if (secondaryGroupBy == 'CATEGORY' ||
                        secondaryGroupBy == 'OBJECT') ...[
                      const SizedBox(height: 8),
                      select(
                        fr
                            ? 'Champ du second axe'
                            : 'Secondary group field',
                        secondaryGroupFieldId,
                        [
                          for (final field in format.fields.where(
                            (item) => secondaryGroupBy == 'OBJECT'
                                ? item.kind == BrainyFieldKind.objectRef
                                : item.kind == BrainyFieldKind.select ||
                                      item.kind == BrainyFieldKind.text || item.kind == BrainyFieldKind.code,
                          ))
                            DropdownMenuItem(
                              value: field.id,
                              child: Text(field.name),
                            ),
                        ],
                        (value) => setState(() => secondaryGroupFieldId = value),
                      ),
                    ],
                  ],
                  if (operation == 'PERCENTILE') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: percentileCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            fr ? 'Centile (0–100)' : 'Percentile (0–100)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (operation == 'RATE_PER_N') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: rateBaseCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: fr ? 'Base du taux (N)' : 'Rate base (N)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    select(
                      fr ? 'Champ dénominateur' : 'Denominator field',
                      denominatorFieldId ?? '',
                      [
                        DropdownMenuItem(
                          value: '',
                          child: Text(
                            fr
                                ? 'Valeur fixe ci-dessous'
                                : 'Fixed value below',
                          ),
                        ),
                        for (final field in numeric)
                          DropdownMenuItem(
                            value: field.id,
                            child: Text(field.name),
                          ),
                      ],
                      (value) => setState(
                        () => denominatorFieldId =
                            value?.isEmpty == true ? null : value,
                      ),
                    ),
                    if (denominatorFieldId == null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: denominatorValueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              fr ? 'Dénominateur fixe' : 'Fixed denominator',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                  if (operation == 'MOVING_AVERAGE') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: windowSizeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: fr
                            ? 'Fenêtre (observations)'
                            : 'Window size (observations)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (operation == 'SUCCESSIVE_DIFF' &&
                      format.fields
                          .any((item) => item.kind == BrainyFieldKind.boolean)) ...[
                    const SizedBox(height: 8),
                    select(
                      fr
                          ? 'Champ de remise à zéro du compteur'
                          : 'Counter reset field',
                      counterResetFieldId ?? '',
                      [
                        DropdownMenuItem(
                          value: '',
                          child: Text(fr ? 'Aucun' : 'None'),
                        ),
                        for (final field in format.fields.where(
                          (item) => item.kind == BrainyFieldKind.boolean,
                        ))
                          DropdownMenuItem(
                            value: field.id,
                            child: Text(field.name),
                          ),
                      ],
                      (value) => setState(
                        () => counterResetFieldId =
                            value?.isEmpty == true ? null : value,
                      ),
                    ),
                  ],
                  if (const ['SUM', 'AVERAGE', 'RATE_PER_N', 'CROSSTAB']
                          .contains(operation) &&
                      numeric.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    select(
                      fr ? 'Pondération (optionnel)' : 'Weight field (optional)',
                      weightFieldId ?? '',
                      [
                        DropdownMenuItem(
                          value: '',
                          child: Text(fr ? 'Sans pondération' : 'Unweighted'),
                        ),
                        for (final field in numeric)
                          DropdownMenuItem(
                            value: field.id,
                            child: Text(field.name),
                          ),
                      ],
                      (value) => setState(
                        () =>
                            weightFieldId = value?.isEmpty == true ? null : value,
                      ),
                    ),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      dateFilter(
                        fr ? 'Du' : 'From',
                        from,
                        (value) => setState(() => from = value),
                      ),
                      dateFilter(
                        fr ? 'Au' : 'To',
                        to,
                        (value) => setState(() => to = value),
                      ),
                      dateFilter(
                        fr ? 'Comparaison du' : 'Compare from',
                        comparisonFrom,
                        (value) => setState(() => comparisonFrom = value),
                      ),
                      dateFilter(
                        fr ? 'Comparaison au' : 'Compare to',
                        comparisonTo,
                        (value) => setState(() => comparisonTo = value),
                      ),
                    ],
                  ),
                  if (from != null ||
                      to != null ||
                      comparisonFrom != null ||
                      comparisonTo != null)
                    TextButton(
                      onPressed: () => setState(() {
                        from = null;
                        to = null;
                        comparisonFrom = null;
                        comparisonTo = null;
                      }),
                      child: Text(fr ? 'Effacer les dates' : 'Clear dates'),
                    ),
                  const SizedBox(height: 8),
                  select(
                    fr ? 'Filtrer sur un champ' : 'Filter by field',
                    filterFieldId,
                    [
                      for (final field in format.fields.where(
                        (item) => [
                          BrainyFieldKind.title,
                          BrainyFieldKind.text,
                          BrainyFieldKind.longText,
                          BrainyFieldKind.link,
                          BrainyFieldKind.number,
                          BrainyFieldKind.date,
                          BrainyFieldKind.datetime,
                          BrainyFieldKind.boolean,
                          BrainyFieldKind.select,
                          BrainyFieldKind.multiSelect,
                        ].contains(item.kind),
                      ))
                        DropdownMenuItem(
                          value: field.id,
                          child: Text(field.name),
                        ),
                    ],
                    (value) => setState(() {
                      filterFieldId = value;
                      filterOperator = 'EQ';
                      filterValue.clear();
                    }),
                  ),
                  if (selectedFilter != null) ...[
                    const SizedBox(height: 8),
                    select(
                      fr ? 'Condition' : 'Condition',
                      filterOperator,
                      options(
                        [
                          'EQ',
                          if ([
                            BrainyFieldKind.title,
                            BrainyFieldKind.text,
                            BrainyFieldKind.longText,
                            BrainyFieldKind.link,
                          ].contains(selectedFilter.kind))
                            'CONTAINS',
                          if ([
                            BrainyFieldKind.number,
                            BrainyFieldKind.date,
                            BrainyFieldKind.datetime,
                          ].contains(selectedFilter.kind)) ...[
                            'GT',
                            'GTE',
                            'LT',
                            'LTE',
                          ],
                        ],
                        labels: {
                          'EQ': fr ? 'Égal à' : 'Equals',
                          'CONTAINS': fr ? 'Contient' : 'Contains',
                        },
                      ),
                      (value) => setState(() => filterOperator = value!),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: filterValue,
                      decoration: InputDecoration(
                        labelText: fr ? 'Valeur du filtre' : 'Filter value',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (filterFieldId != null &&
                      filterValue.text.trim().isNotEmpty &&
                      filters.length < 7)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        filters.add({
                          'fieldId': filterFieldId!,
                          'operator': filterOperator,
                          'value': filterValue.text.trim(),
                        });
                        filterFieldId = null;
                        filterValue.clear();
                      }),
                      icon: const Icon(Icons.add),
                      label: Text(fr ? 'Ajouter ce filtre' : 'Add this filter'),
                    ),
                  if (filters.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var index = 0; index < filters.length; index++)
                          InputChip(
                            label: Text(
                              '${format.fields.where((item) => item.id == filters[index]['fieldId']).firstOrNull?.name ?? ''} ${filters[index]['operator']} ${filters[index]['value']}',
                            ),
                            onDeleted: () =>
                                setState(() => filters.removeAt(index)),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy ? null : analyse,
                    child: Text(fr ? 'Calculer' : 'Calculate'),
                  ),
                  const Divider(height: 36),
                  Text(fr ? 'Prévision limitée' : 'Limited forecast', style: Theme.of(context).textTheme.titleMedium),
                  Text(fr ? 'Une tendance issue des périodes choisies, distincte des faits. Aucun conseil médical.' : 'A trend from the chosen periods, separate from facts. No medical advice.'),
                  select(fr ? 'Méthode' : 'Method', forecastMethod, options(['MEAN', 'LINEAR'], labels: {'MEAN': fr ? 'Moyenne' : 'Mean', 'LINEAR': fr ? 'Tendance linéaire' : 'Linear trend'}), (value) => setState(() => forecastMethod = value!)),
                  select(fr ? 'Période' : 'Frequency', forecastFrequency, options(['DAY', 'MONTH'], labels: {'DAY': fr ? 'Jour' : 'Day', 'MONTH': fr ? 'Mois' : 'Month'}), (value) => setState(() => forecastFrequency = value!)),
                  DropdownButtonFormField<int>(initialValue: forecastHorizon, decoration: InputDecoration(labelText: fr ? 'Horizon' : 'Horizon'), items: [1, 2, 3, 6, 12].map((value) => DropdownMenuItem(value: value, child: Text('$value'))).toList(), onChanged: (value) => setState(() => forecastHorizon = value!)),
                  FilledButton.tonal(onPressed: busy || measure == null || measure!.startsWith('formula:') || dateFieldId == null ? null : runForecast, child: Text(fr ? 'Estimer' : 'Estimate')),
                  if (forecastResult != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${fr ? 'Sources' : 'Sources'}: ${forecastResult!['sourceFrom']} → ${forecastResult!['sourceTo']}'),
                    Text('${forecastResult!['trainingCount']} ${fr ? 'périodes d’apprentissage' : 'training periods'} · ${forecastResult!['holdoutCount']} ${fr ? 'périodes vérifiées' : 'held-out periods'}'),
                    Text('${fr ? 'Erreur moyenne' : 'Mean error'}: ${forecastResult!['holdoutMae']} · ${fr ? 'Incertitude' : 'Uncertainty'}: ±${forecastResult!['uncertainty']}'),
                    const SizedBox(height: 8), Text(fr ? 'Observations tenues à l’écart' : 'Held-out observations', style: Theme.of(context).textTheme.titleSmall),
                    for (final point in (forecastResult!['validation'] as List<dynamic>).cast<Map<String, dynamic>>()) Text('${point['date']}: ${point['observed']} → ${point['estimate']}'),
                    const SizedBox(height: 8), Text(fr ? 'Prévision · distincte des faits' : 'Forecast · separate from facts', style: Theme.of(context).textTheme.titleSmall),
                    for (final point in (forecastResult!['forecast'] as List<dynamic>).cast<Map<String, dynamic>>()) Text('${point['date']}: ${point['estimate']} ${forecastResult!['unit'] ?? ''} [${point['lower']} – ${point['upper']}]'),
                  ]))),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (result != null) ...[
                    const Divider(height: 32),
                    Text(
                      key: _resultsKey,
                      '${fr ? 'Résultats' : 'Results'} · ${result!['unit'] ?? (fr ? 'sans unité' : 'no unit')} · v${result!['operationVersion'] ?? 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${fr ? 'Mis à jour' : 'Updated'} ${result!['refreshedAt']}',
                    ),
                    if (result!['explanation'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${result!['explanation']}${result!['slope'] != null ? ' · ${fr ? 'Pente' : 'Slope'}: ${result!['slope']}' : ''}${(result!['skippedMissingCount'] as int? ?? 0) > 0 ? ' · ${result!['skippedMissingCount']} ${fr ? 'valeurs manquantes ignorées' : 'missing values skipped'}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    select(
                      fr ? 'Affichage' : 'Display',
                      effectiveChart,
                      options(
                        [
                          'TABLE',
                          if (nonnegative) 'BAR',
                          if (canShowLine) 'LINE',
                          if (nonnegative && pieTotal > 0) 'PIE',
                        ],
                        labels: {
                          'TABLE': fr ? 'Tableau' : 'Table',
                          'BAR': fr ? 'Barres' : 'Bars',
                          'LINE': fr ? 'Courbe' : 'Line',
                          'PIE': fr ? 'Répartition' : 'Shares',
                        },
                      ),
                      (value) => setState(() => chart = value!),
                    ),
                    const SizedBox(height: 12),
                    if (effectiveChart == 'BAR')
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  (row['label'] ?? row['group']) as String,
                                ),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value:
                                      (double.tryParse(
                                            row['value'] as String? ?? '',
                                          )?.abs() ??
                                          0) /
                                      maximum,
                                  minHeight: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(row['value'] as String),
                            ],
                          ),
                        ),
                    if (effectiveChart == 'LINE')
                      Text(
                        '${result!['unit'] ?? result!['dimension'] ?? (fr ? 'Valeur' : 'Value')} · 0–${maximum.toStringAsFixed(maximum == maximum.roundToDouble() ? 0 : 2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (effectiveChart == 'LINE' ||
                        effectiveChart == 'PIE') ...[
                      Semantics(
                        label:
                            '${fr ? 'Graphique' : 'Chart'}: ${rows.length} ${fr ? 'groupes' : 'groups'}',
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).width < 600
                              ? 210
                              : 280,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _ChartPainter(
                              rows: rows,
                              line: effectiveChart == 'LINE',
                            ),
                          ),
                        ),
                      ),
                      if (effectiveChart == 'LINE')
                        Text(
                          rows
                              .map(
                                (row) =>
                                    (row['label'] ?? row['group']) as String,
                              )
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (effectiveChart == 'PIE')
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            for (final row in rows)
                              Text(
                                '${row['label'] ?? row['group']}: ${row['value']} ${result!['unit'] ?? ''}',
                              ),
                          ],
                        ),
                    ],
                    for (final row in rows)
                      ExpansionTile(
                        title: Text(
                          '${row['label'] ?? row['group']} · ${row['value']} ${result!['unit'] ?? ''}',
                        ),
                        subtitle: Text(
                          '${row['count']} ${fr ? 'entrées' : 'entries'}',
                        ),
                        children: [
                          for (final source
                              in (row['sources'] as List<dynamic>)
                                  .cast<Map<String, dynamic>>())
                            ListTile(
                              onTap: () async {
                                Navigator.pop(context, collection);
                                await widget.onOpenEntry(
                                  source['entryId'] as String,
                                );
                              },
                              title: Text(
                                '${source['entryId']} · ${source['value']}',
                              ),
                            ),
                          if (row['sourcesHasMore'] == true)
                            ListTile(
                              title: Text(
                                fr
                                    ? 'Afficher 100 entrées de plus'
                                    : 'Show 100 more entries',
                              ),
                              onTap: busy
                                  ? null
                                  : () => loadMore(row['group'] as String),
                            ),
                        ],
                      ),
                    if (result!['comparisonRows'] != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        fr ? 'Période comparée' : 'Comparison period',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final row
                          in (result!['comparisonRows'] as List<dynamic>)
                              .cast<Map<String, dynamic>>())
                        ExpansionTile(
                          title: Text(
                            '${row['label'] ?? row['group']} · ${row['value']} ${result!['unit'] ?? ''}',
                          ),
                          subtitle: Text(
                            '${row['count']} ${fr ? 'entrées' : 'entries'}',
                          ),
                          children: [
                            for (final source
                                in (row['sources'] as List<dynamic>)
                                    .cast<Map<String, dynamic>>())
                              ListTile(
                                onTap: () async {
                                  Navigator.pop(context, collection);
                                  await widget.onOpenEntry(
                                    source['entryId'] as String,
                                  );
                                },
                                title: Text(
                                  '${source['entryId']} · ${source['value']}',
                                ),
                              ),
                            if (row['sourcesHasMore'] == true)
                              ListTile(
                                title: Text(
                                  fr
                                      ? 'Afficher 100 entrées de plus'
                                      : 'Show 100 more entries',
                                ),
                                onTap: busy
                                    ? null
                                    : () => loadMore(
                                        row['group'] as String,
                                        comparison: true,
                                      ),
                              ),
                          ],
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.rows, required this.line});
  final List<Map<String, dynamic>> rows;
  final bool line;
  @override
  void paint(Canvas canvas, Size size) {
    final numbers = rows
        .map((item) => double.tryParse(item['value'] as String? ?? '') ?? 0)
        .toList();
    if (numbers.isEmpty) return;
    final maximum = numbers.map((value) => value.abs()).reduce(math.max);
    if (maximum <= 0) return;
    final paint = Paint()
      ..color = const Color(0xFF3478C9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    if (line) {
      final path = Path();
      for (var index = 0; index < numbers.length; index++) {
        final x =
            16 + index * (size.width - 32) / math.max(1, numbers.length - 1);
        final y =
            size.height - 16 - numbers[index] / maximum * (size.height - 32);
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()..color = const Color(0xFF3478C9),
        );
      }
      canvas.drawPath(path, paint);
    } else {
      final total = numbers
          .where((value) => value > 0)
          .fold<double>(0, (a, b) => a + b);
      if (total <= 0) return;
      var start = -math.pi / 2;
      final colors = [
        const Color(0xFF3478C9),
        const Color(0xFF5DB5A0),
        const Color(0xFFE2A653),
        const Color(0xFFAA8BCB),
        const Color(0xFFD7839E),
      ];
      for (var index = 0; index < numbers.length; index++) {
        final sweep = math.max(0, numbers[index]) / total * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width / 2, size.height / 2),
            radius: math.min(size.height, size.width) / 2 - 8,
          ),
          start,
          sweep,
          true,
          Paint()..color = colors[index % colors.length],
        );
        start += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.line != line;
}
