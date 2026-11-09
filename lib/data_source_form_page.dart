// T32 — create or edit a data source: which file columns fill which fields of one data format.
import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'collections_api.dart';
import 'data_format_colors.dart';
import 'data_source_api.dart';
import 'data_source_labels.dart';

class DataSourceFormPage extends StatefulWidget {
  const DataSourceFormPage({
    super.key,
    required this.collection,
    required this.french,
    this.source,
  });
  final BrainyCollection collection;
  final DataSource? source;
  final bool french;
  @override
  State<DataSourceFormPage> createState() => _DataSourceFormPageState();
}

class _DataSourceFormPageState extends State<DataSourceFormPage> {
  bool get fr => widget.french;
  late final List<BrainyFormat> _formats = widget.collection.formats
      .where((format) => !format.appendOnly && format.workflow == null)
      .toList();
  late String _formatId =
      widget.source?.formatId ?? (_formats.isEmpty ? '' : _formats.first.id);
  late final _name = TextEditingController(text: widget.source?.name ?? '');
  late final _recordId = TextEditingController(
    text: widget.source?.recordIdColumn ?? 'id',
  );
  late final _observedAt = TextEditingController(
    text: widget.source?.observedAtColumn ?? '',
  );
  late final _quality = TextEditingController(
    text: widget.source?.qualityColumn ?? '',
  );
  late final _status = TextEditingController(
    text: widget.source?.statusColumn ?? '',
  );
  late String _decimal =
      widget.source?.decimalSeparator ?? (fr ? 'COMMA' : 'DOT');
  late String _delimiter = widget.source?.delimiter ?? (fr ? ';' : ',');
  late String _policy = widget.source?.updatePolicy ?? 'UPDATE';
  final _columns = <String, TextEditingController>{};
  final _units = <String, TextEditingController>{};

  BrainyFormat? get _format => widget.collection.formats
      .where((item) => item.id == _formatId)
      .firstOrNull;
  List<BrainyField> get _fields =>
      _format?.fields
          .where((field) => dataSourceKinds.contains(field.kind.wireName))
          .toList() ??
      const [];

  @override
  void initState() {
    super.initState();
    _resetColumns(initial: true);
  }

