import 'dart:convert';

import 'collections_api.dart';

class BrainyTransfer {
  BrainyTransfer(this.data);
  final Map<String, dynamic> data;

  Map<String, dynamic> get source => data['collection'] as Map<String, dynamic>;
  List<Map<String, dynamic>> get formats =>
      (source['formats'] as List<dynamic>).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get entries =>
      (data['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get links =>
      (data['links'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get relations =>
      (data['relations'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
  List<BrainyUnit> get units => (source['units'] as List<dynamic>? ?? const [])
      .map((item) => BrainyUnit.fromJson(item as Map<String, dynamic>))
      .toList();

  static BrainyTransfer parse(String text) {
    final raw = jsonDecode(text);
    if (raw is! Map<String, dynamic> ||
        raw['brainyExportVersion'] != 1 ||
        raw['collection'] is! Map<String, dynamic> ||
        raw['entries'] is! List) {
      throw const FormatException('Invalid Brainy backup');
    }
    final result = BrainyTransfer(raw);
    if (raw['links'] != null && raw['links'] is! List) {
      throw const FormatException('Invalid entry links');
    }
    if (raw['relations'] != null && raw['relations'] is! List) {
      throw const FormatException('Invalid relations');
    }
    result.source['units'] ??= <Map<String, dynamic>>[];
    result.source['exchangeRates'] ??= <Map<String, dynamic>>[];
    result.source['codeLists'] ??= <Map<String, dynamic>>[];
    if (result.source['units'] is! List ||
        result.source['exchangeRates'] is! List ||
        result.source['codeLists'] is! List) {
      throw const FormatException('Invalid unit catalog');
    }
    if (result.source['id'] is! String ||
        result.source['name'] is! String ||
        result.formats.isEmpty) {
      throw const FormatException('Invalid collection');
    }
    final formatIds = <String>{};
    final codeIds = <String>{};
    for (final list
        in (result.source['codeLists'] as List).cast<Map<String, dynamic>>()) {
      if (list['id'] is! String ||
          list['name'] is! String ||
          list['codes'] is! List ||
          !codeIds.add(list['id'] as String)) {
        throw const FormatException('Invalid code list');
      }
    }
    for (final format in result.formats) {
      if (format['id'] is! String ||
          format['name'] is! String ||
          format['color'] is! String ||
          format['fields'] is! List ||
          (format['fields'] as List).isEmpty ||
          !formatIds.add(format['id'] as String)) {
        throw const FormatException('Invalid data format');
      }
      final fieldIds = <String>{};
      for (final field
          in (format['fields'] as List).cast<Map<String, dynamic>>()) {
        if (field['id'] is! String ||
            field['name'] is! String ||
            field['kind'] is! String ||
            !fieldIds.add(field['id'] as String)) {
          throw const FormatException('Invalid field');
        }
        if (field['kind'] == 'CODE' && !codeIds.contains(field['codeListId'])) {
          throw const FormatException('Missing code list');
        }
      }
    }
    final ids = <String>{};
    for (final entry in result.entries) {
      if (entry['id'] is! String ||
          !ids.add(entry['id'] as String) ||
          !formatIds.contains(entry['formatId']) ||
          DateTime.tryParse(entry['createdAt']?.toString() ?? '') == null ||
          DateTime.tryParse(entry['updatedAt']?.toString() ?? '') == null ||
          entry['values'] is! List ||
          (entry['values'] as List).isEmpty) {
        throw const FormatException('Invalid entry');
      }
      final format = result.formats.firstWhere(
        (item) => item['id'] == entry['formatId'],
      );
      final fieldIds = (format['fields'] as List)
          .map((item) => (item as Map)['id'])
          .toSet();
      final used = <String>{};
      for (final value
          in (entry['values'] as List).cast<Map<String, dynamic>>()) {
        if (value['fieldId'] is! String ||
            value['value'] is! String ||
            !fieldIds.contains(value['fieldId']) ||
            !used.add(value['fieldId'] as String)) {
          throw const FormatException('Invalid entry value');
        }
      }
    }
    for (final entry in result.entries) {
      final sourceId = entry['sourceObjectId'];
      if (sourceId == null) continue;
      final source = result.entries
          .where((item) => item['id'] == sourceId)
          .firstOrNull;
      if (source == null ||
          !result.formats.any(
            (format) =>
                format['id'] == source['formatId'] &&
                format['objectModel'] == true,
          )) {
        throw const FormatException('Invalid object link');
      }
    }
    for (final link in result.links) {
      if (link['fromSourceId'] is! String ||
          link['toSourceId'] is! String ||
          !ids.contains(link['fromSourceId']) ||
          !ids.contains(link['toSourceId']) ||
          link['fromSourceId'] == link['toSourceId'] ||
          link['label'] is! String ||
          (link['label'] as String).length > 120) {
        throw const FormatException('Invalid entry link');
      }
    }
    for (final relation in result.relations) {
      if (relation['fromSourceId'] is! String ||
          relation['toSourceId'] is! String ||
          !ids.contains(relation['fromSourceId']) ||
          !ids.contains(relation['toSourceId']) ||
          relation['fromSourceId'] == relation['toSourceId'] ||
          !['ASSOCIATION', 'PARENT', 'COMPONENT'].contains(relation['kind']) ||
          relation['label'] is! String ||
          (relation['kind'] == 'COMPONENT' &&
              (relation['quantity'] is! String ||
                  relation['unit'] is! String))) {
        throw const FormatException('Invalid relation');
      }
    }
    return result;
  }

  static Future<BrainyTransfer> export(
    BrainyCollection collection,
    CollectionsApi api, {bool includeSensitive = false, bool french = false}
  ) async {
    final visibleFields = <String, Set<String>>{};
    final visibleFormats = <BrainyFormat>[];
    for (final format in collection.formats) {
      final fields = format.fields
          .where((field) => includeSensitive ||
              effectiveFieldSensitivity(format, field) == 'ORDINARY')
          .toList();
      if (fields.isEmpty ||
          (format.objectModel &&
              !fields.any((field) => field.kind == BrainyFieldKind.title))) {
        continue;
      }
      visibleFormats.add(format);
      visibleFields[format.id] = fields.map((field) => field.id).toSet();
    }
    if (visibleFormats.isEmpty) {
      throw FormatException(french
          ? 'Tous les champs sont protégés. Choisissez explicitement leur inclusion pour exporter cette collection.'
          : 'All fields are protected. Choose explicitly to include them before exporting this collection.');
    }
    final hasProtected = collection.formats.any((format) => format.fields.any(
        (field) => effectiveFieldSensitivity(format, field) != 'ORDINARY'));
    final entryLinks = <Map<String, dynamic>>[];
    final seenLinks = <String>{};
    final entryRelations = <Map<String, dynamic>>[];
    final seenRelations = <String>{};
    final entries = <Map<String, dynamic>>[];
    final includedEntryIds = <String>{};
    String? cursor;
    do {
      final page = await api.entriesPage(collection.id, after: cursor);
      for (final entry in page.entries) {
        final format = collection.formatFor(entry);
        final allowed = visibleFields[format.id];
        if (allowed == null) continue;
        final values = <Map<String, dynamic>>[];
        for (final item in entry.values.entries) {
          if (!allowed.contains(item.key)) continue;
          final field = format.fields
              .where((field) => field.id == item.key)
              .firstOrNull;
          final value = <String, dynamic>{
            'fieldId': item.key,
            'value': item.value,
            if (entry.unitSnapshots[item.key] != null)
              'unitSnapshot': entry.unitSnapshots[item.key]!.toInput(),
            if (includeSensitive && entry.objectSnapshots[item.key] != null)
              'objectSnapshots': entry.objectSnapshots[item.key],
          };
          if (field?.kind == BrainyFieldKind.attachment) {
            final attachment = await api.entryAttachment(entry.id, item.key);
            value['attachmentBase64'] = base64Encode(attachment.bytes);
            value['attachmentMimeType'] = attachment.mimeType;
          }
          values.add(value);
        }
        if (values.isEmpty) continue;
        entries.add({
          'id': entry.id,
          'formatId': format.id,
          if (entry.sourceObjectId != null)
            'sourceObjectId': entry.sourceObjectId,
          'createdAt': entry.createdAt.toUtc().toIso8601String(),
          'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
          'values': values,
          if ((includeSensitive || !hasProtected) &&
              (entry.workflow?['history'] as List<dynamic>?)?.isNotEmpty ==
                  true)
            'workflowHistory': entry.workflow!['history'],
        });
        includedEntryIds.add(entry.id);
        for (final link in await api.entryLinks(collection.id, entry.id)) {
          if (!seenLinks.add(link['id'] as String)) continue;
          entryLinks.add({
            'fromSourceId': link['fromEntryId'],
            'toSourceId': link['toEntryId'],
            'label': link['label'],
          });
        }
        for (final relation in await api.relations(collection.id, entry.id)) {
          if (!seenRelations.add(relation['id'] as String)) continue;
          entryRelations.add({
            'fromSourceId': relation['fromEntryId'],
            'toSourceId': relation['toEntryId'],
            'kind': relation['kind'],
            'label': relation['label'],
            if (relation['quantity'] != null) 'quantity': relation['quantity'],
            if (relation['unit'] != null) 'unit': relation['unit'],
            if (relation['snapshotValue'] != null)
              'snapshotValue': relation['snapshotValue'],
            if (relation['snapshotUnit'] != null)
              'snapshotUnit': relation['snapshotUnit'],
            if (relation['snapshotFieldId'] != null)
              'snapshotFieldId': relation['snapshotFieldId'],
          });
        }
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return BrainyTransfer({
      'brainyExportVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'collection': {
        'id': collection.id,
        'name': collection.name,
        'units': [
          for (final unit in collection.units)
            unit.toInput()..['version'] = unit.version,
        ],
        'exchangeRates': collection.exchangeRates,
        'codeLists': collection.codeLists,
        'sharedObjects':
            includeSensitive ? collection.sharedObjects : const [],
        'formats': [
          for (final format in visibleFormats)
            {
              'id': format.id,
              'name': format.name,
              'color': format.color,
              'sensitivity': format.sensitivity,
              'objectModel': format.objectModel,
              if ((includeSensitive || !hasProtected) && format.workflow != null)
                'workflow': format.workflow,
              'fields': [
                for (final field
                    in format.fields.where((field) =>
                        visibleFields[format.id]!.contains(field.id)))
                  {
                    'id': field.id,
                    'name': field.name,
                    'kind': field.kind.wireName,
                    'sensitivity': field.sensitivity,
                    if (field.unit != null) 'unit': field.unit,
                    if (field.options.isNotEmpty) 'options': field.options,
                    if (field.codeListId != null)
                      'codeListId': field.codeListId,
                    if (field.targetObjectFormatId != null)
                      'targetObjectFormatId': field.targetObjectFormatId,
                    if (field.kind == BrainyFieldKind.objectRef) ...{
                      'multiple': field.multiple,
                      'referenceMode': field.referenceMode,
                      if (field.variableName != null)
                        'variableName': field.variableName,
                    },
                  },
              ],
            },
        ],
      },
      'entries': entries,
      'links': [
        for (final link in entryLinks)
          if (includedEntryIds.contains(link['fromSourceId']) &&
              includedEntryIds.contains(link['toSourceId']))
            link,
      ],
      'relations': [
        for (final relation in entryRelations)
          if (includedEntryIds.contains(relation['fromSourceId']) &&
              includedEntryIds.contains(relation['toSourceId']))
            if (includeSensitive || !hasProtected)
              relation
            else
              Map<String, dynamic>.from(relation)
                ..remove('snapshotValue')
                ..remove('snapshotUnit')
                ..remove('snapshotFieldId'),
      ],
    });
  }

  Map<String, ({String formatId, Map<String, String> fields})> mapping(
    BrainyCollection target,
  ) {
    final mapping = <String, ({String formatId, Map<String, String> fields})>{};
    final unitIds = unitMapping(target);
    final codeIds = <String, String>{};
    for (final sourceList
        in (source['codeLists'] as List).cast<Map<String, dynamic>>()) {
      final match = target.codeLists
          .where(
            (item) =>
                (item['name'] as String).toLowerCase() ==
                    (sourceList['name'] as String).toLowerCase() &&
                (sourceList['codes'] as List).every(
                  (code) => (item['codes'] as List).any(
                    (candidate) =>
                        (candidate as Map)['code'] == (code as Map)['code'],
                  ),
                ),
          )
          .firstOrNull;
      if (match != null) {
        codeIds[sourceList['id'] as String] = match['id'] as String;
      }
    }
    for (final sourceFormat in formats) {
      final targetFormat = target.formats
          .where(
            (item) =>
                item.name.toLowerCase() ==
                (sourceFormat['name'] as String).toLowerCase(),
          )
          .firstOrNull;
      if (targetFormat == null) {
        throw FormatException('Missing data format: ${sourceFormat['name']}');
      }
      if (sourceFormat['objectModel'] == true && !targetFormat.objectModel) {
        throw FormatException(
          'Data format must be an object model: ${sourceFormat['name']}',
        );
      }
      final fields = <String, String>{};
      for (final sourceField
          in (sourceFormat['fields'] as List).cast<Map<String, dynamic>>()) {
        final sourceUnit = sourceField['unit'] as String?;
        final expectedUnit = sourceUnit?.startsWith('local:') == true
            ? 'local:${unitIds[sourceUnit!.substring(6)] ?? 'missing'}'
            : sourceUnit;
        final targetField = targetFormat.fields
            .where(
              (item) =>
                  item.name.toLowerCase() ==
                      (sourceField['name'] as String).toLowerCase() &&
                  item.kind.wireName == sourceField['kind'] &&
                  (item.unit ?? '') == (expectedUnit ?? '') &&
                  (sourceField['kind'] != 'CODE' ||
                      item.codeListId == codeIds[sourceField['codeListId']]),
            )
            .firstOrNull;
        if (targetField == null) {
          throw FormatException(
            'Missing compatible field: ${sourceFormat['name']} → ${sourceField['name']}',
          );
        }
        fields[sourceField['id'] as String] = targetField.id;
      }
      final sourceWorkflow = sourceFormat['workflow'] as Map<String, dynamic>?;
      if (sourceWorkflow != null) {
        final targetWorkflow = targetFormat.workflow;
        if (targetWorkflow == null ||
            fields[sourceWorkflow['stateFieldId']] !=
                targetWorkflow['stateFieldId'] ||
            sourceWorkflow['initialState'] != targetWorkflow['initialState']) {
          throw FormatException(
            'Incompatible workflow: ${sourceFormat['name']}',
          );
        }
      }
      mapping[sourceFormat['id'] as String] = (
        formatId: targetFormat.id,
        fields: fields,
      );
    }
    return mapping;
  }

  Map<String, String> unitMapping(BrainyCollection target) {
    final result = <String, String>{};
    for (final sourceUnit in units) {
      final match = target.units
          .where(
            (unit) =>
                unit.name.toLowerCase() == sourceUnit.name.toLowerCase() &&
                unit.symbol == sourceUnit.symbol &&
                unit.dimension == sourceUnit.dimension,
          )
          .firstOrNull;
      if (match != null) result[sourceUnit.id] = match.id;
    }
    return result;
  }

  Future<({int valid, int created, int skipped, List<String> errors})>
  importInto(
    BrainyCollection target,
    CollectionsApi api, {
    required bool dryRun,
  }) async {
    if (formats.any(
      (format) => (format['fields'] as List).any(
        (field) => (field as Map)['kind'] == 'OBJECT_REF',
      ),
    )) {
      throw const FormatException(
        'Object reference IDs need remapping. Use Copy to collection for linked objects.',
      );
    }
    final mapped = mapping(target);
    final unitIds = unitMapping(target);
    var valid = 0, created = 0, skipped = 0;
    final errors = <String>[];
    final key = 'brainy-${source['id']}'.replaceAll(RegExp(r'[^\w.-]'), '_');
    for (final format in formats) {
      final targetFormat = mapped[format['id']]!;
      final rows = [
        for (final entry in entries.where(
          (item) => item['formatId'] == format['id'],
        ))
          {
            'sourceId': entry['id'],
            'createdAt': DateTime.parse(entry['createdAt'] as String)
                .toUtc()
                .toIso8601String(),
            'updatedAt': DateTime.parse(entry['updatedAt'] as String)
                .toUtc()
                .toIso8601String(),
            if (entry['workflowHistory'] != null)
              'workflowHistory': entry['workflowHistory'],
            'values': [
              for (final value
                  in (entry['values'] as List).cast<Map<String, dynamic>>())
                {
                  ...value,
                  'fieldId': targetFormat.fields[value['fieldId']],
                  if (value['unitSnapshot']
                      case final Map<String, dynamic> snapshot)
                    'unitSnapshot': {
                      ...snapshot,
                      'id': unitIds[snapshot['id']] ?? snapshot['id'],
                      'root': unitIds[snapshot['root']] ?? snapshot['root'],
                    },
                },
            ],
          },
      ];
      for (var start = 0; start < rows.length;) {
        final batch = <Map<String, dynamic>>[];
        var bytes = 0;
        while (start < rows.length && batch.length < 50) {
          final size = jsonEncode(rows[start]).length;
          if (batch.isNotEmpty && bytes + size > 6000000) break;
          batch.add(rows[start++]);
          bytes += size;
        }
        final result = await api.importEntriesBatch(target.id, {
          'formatId': targetFormat.formatId,
          'importKey': key.length <= 100 ? key : key.substring(0, 100),
          'dryRun': dryRun,
          'rows': batch,
        });
        valid += result.valid;
        created += result.created;
        skipped += result.skipped;
        errors.addAll(
          result.errors.map(
            (item) => '${item['sourceId']}: ${item['message']}',
          ),
        );
        if (errors.isNotEmpty && !dryRun) break;
      }
    }
    if (errors.isEmpty && !dryRun) {
      final links = [
        for (final entry in entries)
          if (entry['sourceObjectId'] != null)
            <String, dynamic>{
              'sourceId': entry['id'],
              'sourceObjectId': entry['sourceObjectId'],
            },
      ];
      for (var start = 0; start < links.length; start += 50) {
        await api.linkImportedObjects(
          target.id,
          key.length <= 100 ? key : key.substring(0, 100),
          links.skip(start).take(50).toList(),
        );
      }
      for (var start = 0; start < this.links.length; start += 50) {
        await api.linkImportedEntries(
          target.id,
          key.length <= 100 ? key : key.substring(0, 100),
          this.links.skip(start).take(50).toList(),
        );
      }
      final mappedUnits = unitMapping(target);
      for (var start = 0; start < relations.length; start += 50) {
        await api.importRelations(
          target.id,
          key.length <= 100 ? key : key.substring(0, 100),
          [
            for (final relation in relations.skip(start).take(50))
              {
                ...relation,
                if ((relation['unit'] as String?)?.startsWith('local:') == true)
                  'unit':
                      'local:${mappedUnits[(relation['unit'] as String).substring(6)] ?? 'missing'}',
                if ((relation['snapshotUnit'] as String?)?.startsWith(
                      'local:',
                    ) ==
                    true)
                  'snapshotUnit':
                      'local:${mappedUnits[(relation['snapshotUnit'] as String).substring(6)] ?? 'missing'}',
                if (relation['snapshotFieldId'] != null)
                  'snapshotFieldId':
                      mapped[entries.firstWhere(
                            (entry) => entry['id'] == relation['toSourceId'],
                          )['formatId']]
                          ?.fields[relation['snapshotFieldId']],
              },
          ],
        );
      }
    }
    return (valid: valid, created: created, skipped: skipped, errors: errors);
  }

  String get json => const JsonEncoder.withIndent('  ').convert(data);

  String bookText({required bool french}) {
    final byFormat = {
      for (final format in formats) format['id'] as String: format,
    };
    String? fieldValue(Map<String, dynamic> entry, String? fieldId) =>
        fieldId == null
        ? null
        : (entry['values'] as List)
                  .cast<Map<String, dynamic>>()
                  .where((value) => value['fieldId'] == fieldId)
                  .firstOrNull?['value']
              as String?;
    String title(Map<String, dynamic> entry) {
      final format = byFormat[entry['formatId']]!;
      final field = (format['fields'] as List)
          .cast<Map<String, dynamic>>()
          .where((item) => item['kind'] == 'TITLE')
          .firstOrNull;
      return fieldValue(entry, field?['id'] as String?) ??
          format['name'] as String;
    }

    final byId = {for (final entry in entries) entry['id'] as String: entry};
    double order(Map<String, dynamic> entry) {
      final format = byFormat[entry['formatId']]!;
      final field = (format['fields'] as List)
          .cast<Map<String, dynamic>>()
          .where(
            (item) =>
                item['kind'] == 'NUMBER' &&
                [
                  'ordre',
                  'order',
                ].contains((item['name'] as String).toLowerCase()),
          )
          .firstOrNull;
      return double.tryParse(
            fieldValue(entry, field?['id'] as String?) ?? '',
          ) ??
          double.infinity;
    }

    final sorted = [...entries]
      ..sort((a, b) {
        final first = order(a), second = order(b);
        final compare = first.compareTo(second);
        if (compare != 0) return compare;
        final date = (a['createdAt'] as String).compareTo(
          b['createdAt'] as String,
        );
        return date != 0
            ? date
            : (a['id'] as String).compareTo(b['id'] as String);
      });
    final lines = <String>[source['name'] as String, ''];
    for (final entry in sorted) {
      final format = byFormat[entry['formatId']]!;
      lines.add('${format['name']} — ${title(entry)}');
      lines.add('');
      for (final field
          in (format['fields'] as List).cast<Map<String, dynamic>>()) {
        if (!['LONG_TEXT', 'TEXT'].contains(field['kind'])) continue;
        final value = fieldValue(entry, field['id'] as String);
        if (value != null && value.isNotEmpty) {
          lines.add(value);
          lines.add('');
        }
      }
      final related = links
          .where(
            (link) =>
                link['fromSourceId'] == entry['id'] ||
                link['toSourceId'] == entry['id'],
          )
          .toList();
      if (related.isNotEmpty) {
        lines.add(french ? 'Entrées liées :' : 'Linked entries:');
        for (final link in related) {
          final targetId = link['fromSourceId'] == entry['id']
              ? link['toSourceId']
              : link['fromSourceId'];
          final target = byId[targetId];
          final label = link['label'] as String? ?? '';
          lines.add(
            '• ${label.isEmpty ? '' : '$label: '}${target == null ? targetId : title(target)}',
          );
        }
        lines.add('');
      }
    }
    return '${lines.join('\n').trim()}\n';
  }

  String csv() {
    String cell(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final lines = <String>[
      [
        "collection",
        "data_format",
        "entry_id",
        "created_at",
        "updated_at",
        "field",
        "type",
        "unit",
        "value",
      ].map(cell).join(','),
    ];
    for (final entry in entries) {
      final format = formats.firstWhere(
        (item) => item['id'] == entry['formatId'],
      );
      for (final value
          in (entry['values'] as List).cast<Map<String, dynamic>>()) {
        final field = (format['fields'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((item) => item['id'] == value['fieldId']);
        lines.add(
          [
            source['name'],
            format['name'],
            entry['id'],
            entry['createdAt'],
            entry['updatedAt'],
            field['name'],
            field['kind'],
            field['unit'] ?? '',
            field['kind'] == 'ATTACHMENT'
                ? '[${value['value']}]'
                : value['value'],
          ].map(cell).join(','),
        );
      }
    }
    for (final link in links) {
      final linkedEntry = entries
          .where((entry) => entry['id'] == link['fromSourceId'])
          .firstOrNull;
      final linkedFormat = formats
          .where((format) => format['id'] == linkedEntry?['formatId'])
          .firstOrNull;
      lines.add(
        [
          source['name'],
          linkedFormat?['name'] ?? '',
          link['fromSourceId'],
          linkedEntry?['createdAt'] ?? '',
          linkedEntry?['updatedAt'] ?? '',
          'Related entry',
          'ENTRY_LINK',
          '',
          '${link['toSourceId']}${(link['label'] as String).isNotEmpty ? ' · ${link['label']}' : ''}',
        ].map(cell).join(','),
      );
    }
    return '\uFEFF${lines.join('\r\n')}';
  }
}