  void _resetColumns({bool initial = false}) {
    for (final controller in [..._columns.values, ..._units.values]) {
      controller.dispose();
    }
    _columns.clear();
    _units.clear();
    final saved = initial
        ? {
            for (final item
                in widget.source?.mappings ?? const <DataSourceMapping>[])
              item.fieldId: item,
          }
        : const <String, DataSourceMapping>{};
    for (final field in _fields) {
      final mapping = saved[field.id];
      _columns[field.id] = TextEditingController(
        text: widget.source != null && initial
            ? mapping?.column ?? ''
            : field.name,
      );
      _units[field.id] = TextEditingController(text: mapping?.unitColumn ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _recordId,
      _observedAt,
      _quality,
      _status,
      ..._columns.values,
      ..._units.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? get _blocked {
    if (_formatId.isEmpty) {
      return dsTr(
        fr,
        'Add an ordinary data format to this collection first.',
        'Ajoutez d’abord un format de données ordinaire à cette collection.',
      );
    }
    if (_name.text.trim().isEmpty) {
      return dsTr(
        fr,
        'Name the data source to continue.',
        'Nommez la source de données pour continuer.',
      );
    }
    if (_recordId.text.trim().isEmpty) {
      return dsTr(
        fr,
        'Choose the column that identifies each record.',
        'Choisissez la colonne qui identifie chaque enregistrement.',
      );
    }
    if (!_fields.any((field) => _columns[field.id]!.text.trim().isNotEmpty)) {
      return dsTr(
        fr,
        'Give at least one field a column name.',
        'Indiquez une colonne pour au moins un champ.',
      );
    }
    final format = _format;
    if (format != null && format.objectModel) {
      final title = format.fields
          .where((field) => field.kind.wireName == 'TITLE')
          .firstOrNull;
      if (title == null || (_columns[title.id]?.text.trim().isEmpty ?? true)) {
        return dsTr(
          fr,
          'Objects need a column for their name.',
          'Les objets ont besoin d’une colonne pour leur nom.',
        );
      }
    }
    return null;
  }

  void _submit() {
    if (_blocked != null) return;
    String? optional(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    Navigator.pop(
      context,
      DataSourceInput(
        name: _name.text.trim(),
        formatId: _formatId,
        recordIdColumn: _recordId.text.trim(),
        observedAtColumn: optional(_observedAt),
        qualityColumn: optional(_quality),
        statusColumn: optional(_status),
        decimalSeparator: _decimal,
        delimiter: _delimiter,
        updatePolicy: _policy,
        mappings: [
          for (final field in _fields)
            if (_columns[field.id]!.text.trim().isNotEmpty)
              DataSourceMapping(
                column: _columns[field.id]!.text.trim(),
                fieldId: field.id,
                unitColumn: optional(_units[field.id]!),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final blocked = _blocked;
    final hasMeasure = _fields.any(
      (field) =>
          field.kind.wireName == 'MEASURE' &&
          _columns[field.id]!.text.trim().isNotEmpty,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.source == null
              ? dsTr(fr, 'New data source', 'Nouvelle source de données')
              : dsTr(fr, 'Edit data source', 'Modifier la source de données'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              maxLength: 80, buildCounter: quietFormCounter,
              decoration: InputDecoration(labelText: dsTr(fr, 'Name', 'Nom')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownMenu<String>(
              expandedInsets: EdgeInsets.zero,
              enabled: widget.source == null && _formats.isNotEmpty,
              initialSelection: _formatId.isEmpty ? null : _formatId,
              label: Text(
                dsTr(fr, 'Data format to fill', 'Format de données à remplir'),
              ),
              helperText: widget.source != null
                  ? dsTr(
                      fr,
                      'The data format of a source cannot change.',
                      'Le format de données d’une source ne change pas.',
                    )
                  : null,
              dropdownMenuEntries: [
                for (final format in _formats)
                  DropdownMenuEntry(
                    value: format.id,
                    label: format.name,
                    leadingIcon: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: DataFormatColors.marker(
                          format.color,
                          theme.brightness == Brightness.dark,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
              onSelected: (value) {
                if (value != null) {
                  setState(() {
                    _formatId = value;
                    _resetColumns();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recordId,
              maxLength: 100, buildCounter: quietFormCounter,
              decoration: InputDecoration(
                labelText: dsTr(
                  fr,
                  'Record ID column',
                  'Colonne d’identifiant',
                ),
                helperMaxLines: 3,
                helperText: dsTr(
                  fr,
                  'A stable ID from the source. Sending the same ID again updates the same entry instead of adding a copy.',
                  'Un identifiant stable fourni par la source. Renvoyer le même identifiant met à jour la même entrée au lieu d’en ajouter une copie.',
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(
              dsTr(fr, 'Columns to read', 'Colonnes à lire'),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              dsTr(
                fr,
                'Write the column name used in the file for each field. Leave it empty to ignore the field.',
                'Indiquez le nom de colonne du fichier pour chaque champ. Laissez vide pour ignorer le champ.',
              ),
              style: muted,
            ),
            const SizedBox(height: 8),
            if (_fields.isEmpty)
              Text(
                dsTr(
                  fr,
                  'This data format has no field a file can fill.',
                  'Ce format de données n’a aucun champ qu’un fichier peut remplir.',
                ),
                style: muted,
              ),
            for (final field in _fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _columns[field.id],
                      maxLength: 100, buildCounter: quietFormCounter,
                      decoration: InputDecoration(
                        labelText: field.name,
                        helperText: [
                          field.kind.wireName.toLowerCase().replaceAll(
                            '_',
                            ' ',
                          ),
                          if (field.unit != null) field.unit!,
                        ].join(' · '),
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if ((field.kind.wireName == 'NUMBER' ||
                            field.kind.wireName == 'MEASURE') &&
                        _columns[field.id]!.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 12),
                        child: TextField(
                          controller: _units[field.id],
                          maxLength: 100, buildCounter: quietFormCounter,
                          decoration: InputDecoration(
                            labelText: dsTr(
                              fr,
                              'Unit column (optional)',
                              'Colonne d’unité (facultatif)',
                            ),
                            counterText: '',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                dsTr(
                  fr,
                  'Dates, quality and file settings',
                  'Dates, qualité et réglages du fichier',
                ),
              ),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                TextField(
                  controller: _observedAt,
                  maxLength: 100, buildCounter: quietFormCounter,
                  decoration: InputDecoration(
                    labelText: dsTr(
                      fr,
                      'Fact date column',
                      'Colonne de date du fait',
                    ),
                    helperMaxLines: 3,
                    helperText: dsTr(
                      fr,
                      'When it happened, kept apart from when Brainy received it. An older version never overwrites a newer one.',
                      'Quand le fait a eu lieu, distinct de sa réception. Une version plus ancienne n’écrase jamais une plus récente.',
                    ),
                    counterText: '',
                  ),
                ),
                if (hasMeasure) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quality,
                    maxLength: 100, buildCounter: quietFormCounter,
                    decoration: InputDecoration(
                      labelText: dsTr(
                        fr,
                        'Quality column',
                        'Colonne de qualité',
                      ),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _status,
                    maxLength: 100, buildCounter: quietFormCounter,
                    decoration: InputDecoration(
                      labelText: dsTr(
                        fr,
                        'Measure status column',
                        'Colonne de statut de mesure',
                      ),
                      helperText: 'MEASURED, ESTIMATED, CALCULATED, ABSENT',
                      counterText: '',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dsTr(fr, 'Decimal separator', 'Séparateur décimal'),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'DOT',
                        label: Text(dsTr(fr, 'Point (12.5)', 'Point (12.5)')),
                      ),
                      ButtonSegment(
                        value: 'COMMA',
                        label: Text(dsTr(fr, 'Comma (12,5)', 'Virgule (12,5)')),
                      ),
                    ],
                    selected: {_decimal},
                    onSelectionChanged: (value) =>
                        setState(() => _decimal = value.first),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownMenu<String>(
                  expandedInsets: EdgeInsets.zero,
                  initialSelection: _delimiter,
                  label: Text(
                    dsTr(
                      fr,
                      'CSV column separator',
                      'Séparateur de colonnes CSV',
                    ),
                  ),
                  dropdownMenuEntries: [
                    DropdownMenuEntry(
                      value: ',',
                      label: dsTr(fr, 'Comma', 'Virgule'),
                    ),
                    DropdownMenuEntry(
                      value: ';',
                      label: dsTr(fr, 'Semicolon', 'Point-virgule'),
                    ),
                    DropdownMenuEntry(
                      value: '\t',
                      label: dsTr(fr, 'Tab', 'Tabulation'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value != null) setState(() => _delimiter = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownMenu<String>(
                  expandedInsets: EdgeInsets.zero,
                  initialSelection: _policy,
                  label: Text(
                    dsTr(
                      fr,
                      'When a record comes back',
                      'Quand un enregistrement revient',
                    ),
                  ),
                  dropdownMenuEntries: [
                    DropdownMenuEntry(
                      value: 'UPDATE',
                      label: dsTr(
                        fr,
                        'Update the entry and keep its history',
                        'Mettre à jour l’entrée et garder l’historique',
                      ),
                    ),
                    DropdownMenuEntry(
                      value: 'KEEP_FIRST',
                      label: dsTr(
                        fr,
                        'Keep the first version',
                        'Garder la première version',
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value != null) setState(() => _policy = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (blocked != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(blocked, style: muted),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: blocked == null ? _submit : null,
                  child: Text(
                    widget.source == null
                        ? dsTr(fr, 'Create data source', 'Créer la source')
                        : dsTr(fr, 'Save changes', 'Enregistrer'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(dsTr(fr, 'Cancel', 'Annuler')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
