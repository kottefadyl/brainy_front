import 'dart:convert';
import 'dart:typed_data';

import 'auth_api.dart';

const brainyFormatColors = [
  '#EEF5FF',
  '#EDF9F3',
  '#FFF5EB',
  '#F4F0FF',
  '#FFF0F4',
  '#EAF8FA',
  '#FBF7E9',
  '#F1F8ED',
  '#F8F0FA',
  '#F1F5FA',
  '#FFF7F1',
  '#EFF8FF',
  '#FDEFF7',
  '#EDF7FF',
  '#F7FBEA',
  '#FFF0E8',
  '#EFEFFD',
  '#E9F8F4',
  '#FBF1E8',
  '#F0F8F9',
  '#FFF2EF',
  '#F4F8E8',
  '#F1F2FF',
  '#EFFAF0',
];

enum BrainyFieldKind {
  title,
  date,
  number,
  time,
  link,
  character,
  text,
  longText,
  boolean,
  select,
  multiSelect,
  datetime,
  duration,
  attachment,
  objectRef,
  measure,
  code,
  position,
  zone,
}

extension BrainyFieldKindLabel on BrainyFieldKind {
  String get wireName => name
      .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match[0]}')
      .toUpperCase();
  String get label => switch (this) {
    BrainyFieldKind.title => 'Title',
    BrainyFieldKind.date => 'Date',
    BrainyFieldKind.number => 'Number',
    BrainyFieldKind.time => 'Time',
    BrainyFieldKind.link => 'Link',
    BrainyFieldKind.character => 'Character',
    BrainyFieldKind.text => 'Text',
    BrainyFieldKind.longText => 'Long text',
    BrainyFieldKind.boolean => 'Checkbox (yes/no)',
    BrainyFieldKind.select => 'Single choice',
    BrainyFieldKind.multiSelect => 'Multiple choices',
    BrainyFieldKind.datetime => 'Date and time',
    BrainyFieldKind.duration => 'Duration',
    BrainyFieldKind.attachment => 'Attachment',
    BrainyFieldKind.objectRef => 'Object reference',
    BrainyFieldKind.measure => 'Measure',
    BrainyFieldKind.code => 'Code from a list',
    BrainyFieldKind.position => 'Position',
    BrainyFieldKind.zone => 'Zone',
  };
}

class BrainyField {
  const BrainyField({
    required this.id,
    required this.name,
    required this.kind,
    this.unit,
    this.options = const [],
    this.targetObjectFormatId,
    this.multiple = false,
    this.variableName,
    this.referenceMode = 'SNAPSHOT',
    this.sourceFieldId,
    this.codeListId,
    this.sensitivity,
  });
  final String id;
  final String name;
  final BrainyFieldKind kind;
  final String? unit;
  final List<String> options;
  final String? targetObjectFormatId;
  final bool multiple;
  final String? variableName;
  final String referenceMode;
  final String? sourceFieldId;
  final String? codeListId;
  final String? sensitivity;

  factory BrainyField.fromJson(Map<String, dynamic> json) => BrainyField(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: BrainyFieldKind.values.firstWhere(
      (kind) => kind.wireName == json['kind'],
    ),
    unit: json['unit'] as String?,
    options: (json['options'] as List<dynamic>?)?.cast<String>() ?? const [],
    targetObjectFormatId: json['targetObjectFormatId'] as String?,
    multiple: json['multiple'] as bool? ?? false,
    variableName: json['variableName'] as String?,
    referenceMode: json['referenceMode'] as String? ?? 'SNAPSHOT',
    sourceFieldId: json['sourceFieldId'] as String?,
    codeListId: json['codeListId'] as String?,
    sensitivity: json['sensitivity'] as String?,
  );
}

class BrainyUnit {
  const BrainyUnit({
    required this.id,
    required this.name,
    required this.symbol,
    required this.dimension,
    required this.factor,
    required this.version,
    this.baseUnitId,
    this.objectFormatId,
  });
  final String id;
  final String name;
  final String symbol;
  final String dimension;
  final String factor;
  final int version;
  final String? baseUnitId;
  final String? objectFormatId;
  factory BrainyUnit.fromJson(Map<String, dynamic> json) => BrainyUnit(
    id: json['id'] as String,
    name: json['name'] as String,
    symbol: json['symbol'] as String,
    dimension: json['dimension'] as String,
    factor: json['factor'] as String,
    version: (json['version'] as num).toInt(),
    baseUnitId: json['baseUnitId'] as String?,
    objectFormatId: json['objectFormatId'] as String?,
  );
  Map<String, dynamic> toInput() => {
    'id': id,
    'name': name,
    'symbol': symbol,
    'dimension': dimension,
    'factor': factor,
    if (baseUnitId != null) 'baseUnitId': baseUnitId,
    if (objectFormatId != null) 'objectFormatId': objectFormatId,
  };
}

class BrainyUnitSnapshot {
  const BrainyUnitSnapshot({
    required this.id,
    required this.version,
    required this.symbol,
    required this.dimension,
    required this.factor,
    required this.root,
    this.objectFormatId,
  });
  final String id;
  final int version;
  final String symbol;
  final String dimension;
  final String factor;
  final String root;
  final String? objectFormatId;
  factory BrainyUnitSnapshot.fromJson(Map<String, dynamic> json) =>
      BrainyUnitSnapshot(
        id: json['id'] as String,
        version: (json['version'] as num).toInt(),
        symbol: json['symbol'] as String,
        dimension: json['dimension'] as String,
        factor: json['factor'] as String,
        root: json['root'] as String,
        objectFormatId: json['objectFormatId'] as String?,
      );
  Map<String, dynamic> toInput() => {
    'id': id,
    'version': version,
    'symbol': symbol,
    'dimension': dimension,
    'factor': factor,
    'root': root,
    if (objectFormatId != null) 'objectFormatId': objectFormatId,
  };
}

class BrainyFormat {
  const BrainyFormat({
    required this.id,
    required this.name,
    required this.color,
    required this.fields,
    this.version = 1,
    this.objectModel = false,
    this.appendOnly = false,
    this.copiedFromFormatId,
    this.linkedSource,
    this.workflow,
    this.sensitivity = 'ORDINARY',
    this.singleEntry = false,
    this.parentFormatIds = const [],
  });
  final String id;
  final String name;
  final String color;
  final List<BrainyField> fields;
  /// T47: at most one entry may use this data format.
  final bool singleEntry;
  /// T47: allowed parent data formats for a parent relation (empty = any).
  final List<String> parentFormatIds;
  final int version;
  final bool objectModel;
  final bool appendOnly;
  final String? copiedFromFormatId;
  final Map<String, dynamic>? linkedSource;
  final Map<String, dynamic>? workflow;
  final String sensitivity;

  factory BrainyFormat.fromJson(Map<String, dynamic> json) => BrainyFormat(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
    fields: (json['fields'] as List<dynamic>)
        .map((item) => BrainyField.fromJson(item as Map<String, dynamic>))
        .toList(),
    version: (json['version'] as num?)?.toInt() ?? 1,
    objectModel: json['objectModel'] as bool? ?? false,
    appendOnly: json['appendOnly'] as bool? ?? false,
    copiedFromFormatId: json['copiedFromFormatId'] as String?,
    linkedSource: json['linkedSource'] as Map<String, dynamic>?,
    workflow: json['workflow'] as Map<String, dynamic>?,
    sensitivity: json['sensitivity'] as String? ?? 'ORDINARY',
    singleEntry: json['singleEntry'] as bool? ?? false,
    parentFormatIds: (json['parentFormatIds'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}

String defaultFieldSensitivity(BrainyField field) =>
    field.sensitivity ??
    (field.kind == BrainyFieldKind.position || field.kind == BrainyFieldKind.zone
        ? 'SENSITIVE'
        : 'ORDINARY');

String effectiveFieldSensitivity(BrainyFormat format, BrainyField field) {
  const rank = {'ORDINARY': 0, 'PERSONAL': 1, 'SENSITIVE': 2};
  final fieldLevel = defaultFieldSensitivity(field);
  return rank[format.sensitivity]! >= rank[fieldLevel]!
      ? format.sensitivity
      : fieldLevel;
}

enum BrainyCollectionRole { owner, editor, reader }

class BrainyCollectionMember {
  const BrainyCollectionMember({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.addedAt,
    this.sharedFieldIds = const [],
    this.sensitiveFieldIds = const [],
  });

  final String userId;
  final String email;
  final String name;
  final BrainyCollectionRole role;
  final DateTime addedAt;
  final List<String> sharedFieldIds;
  final List<String> sensitiveFieldIds;

  factory BrainyCollectionMember.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String? ?? 'READER').toUpperCase();
    final role = roleStr == 'OWNER'
        ? BrainyCollectionRole.owner
        : roleStr == 'EDITOR'
            ? BrainyCollectionRole.editor
            : BrainyCollectionRole.reader;
    return BrainyCollectionMember(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: role,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      sharedFieldIds: (json['sharedFieldIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      sensitiveFieldIds: (json['sensitiveFieldIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

class BrainyAuditLog {
  const BrainyAuditLog({
    required this.id,
    required this.collectionId,
    required this.userId,
    required this.action,
    this.details,
    required this.occurredAt,
  });

  final String id;
  final String collectionId;
  final String userId;
  final String action;
  final String? details;
  final DateTime occurredAt;

  factory BrainyAuditLog.fromJson(Map<String, dynamic> json) {
    return BrainyAuditLog(
      id: json['id'] as String? ?? '',
      collectionId: json['collectionId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      action: json['action'] as String? ?? '',
      details: json['details'] as String?,
      occurredAt: DateTime.tryParse(json['occurredAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Fields behind the week, month and year totals panel.
class BrainyPeriodTotals {
  const BrainyPeriodTotals({required this.formatId, required this.dateFieldId, required this.amountFieldId});
  final String formatId, dateFieldId, amountFieldId;
  factory BrainyPeriodTotals.fromJson(Map<String, dynamic> json) => BrainyPeriodTotals(formatId: json['formatId'] as String, dateFieldId: json['dateFieldId'] as String, amountFieldId: json['amountFieldId'] as String);
}

class BrainyCollection {
  const BrainyCollection({
    required this.id,
    required this.name,
    required this.fields,
    required this.formats,
    this.ownerId,
    this.codeLists = const [],
    this.units = const [],
    this.exchangeRates = const [],
    this.sharedObjects = const [],
    this.savedViews = const [],
    this.formulas = const [],
    this.stockRules = const [],
    this.allowNegativeStock = false,
    this.members = const [],
    this.sharedBy,
    this.minAggregateSize = 5,
    this.periodTotals,
    this.templateId,
    this.bookView,
    this.taskPlanner,
  });
  final String id;
  final String name;
  final List<BrainyField> fields;
  final List<BrainyFormat> formats;
  /// T47: starter template the collection came from (provenance only).
  final String? templateId;
  /// T47: book view settings, see book_model.dart.
  final Map<String, dynamic>? bookView;
  /// T49: fields driving the Day and Calendar task views (Task list template only).
  final Map<String, dynamic>? taskPlanner;
  final String? ownerId;
  final List<Map<String, dynamic>> codeLists;
  final List<BrainyUnit> units;
  final List<Map<String, dynamic>> exchangeRates;
  final List<Map<String, dynamic>> sharedObjects;
  final List<Map<String, dynamic>> savedViews;
  final List<Map<String, dynamic>> formulas;
  final List<Map<String, dynamic>> stockRules;
  final bool allowNegativeStock;
  final List<BrainyCollectionMember> members;

  /// T52: owner of a collection shared with me; null for my own collections.
  final ({String userId, String name})? sharedBy;
  final int minAggregateSize;
  final BrainyPeriodTotals? periodTotals;

  BrainyFormat formatFor(BrainyEntry entry) => formats.firstWhere(
    (format) => format.id == entry.formatId,
    orElse: () => formats.first,
  );

  factory BrainyCollection.fromJson(Map<String, dynamic> json) {
    final fields = (json['fields'] as List<dynamic>)
        .map((item) => BrainyField.fromJson(item as Map<String, dynamic>))
        .toList();
    final formats = (json['formats'] as List<dynamic>?)
        ?.map((item) => BrainyFormat.fromJson(item as Map<String, dynamic>))
        .toList();
    return BrainyCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String?,
      minAggregateSize: (json['minAggregateSize'] as num?)?.toInt() ?? 5,
      periodTotals: json['periodTotals'] == null ? null : BrainyPeriodTotals.fromJson(json['periodTotals'] as Map<String, dynamic>),
      templateId: json['templateId'] as String?,
      bookView: json['bookView'] as Map<String, dynamic>?,
      taskPlanner: json['taskPlanner'] as Map<String, dynamic>?,
      fields: fields,
      formats: formats?.isNotEmpty == true
          ? formats!
          : [
              BrainyFormat(
                id: 'legacy-${json['id']}',
                name: 'General',
                color: '#EEF5FF',
                fields: fields,
              ),
            ],
      codeLists: (json['codeLists'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ?? const [],
      units:
          (json['units'] as List<dynamic>?)
              ?.map((item) => BrainyUnit.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      exchangeRates:
          (json['exchangeRates'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const [],
      sharedObjects:
          (json['sharedObjects'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const [],
      savedViews:
          (json['savedViews'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const [],
      formulas:
          (json['formulas'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          const [],
      stockRules:
          (json['stockRules'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          const [],
      allowNegativeStock: json['allowNegativeStock'] as bool? ?? false,
      members: (json['members'] as List<dynamic>?)
              ?.map((item) => BrainyCollectionMember.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      sharedBy: json['sharedBy'] is Map<String, dynamic>
          ? (userId: (json['sharedBy'] as Map<String, dynamic>)['userId'] as String, name: (json['sharedBy'] as Map<String, dynamic>)['name'] as String)
          : null,
    );
  }
}

class BrainyEntry {
  const BrainyEntry({
    required this.id,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
    this.measures = const {},
    this.formatId,
    this.correctionOf,
    this.ledgerHash,
    this.ledgerSequence,
    this.unitSnapshots = const {},
    this.sourceObjectId,
    this.contributionLinkId,
    this.contributionReceivedAt,
    this.objectSnapshots = const {},
    this.recurrence,
    this.workflow,
    this.offlinePending = false,
    this.largeFiles = const {},
  });
  final String id;
  final Map<String, String> values;

  /// Status and details of measure fields, by field id.
  final Map<String, Map<String, String>> measures;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? formatId;
  final String? correctionOf;
  final String? ledgerHash;
  final int? ledgerSequence;
  final Map<String, BrainyUnitSnapshot> unitSnapshots;
  final String? sourceObjectId;
  final String? contributionLinkId;
  final DateTime? contributionReceivedAt;
  final Map<String, List<Map<String, dynamic>>> objectSnapshots;
  final Map<String, dynamic>? recurrence;
  final Map<String, dynamic>? workflow;
  final bool offlinePending;

  /// T44: attachment fields stored by reference, with their size in bytes.
  final Map<String, int> largeFiles;

  factory BrainyEntry.fromJson(Map<String, dynamic> json) => BrainyEntry(
    id: json['id'] as String,
    values: {
      for (final item in json['values'] as List<dynamic>)
        (item as Map<String, dynamic>)['fieldId'] as String:
            item['value'] as String,
    },
    measures: {
      for (final item in json['values'] as List<dynamic>)
        if ((item as Map<String, dynamic>)['measureValue'] is Map)
          item['fieldId'] as String: {
            for (final detail in (item['measureValue'] as Map).entries)
              if (detail.value is String && (detail.value as String).isNotEmpty)
                detail.key as String: detail.value as String,
          },
    },
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    formatId: json['formatId'] as String?,
    correctionOf: json['correctionOf'] as String?,
    ledgerHash: json['ledgerHash'] as String?,
    ledgerSequence: (json['ledgerSequence'] as num?)?.toInt(),
    sourceObjectId: json['sourceObjectId'] as String?,
    contributionLinkId: json['contributionLinkId'] as String?,
    contributionReceivedAt: DateTime.tryParse(json['contributionReceivedAt'] as String? ?? ''),
    recurrence: json['recurrence'] as Map<String, dynamic>?,
    workflow: json['workflow'] as Map<String, dynamic>?,
    unitSnapshots: {
      for (final item in json['values'] as List<dynamic>)
        if ((item as Map<String, dynamic>)['unitSnapshot']
            is Map<String, dynamic>)
          item['fieldId'] as String: BrainyUnitSnapshot.fromJson(
            item['unitSnapshot'] as Map<String, dynamic>,
          ),
    },
    objectSnapshots: {
      for (final item in json['values'] as List<dynamic>)
        if ((item as Map<String, dynamic>)['objectSnapshots'] is List<dynamic>)
          item['fieldId'] as String: (item['objectSnapshots'] as List<dynamic>)
              .cast<Map<String, dynamic>>(),
    },
    largeFiles: {
      for (final item in json['values'] as List<dynamic>)
        if ((item as Map<String, dynamic>)['largeFileId'] is String)
          item['fieldId'] as String: (item['attachmentSize'] as num?)?.toInt() ?? 0,
    },
  );
}

class BrainyEntryPage {
  const BrainyEntryPage({
    required this.entries,
    required this.hasMore,
    this.nextCursor,
  });
  final List<BrainyEntry> entries;
  final bool hasMore;
  final String? nextCursor;

  factory BrainyEntryPage.fromJson(Map<String, dynamic> json) =>
      BrainyEntryPage(
        entries: (json['entries'] as List<dynamic>)
            .map((item) => BrainyEntry.fromJson(item as Map<String, dynamic>))
            .toList(),
        hasMore: json['hasMore'] as bool,
        nextCursor: json['nextCursor'] as String?,
      );
}

class CollectionsApi {
  Future<String> workspaceBackup({bool includeSensitive = false}) async {
    final data = await auth.authenticatedRequest('query(\$includeSensitive:Boolean){workspaceBackup(includeSensitive:\$includeSensitive)}', {'includeSensitive': includeSensitive}, timeout: const Duration(minutes: 2));
    return data['workspaceBackup'] as String;
  }

  Future<Map<String, dynamic>> restoreWorkspaceBackup(String archive, {required bool dryRun}) async {
    final data = await auth.authenticatedRequest('mutation(\$archive:String!,\$dryRun:Boolean!){restoreWorkspaceBackup(archive:\$archive,dryRun:\$dryRun){version collections entries relations stockMovements conflicts allowed restored}}', {'archive': archive, 'dryRun': dryRun}, timeout: const Duration(minutes: 2));
    return data['restoreWorkspaceBackup'] as Map<String, dynamic>;
  }
  const CollectionsApi(this.auth);
  final AuthApi auth;

  Future<BrainyCollection> setFormatSensitivity(String collectionId, String formatId, String level, int expectedVersion) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$formatId:String!,\$level:SensitivityLevel!,\$expectedVersion:Int!){setFormatSensitivity(collectionId:\$collectionId,formatId:\$formatId,level:\$level,expectedVersion:\$expectedVersion){\$_collectionFields}}', {'collectionId': collectionId, 'formatId': formatId, 'level': level, 'expectedVersion': expectedVersion});
    return BrainyCollection.fromJson(data['setFormatSensitivity'] as Map<String, dynamic>);
  }

  Future<BrainyCollection> setFieldSensitivity(String collectionId, String formatId, String fieldId, String level, int expectedVersion) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$formatId:String!,\$fieldId:String!,\$level:SensitivityLevel!,\$expectedVersion:Int!){setFieldSensitivity(collectionId:\$collectionId,formatId:\$formatId,fieldId:\$fieldId,level:\$level,expectedVersion:\$expectedVersion){\$_collectionFields}}', {'collectionId': collectionId, 'formatId': formatId, 'fieldId': fieldId, 'level': level, 'expectedVersion': expectedVersion});
    return BrainyCollection.fromJson(data['setFieldSensitivity'] as Map<String, dynamic>);
  }

  Future<BrainyCollection> setMinimumAggregateSize(String collectionId, int minimum) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$minimum:Int!){setMinimumAggregateSize(collectionId:\$collectionId,minimum:\$minimum){\$_collectionFields}}', {'collectionId': collectionId, 'minimum': minimum});
    return BrainyCollection.fromJson(data['setMinimumAggregateSize'] as Map<String, dynamic>);
  }

  static const _collectionFields =
      'id ownerId name minAggregateSize templateId taskPlanner { formatId doneFieldId startFieldId endFieldId repeatFieldId intervalFieldId weekdaysFieldId completedFieldId } bookView { enabled bodyFont headingFont fontSize lineHeight paragraphSpacing firstLineIndent marginMm textAlign pageSize showRuler chapterOnNewPage roles { formatId role } } periodTotals { formatId dateFieldId amountFieldId } fields { id name kind unit options codeListId targetObjectFormatId multiple variableName referenceMode sourceFieldId sensitivity } formats { id name color version objectModel appendOnly sensitivity singleEntry parentFormatIds copiedFromFormatId linkedSource { sourceCollectionId sourceFormatId acceptedVersion targetVersion } workflow { stateFieldId initialState transitions { from to minimumRole } requirements { state fieldIds } } fields { id name kind unit options codeListId targetObjectFormatId multiple variableName referenceMode sourceFieldId sensitivity } } codeLists { id name version external codeCount levels codes { code labelEn labelFr parentCode active mergedInto } } units { id name symbol dimension baseUnitId factor objectFormatId version } exchangeRates { id from to rate effectiveAt } sharedObjects { id sourceCollectionId sourceFormatId sourceFormatVersion objectId sourceName objectName propertyFieldIds sensitiveFieldIds mode snapshot { fieldId name kind value unitSnapshot { id version symbol dimension factor root objectFormatId } } createdAt revokedAt } savedViews { id name layout formatIds columnFieldIds search filterFieldId filterOperator filterValue sort manualOrderFieldIds groupByFormat taskDoneFieldId taskDueFieldId taskCompletedFieldId taskPriorityFieldId calendarStartFieldId calendarEndFieldId calendarTimeZone } formulas { id name formatId expression version dependencies } stockRules { id name formatId kind productFieldId quantityFieldId version } allowNegativeStock members { userId email name role addedAt sharedFieldIds sensitiveFieldIds } sharedBy { userId name }';
  static const _entryFields =
      'id formatId correctionOf ledgerHash ledgerSequence sourceObjectId contributionLinkId contributionReceivedAt recurrence { startFieldId endFieldId timeZone frequency interval untilDate excludedDates } workflow { assigneeUserId dueAt reminderMinutesBefore history { kind from to actorUserId at assigneeUserId dueAt } } values { fieldId value measureValue { status uncertainty uncertaintyType quality instrument observedAt } largeFileId attachmentSize objectIds objectSnapshots { objectId capturedAt properties { fieldId name kind value unitSnapshot { id version symbol dimension factor root objectFormatId } } } unitSnapshot { id version symbol dimension factor root objectFormatId } } createdAt updatedAt';

  static String get workflowCollectionFields => _collectionFields;
  static String get workflowEntryFields => _entryFields;

  Future<BrainyCollection> saveClassification(String collectionId, String name, List<Map<String, dynamic>> codes, {String? listId, int? expectedVersion}) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$name:String!,\$codes:[ClassificationCodeInput!]!,\$listId:String,\$expectedVersion:Int){saveClassification(collectionId:\$collectionId,name:\$name,codes:\$codes,listId:\$listId,expectedVersion:\$expectedVersion){$_collectionFields}}', {'collectionId': collectionId, 'name': name, 'codes': codes.map((item) => {'code': item['code'], 'labelEn': item['labelEn'], 'labelFr': item['labelFr'], 'parentCode': item['parentCode'], 'active': item['active'], if (item['mergedInto'] != null) 'mergedInto': item['mergedInto']}).toList(), 'listId': listId, 'expectedVersion': expectedVersion});
    return BrainyCollection.fromJson(data['saveClassification'] as Map<String, dynamic>);
  }

  /// Imports a referential (T39/1); beyond 5,000 codes the list is stored apart (T39/3).
  Future<BrainyCollection> importReferential(String collectionId, String name, String format, String content, {String? listId, int? expectedVersion}) async {
    final data = await auth.authenticatedRequest('mutation(\$c:String!,\$n:String!,\$f:String!,\$t:String!,\$l:String,\$v:Int){importReferential(collectionId:\$c,name:\$n,format:\$f,content:\$t,listId:\$l,expectedVersion:\$v){$_collectionFields}}', {'c': collectionId, 'n': name, 'f': format, 't': content, 'l': listId, 'v': expectedVersion}, timeout: const Duration(minutes: 2));
    return BrainyCollection.fromJson(data['importReferential'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> previewClassificationCsv(String csv) async {
    final data = await auth.authenticatedRequest(r'query($csv:String!){previewClassificationCsv(csv:$csv){codes{code labelEn labelFr parentCode active} errors{row message}}}', {'csv': csv});
    return data['previewClassificationCsv'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> classificationCopyPreview(String collectionId, String listId, String targetCollectionId) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$listId:String!,$targetCollectionId:String!){classificationCopyPreview(collectionId:$collectionId,listId:$listId,targetCollectionId:$targetCollectionId){allowed sourceName targetName codeCount conflicts}}', {'collectionId': collectionId, 'listId': listId, 'targetCollectionId': targetCollectionId});
    return data['classificationCopyPreview'] as Map<String, dynamic>;
  }

  Future<BrainyCollection> copyClassification(String collectionId, String listId, String targetCollectionId) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$listId:String!,\$targetCollectionId:String!){copyClassification(collectionId:\$collectionId,listId:\$listId,targetCollectionId:\$targetCollectionId){$_collectionFields}}', {'collectionId': collectionId, 'listId': listId, 'targetCollectionId': targetCollectionId});
    return BrainyCollection.fromJson(data['copyClassification'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> classificationMergePreview(String collectionId, String listId, String fromCode, String toCode) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$listId:String!,$fromCode:String!,$toCode:String!){classificationMergePreview(collectionId:$collectionId,listId:$listId,fromCode:$fromCode,toCode:$toCode){affectedEntries allowed}}', {'collectionId': collectionId, 'listId': listId, 'fromCode': fromCode, 'toCode': toCode});
    return data['classificationMergePreview'] as Map<String, dynamic>;
  }

  Future<BrainyCollection> mergeClassificationCodes(String collectionId, String listId, String fromCode, String toCode, int expectedVersion) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$listId:String!,\$fromCode:String!,\$toCode:String!,\$expectedVersion:Int!){mergeClassificationCodes(collectionId:\$collectionId,listId:\$listId,fromCode:\$fromCode,toCode:\$toCode,expectedVersion:\$expectedVersion){$_collectionFields}}', {'collectionId': collectionId, 'listId': listId, 'fromCode': fromCode, 'toCode': toCode, 'expectedVersion': expectedVersion});
    return BrainyCollection.fromJson(data['mergeClassificationCodes'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> geoPage(String collectionId, String formatId, String fieldId, {String? after, String? search, String? filterFieldId, String? filterOperator, String? filterValue, String? viewId}) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$formatId:String!,$fieldId:String!,$first:Int!,$after:String,$search:String,$filters:[EntryFieldFilterInput!],$viewId:String){collectionGeoPage(collectionId:$collectionId,formatId:$formatId,fieldId:$fieldId,first:$first,after:$after,search:$search,filters:$filters,viewId:$viewId){points{entryId name latitude longitude accuracy} nextCursor hasMore}}', {'collectionId': collectionId, 'formatId': formatId, 'fieldId': fieldId, 'first': 100, 'after': after, 'search': search, if (filterFieldId != null && filterValue?.isNotEmpty == true) 'filters': [{'fieldId': filterFieldId, 'operator': filterOperator ?? 'EQ', 'value': filterValue}], 'viewId': ?viewId});
    return data['collectionGeoPage'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> geoDistance(String collectionId, String formatId, String fieldId, String firstEntryId, String secondEntryId) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$formatId:String!,$fieldId:String!,$firstEntryId:String!,$secondEntryId:String!,$unit:String!){collectionGeoDistance(collectionId:$collectionId,formatId:$formatId,fieldId:$fieldId,firstEntryId:$firstEntryId,secondEntryId:$secondEntryId,unit:$unit){value unit}}', {'collectionId': collectionId, 'formatId': formatId, 'fieldId': fieldId, 'firstEntryId': firstEntryId, 'secondEntryId': secondEntryId, 'unit': 'km'});
    return data['collectionGeoDistance'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> geoZoneSummary(String collectionId, String positionFormatId, String positionFieldId, String zoneFormatId, String zoneFieldId, {String? search, String? filterFieldId, String? filterOperator, String? filterValue, String? viewId}) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$positionFormatId:String!,$positionFieldId:String!,$zoneFormatId:String!,$zoneFieldId:String!,$search:String,$filters:[EntryFieldFilterInput!],$viewId:String){collectionGeoZoneSummary(collectionId:$collectionId,positionFormatId:$positionFormatId,positionFieldId:$positionFieldId,zoneFormatId:$zoneFormatId,zoneFieldId:$zoneFieldId,search:$search,filters:$filters,viewId:$viewId){zoneEntryId label count}}', {'collectionId': collectionId, 'positionFormatId': positionFormatId, 'positionFieldId': positionFieldId, 'zoneFormatId': zoneFormatId, 'zoneFieldId': zoneFieldId, if (search?.isNotEmpty == true) 'search': search, if (filterFieldId != null && filterValue?.isNotEmpty == true) 'filters': [{'fieldId': filterFieldId, 'operator': filterOperator ?? 'EQ', 'value': filterValue}], 'viewId': ?viewId});
    return (data['collectionGeoZoneSummary'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> previewGeoImport(String collectionId, String formatId, String fieldId, String text, String kind) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$formatId:String!,$fieldId:String!,$text:String!,$kind:String!){previewGeoImport(collectionId:$collectionId,formatId:$formatId,fieldId:$fieldId,text:$text,kind:$kind){count errors{row message}}}', {'collectionId': collectionId, 'formatId': formatId, 'fieldId': fieldId, 'text': text, 'kind': kind});
    return data['previewGeoImport'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importGeoPoints(String collectionId, String formatId, String fieldId, String text, String kind, String importKey) async {
    final data = await auth.authenticatedRequest(r'mutation($collectionId:String!,$formatId:String!,$fieldId:String!,$text:String!,$kind:String!,$importKey:String!){importGeoPoints(collectionId:$collectionId,formatId:$formatId,fieldId:$fieldId,text:$text,kind:$kind,importKey:$importKey){count errors{row message}}}', {'collectionId': collectionId, 'formatId': formatId, 'fieldId': fieldId, 'text': text, 'kind': kind, 'importKey': importKey});
    return data['importGeoPoints'] as Map<String, dynamic>;
  }

  Future<String> exportGeoPoints(String collectionId, String formatId, String fieldId, String kind, {bool includeSensitive = false}) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$formatId:String!,$fieldId:String!,$kind:String!,$includeSensitive:Boolean){exportGeoPoints(collectionId:$collectionId,formatId:$formatId,fieldId:$fieldId,kind:$kind,includeSensitive:$includeSensitive)}', {'collectionId': collectionId, 'formatId': formatId, 'fieldId': fieldId, 'kind': kind, 'includeSensitive': includeSensitive});
    return data['exportGeoPoints'] as String;
  }

  Future<List<Map<String, dynamic>>> stockPositions(String collectionId) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!) { stockPositions(collectionId:$collectionId) { productId productName location lot quantity } }', {'collectionId': collectionId});
    return (data['stockPositions'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> stockMovements(String collectionId) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!) { stockMovements(collectionId:$collectionId) { id kind productId productName baseQuantity fromLocation toLocation lot occurredAt createdAt reason sourceEntryId } }', {'collectionId': collectionId});
    return (data['stockMovements'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> stockDailyReport(String collectionId, String productId, String from, String to, String timeZone) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$productId:String!,$from:String!,$to:String!,$timeZone:String!) { stockDailyReport(collectionId:$collectionId,productId:$productId,from:$from,to:$to,timeZone:$timeZone) { date opening incoming outgoing closing movements { id kind baseQuantity } } }', {'collectionId': collectionId, 'productId': productId, 'from': from, 'to': to, 'timeZone': timeZone});
    return (data['stockDailyReport'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<BrainyCollection> setStockNegativePolicy(String collectionId, bool allowNegative) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$allowNegative:Boolean!) { setStockNegativePolicy(collectionId:\$collectionId,allowNegative:\$allowNegative) { $_collectionFields } }', {'collectionId': collectionId, 'allowNegative': allowNegative});
    return BrainyCollection.fromJson(data['setStockNegativePolicy'] as Map<String, dynamic>);
  }

  Future<BrainyCollection> saveStockRule(String collectionId, Map<String, dynamic> input) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$input:StockRuleInput!) { saveStockRule(collectionId:\$collectionId,input:\$input) { $_collectionFields } }', {'collectionId': collectionId, 'input': input});
    return BrainyCollection.fromJson(data['saveStockRule'] as Map<String, dynamic>);
  }

  Future<BrainyCollection> deleteStockRule(String collectionId, String ruleId) async {
    final data = await auth.authenticatedRequest('mutation(\$collectionId:String!,\$ruleId:String!) { deleteStockRule(collectionId:\$collectionId,ruleId:\$ruleId) { $_collectionFields } }', {'collectionId': collectionId, 'ruleId': ruleId});
    return BrainyCollection.fromJson(data['deleteStockRule'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> previewStock(String collectionId, Map<String, dynamic> input) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$input:StockMovementInput!) { previewStockMovement(collectionId:$collectionId,input:$input) { kind productName baseQuantity beforeFrom afterFrom beforeTo afterTo allowed reason existingMovementId } }', {'collectionId': collectionId, 'input': input});
    return data['previewStockMovement'] as Map<String, dynamic>;
  }

  Future<void> commitStock(String collectionId, Map<String, dynamic> input) async {
    await auth.authenticatedRequest(r'mutation($collectionId:String!,$input:StockMovementInput!) { commitStockMovement(collectionId:$collectionId,input:$input) { id } }', {'collectionId': collectionId, 'input': input});
  }

  Future<Map<String, dynamic>> previewEntryStock(String collectionId, String entryId, String ruleId) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$entryId:String!,$ruleId:String!) { previewEntryStockEffect(collectionId:$collectionId,entryId:$entryId,ruleId:$ruleId) { kind productName baseQuantity beforeFrom afterFrom beforeTo afterTo allowed reason existingMovementId } }', {'collectionId': collectionId, 'entryId': entryId, 'ruleId': ruleId});
    return data['previewEntryStockEffect'] as Map<String, dynamic>;
  }

  Future<void> commitEntryStock(String collectionId, String entryId, String ruleId, String expectedUpdatedAt) async {
    await auth.authenticatedRequest(r'mutation($collectionId:String!,$entryId:String!,$ruleId:String!,$expectedUpdatedAt:String!) { commitEntryStockEffect(collectionId:$collectionId,entryId:$entryId,ruleId:$ruleId,expectedUpdatedAt:$expectedUpdatedAt) { id } }', {'collectionId': collectionId, 'entryId': entryId, 'ruleId': ruleId, 'expectedUpdatedAt': expectedUpdatedAt});
  }

  Future<Map<String, dynamic>> forecast(String collectionId, Map<String, dynamic> input) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!,$input:ForecastInput!) { forecastCollection(collectionId:$collectionId,input:$input) { method frequency sourceFrom sourceTo trainingCount holdoutCount holdoutMae uncertainty unit dimension observations { date estimate lower upper observed } validation { date estimate lower upper observed } forecast { date estimate lower upper observed } } }', {'collectionId': collectionId, 'input': input});
    return data['forecastCollection'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> backgroundJobs(String collectionId) async {
    final data = await auth.authenticatedRequest(r'query($collectionId:String!){backgroundJobs(collectionId:$collectionId){id collectionId requestKey kind state total processed createdCount skippedCount errorCount logs{row message} failure createdAt updatedAt}}', {'collectionId': collectionId});
    return (data['backgroundJobs'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> backgroundJob(String jobId) async {
    final data = await auth.authenticatedRequest(r'query($jobId:String!){backgroundJob(jobId:$jobId){id collectionId requestKey kind state total processed createdCount skippedCount errorCount logs{row message} result failure createdAt updatedAt}}', {'jobId': jobId});
    return data['backgroundJob'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startBackgroundJob(String collectionId, String kind, Map<String, dynamic> payload, String requestKey) async {
    final data = await auth.authenticatedRequest(r'mutation($collectionId:String!,$input:StartBackgroundJobInput!){startBackgroundJob(collectionId:$collectionId,input:$input){id collectionId requestKey kind state total processed createdCount skippedCount errorCount logs{row message} failure createdAt updatedAt}}', {'collectionId': collectionId, 'input': {'kind': kind, 'requestKey': requestKey, 'payload': jsonEncode(payload)}});
    return data['startBackgroundJob'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelBackgroundJob(String jobId) async {
    final data = await auth.authenticatedRequest(r'mutation($jobId:String!){cancelBackgroundJob(jobId:$jobId){id collectionId requestKey kind state total processed createdCount skippedCount errorCount logs{row message} failure createdAt updatedAt}}', {'jobId': jobId});
    return data['cancelBackgroundJob'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resumeBackgroundJob(String jobId) async {
    final data = await auth.authenticatedRequest(r'mutation($jobId:String!){resumeBackgroundJob(jobId:$jobId){id collectionId requestKey kind state total processed createdCount skippedCount errorCount logs{row message} failure createdAt updatedAt}}', {'jobId': jobId});
    return data['resumeBackgroundJob'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> starterTemplates(String language) async {
    final data = await auth.authenticatedRequest(
      'query(\$language:String) { starterTemplates(language:\$language) { id name description } }',
      {'language': language},
    );
    return (data['starterTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<BrainyCollection> createFromTemplate(
    String templateId,
    String name,
    String language,
    String timeZone,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$templateId:String!,\$name:String!,\$language:String,\$timeZone:String) { createCollectionFromTemplate(templateId:\$templateId,name:\$name,language:\$language,timeZone:\$timeZone) { $_collectionFields } }',
      {
        'templateId': templateId,
        'name': name,
        'language': language,
        'timeZone': timeZone,
      },
    );
    return BrainyCollection.fromJson(
      data['createCollectionFromTemplate'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> saveFormula(
    String collectionId,
    String name,
    String formatId,
    String expression, {
    String? formulaId,
    int? expectedVersion,
  }) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$input:FormulaInput!,\$formulaId:String) { saveCollectionFormula(collectionId:\$collectionId,input:\$input,formulaId:\$formulaId) { $_collectionFields } }',
      {
        'collectionId': collectionId,
        'formulaId': formulaId,
        'input': {
          'name': name,
          'formatId': formatId,
          'expression': expression,
          'expectedVersion': ?expectedVersion,
        },
      },
    );
    return BrainyCollection.fromJson(
      data['saveCollectionFormula'] as Map<String, dynamic>,
    );
  }

  /// Checks a formula: its result type, unit and dimension.
  Future<Map<String, dynamic>> inferFormula(
    String collectionId,
    String formatId,
    String expression,
  ) async {
    final data = await auth.authenticatedRequest(
      'query(\$collectionId:String!,\$formatId:String!,\$expression:String!) { inferCollectionFormula(collectionId:\$collectionId,formatId:\$formatId,expression:\$expression) { type unit dimension unitOpen } }',
      {'collectionId': collectionId, 'formatId': formatId, 'expression': expression},
    );
    return data['inferCollectionFormula'] as Map<String, dynamic>;
  }

  /// Calculates a formula on a sample entry, or null when there is none.
  Future<Map<String, dynamic>?> previewFormula(
    String collectionId,
    String formatId,
    String expression,
  ) async {
    final data = await auth.authenticatedRequest(
      'query(\$collectionId:String!,\$formatId:String!,\$expression:String!) { previewCollectionFormula(collectionId:\$collectionId,formatId:\$formatId,expression:\$expression) { entryId entryLabel value unit dimension missing } }',
      {'collectionId': collectionId, 'formatId': formatId, 'expression': expression},
    );
    return data['previewCollectionFormula'] as Map<String, dynamic>?;
  }

  Future<BrainyCollection> deleteFormula(
    String collectionId,
    String formulaId,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$formulaId:String!) { deleteCollectionFormula(collectionId:\$collectionId,formulaId:\$formulaId) { $_collectionFields } }',
      {'collectionId': collectionId, 'formulaId': formulaId},
    );
    return BrainyCollection.fromJson(
      data['deleteCollectionFormula'] as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> analyse(
    String collectionId,
    Map<String, dynamic> input,
  ) async {
    final data = await auth.authenticatedRequest(
      'query(\$collectionId:String!,\$input:AnalysisInput!) { analyseCollection(collectionId:\$collectionId,input:\$input) { operation operationVersion groupBy secondaryGroupBy unit dimension skippedMissingCount slope explanation refreshedAt rows { group label rowKey columnKey value count sourcesHasMore sources { entryId value } } comparisonRows { group label rowKey columnKey value count sourcesHasMore sources { entryId value } } } }',
      {'collectionId': collectionId, 'input': input},
      // A large analysis takes up to about 33 s on one million entries (T22).
      timeout: const Duration(seconds: 60),
    );
    return data['analyseCollection'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> entryLinks(
    String collectionId,
    String entryId, {
    bool includeDeleted = false,
  }) async {
    final data = await auth.authenticatedRequest(
      'query(\$collectionId:String!,\$entryId:String!,\$includeDeleted:Boolean) { collectionEntryLinks(collectionId:\$collectionId,entryId:\$entryId,includeDeleted:\$includeDeleted) { id collectionId fromEntryId toEntryId label createdAt deletedAt } }',
      {
        'collectionId': collectionId,
        'entryId': entryId,
        'includeDeleted': includeDeleted,
      },
    );
    return (data['collectionEntryLinks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> relations(String collectionId, String entryId) async {
    final data = await auth.authenticatedRequest(
      'query(\$collectionId:String!,\$entryId:String!){collectionRelations(collectionId:\$collectionId,entryId:\$entryId){id fromEntryId toEntryId kind label quantity unit snapshotValue snapshotUnit snapshotFieldId createdAt}}',
      {'collectionId': collectionId, 'entryId': entryId},
    );
    return (data['collectionRelations'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> createRelation(String collectionId, String fromEntryId, String toEntryId, String kind, String label, {String? quantity, String? unit, String? snapshotFieldId}) async {
    await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$fromEntryId:String!,\$toEntryId:String!,\$kind:RelationKind!,\$label:String,\$quantity:String,\$unit:String,\$snapshotFieldId:String){createCollectionRelation(collectionId:\$collectionId,fromEntryId:\$fromEntryId,toEntryId:\$toEntryId,kind:\$kind,label:\$label,quantity:\$quantity,unit:\$unit,snapshotFieldId:\$snapshotFieldId){id}}',
      {'collectionId': collectionId, 'fromEntryId': fromEntryId, 'toEntryId': toEntryId, 'kind': kind, 'label': label, 'quantity': ?quantity, 'unit': ?unit, 'snapshotFieldId': ?snapshotFieldId},
    );
  }

  Future<void> removeRelation(String collectionId, String relationId) async {
    await auth.authenticatedRequest('mutation(\$collectionId:String!,\$relationId:String!){removeCollectionRelation(collectionId:\$collectionId,relationId:\$relationId)}', {'collectionId': collectionId, 'relationId': relationId});
  }

  Future<Map<String, dynamic>> relationTotal(String collectionId, String rootId, String kind, String fieldName) async {
    final data = await auth.authenticatedRequest('query(\$collectionId:String!,\$rootId:String!,\$kind:RelationKind!,\$fieldName:String!){collectionRelationTotal(collectionId:\$collectionId,rootId:\$rootId,kind:\$kind,fieldName:\$fieldName){value unit nodes}}', {'collectionId': collectionId, 'rootId': rootId, 'kind': kind, 'fieldName': fieldName});
    return data['collectionRelationTotal'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> relationImpact(String collectionId, String entryId, {String? replacementId}) async {
    final data = await auth.authenticatedRequest('query(\$collectionId:String!,\$entryId:String!,\$replacementId:String){collectionRelationImpact(collectionId:\$collectionId,entryId:\$entryId,replacementId:\$replacementId){replacementAllowed relations{id fromEntryId toEntryId kind label quantity unit}}}', {'collectionId': collectionId, 'entryId': entryId, 'replacementId': ?replacementId});
    return data['collectionRelationImpact'] as Map<String, dynamic>;
  }

  Future<void> detachRelations(String collectionId, String entryId, {String? replacementId}) async {
    await auth.authenticatedRequest('mutation(\$collectionId:String!,\$entryId:String!,\$replacementId:String){detachCollectionRelations(collectionId:\$collectionId,entryId:\$entryId,replacementId:\$replacementId)}', {'collectionId': collectionId, 'entryId': entryId, 'replacementId': ?replacementId});
  }

  Future<void> importRelations(String collectionId, String importKey, List<Map<String, dynamic>> rows) async {
    await auth.authenticatedRequest('mutation(\$collectionId:String!,\$importKey:String!,\$rows:[ImportedRelationInput!]!){importCollectionRelations(collectionId:\$collectionId,importKey:\$importKey,rows:\$rows)}', {'collectionId': collectionId, 'importKey': importKey, 'rows': rows});
  }

  Future<void> createEntryLink(
    String collectionId,
    String fromEntryId,
    String toEntryId,
    String label,
  ) async {
    await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$fromEntryId:String!,\$toEntryId:String!,\$label:String) { createCollectionEntryLink(collectionId:\$collectionId,fromEntryId:\$fromEntryId,toEntryId:\$toEntryId,label:\$label) { id } }',
      {
        'collectionId': collectionId,
        'fromEntryId': fromEntryId,
        'toEntryId': toEntryId,
        'label': label,
      },
    );
  }

  Future<void> setEntryLinkActive(
    String collectionId,
    String linkId,
    bool active,
  ) async {
    await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$linkId:String!,\$active:Boolean!) { setCollectionEntryLinkActive(collectionId:\$collectionId,linkId:\$linkId,active:\$active) { id } }',
      {'collectionId': collectionId, 'linkId': linkId, 'active': active},
    );
  }

  Future<List<BrainyEntry>> duplicateLinks(
    String collectionId,
    String formatId,
    String fieldId,
    String url, {
    String? excludeEntryId,
  }) async {
    final data = await auth.authenticatedRequest(
      'query(\$collectionId:String!,\$formatId:String!,\$fieldId:String!,\$url:String!,\$excludeEntryId:String) { collectionDuplicateLinks(collectionId:\$collectionId,formatId:\$formatId,fieldId:\$fieldId,url:\$url,excludeEntryId:\$excludeEntryId) { $_entryFields } }',
      {
        'collectionId': collectionId,
        'formatId': formatId,
        'fieldId': fieldId,
        'url': url,
        'excludeEntryId': ?excludeEntryId,
      },
    );
    return (data['collectionDuplicateLinks'] as List<dynamic>)
        .map((item) => BrainyEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> linkImportedEntries(
    String collectionId,
    String importKey,
    List<Map<String, dynamic>> links,
  ) async {
    await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$importKey:String!,\$links:[ImportedEntryLinkInput!]!) { linkImportedEntries(collectionId:\$collectionId,importKey:\$importKey,links:\$links) }',
      {'collectionId': collectionId, 'importKey': importKey, 'links': links},
    );
  }

  Future<List<BrainyCollection>> collections() async {
    final data = await auth.authenticatedRequest(
      'query { collectionsList { $_collectionFields } }',
      {},
    );
    return (data['collectionsList'] as List<dynamic>)
        .map((item) => BrainyCollection.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BrainyCollection> createCollection(
    String name,
    List<
      ({String name, BrainyFieldKind kind, String? unit, List<String>? options})
    >
    fields, {
    String formatName = 'Data format 1',
    required String color,
    bool objectModel = false,
  }) async {
    final data = await auth.authenticatedRequest(
      'mutation Create(\$input: CreateCollectionInput!) { createCollection(input: \$input) { $_collectionFields } }',
      {
        'input': {
          'name': name,
          'formats': [
            {
              'name': formatName,
              'color': color,
              'objectModel': objectModel,
              'fields': _fieldInputs(fields),
            },
          ],
        },
      },
    );
    return BrainyCollection.fromJson(
      data['createCollection'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> createCollectionWithFormats(
    String name,
    List<Map<String, dynamic>> formats, {
    List<BrainyUnit> units = const [],
    List<Map<String, dynamic>> exchangeRates = const [],
    List<Map<String, dynamic>> codeLists = const [],
  }) async {
    final data = await auth.authenticatedRequest(
      'mutation Create(\$input: CreateCollectionInput!) { createCollection(input: \$input) { $_collectionFields } }',
      {
        'input': {
          'name': name,
          'formats': formats,
          'codeLists': [for (final list in codeLists) {'id': list['id'], 'name': list['name'], 'codes': [for (final code in (list['codes'] as List).cast<Map<String, dynamic>>()) {'code': code['code'], 'labelEn': code['labelEn'], 'labelFr': code['labelFr'], if (code['parentCode'] != null) 'parentCode': code['parentCode'], 'active': code['active'] != false, if (code['mergedInto'] != null) 'mergedInto': code['mergedInto']}]}],
          'units': [for (final unit in units) unit.toInput()],
          'exchangeRates': [
            for (final rate in exchangeRates)
              {
                'from': rate['from'],
                'to': rate['to'],
                'rate': rate['rate'],
                'effectiveAt': rate['effectiveAt'],
              },
          ],
        },
      },
    );
    return BrainyCollection.fromJson(
      data['createCollection'] as Map<String, dynamic>,
    );
  }

  Future<List<BrainyUnit>> availableUnits(String collectionId) async {
    final data = await auth.authenticatedRequest(
      'query Units(\$id: String!) { collectionAvailableUnits(collectionId: \$id) { id name symbol dimension baseUnitId factor objectFormatId version } }',
      {'id': collectionId},
    );
    return (data['collectionAvailableUnits'] as List<dynamic>)
        .map((item) => BrainyUnit.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> objectTemplates(String language) async {
    final data = await auth.authenticatedRequest(
      'query Templates(\$language: String) { objectModelTemplates(language: \$language) { id name description fields { id name kind unit } } }',
      {'language': language},
    );
    return (data['objectModelTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<BrainyCollection> addObjectTemplate(
    String collectionId,
    String templateId,
    String name,
    String color,
    String language,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation Template(\$collectionId: String!, \$templateId: String!, \$name: String!, \$color: String!, \$language: String) { addObjectModelFromTemplate(collectionId: \$collectionId, templateId: \$templateId, name: \$name, color: \$color, language: \$language) { $_collectionFields } }',
      {
        'collectionId': collectionId,
        'templateId': templateId,
        'name': name,
        'color': color,
        'language': language,
      },
    );
    return BrainyCollection.fromJson(
      data['addObjectModelFromTemplate'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> setObjectModel(
    String collectionId,
    BrainyFormat format,
    bool enabled, {
    int? expectedEntryCount,
  }) async {
    final data = await auth.authenticatedRequest(
      'mutation ObjectModel(\$collectionId: String!, \$formatId: String!, \$enabled: Boolean!, \$expectedVersion: Int!, \$expectedEntryCount: Int) { setCollectionFormatObjectModel(collectionId: \$collectionId, formatId: \$formatId, enabled: \$enabled, expectedVersion: \$expectedVersion, expectedEntryCount: \$expectedEntryCount) { $_collectionFields } }',
      {
        'collectionId': collectionId,
        'formatId': format.id,
        'enabled': enabled,
        'expectedVersion': format.version,
        'expectedEntryCount': ?expectedEntryCount,
      },
    );
    return BrainyCollection.fromJson(
      data['setCollectionFormatObjectModel'] as Map<String, dynamic>,
    );
  }

  Future<BrainyEntryPage> objectsPage(
    String collectionId,
    String formatId, {
    String? after,
    String? search,
  }) async {
    final data = await auth.authenticatedRequest(
      'query Objects(\$collectionId: String!, \$formatId: String!, \$first: Int!, \$after: String, \$search: String) { collectionObjectsPage(collectionId: \$collectionId, formatId: \$formatId, first: \$first, after: \$after, search: \$search) { entries { $_entryFields } nextCursor hasMore } }',
      {
        'collectionId': collectionId,
        'formatId': formatId,
        'first': 30,
        'after': ?after,
        if (search?.isNotEmpty == true) 'search': search,
      },
    );
    return BrainyEntryPage.fromJson(
      data['collectionObjectsPage'] as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> objectDetail(String id) async {
    final data = await auth.authenticatedRequest(
      'query Object(\$id: String!) { collectionObject(id: \$id) { $_entryFields revisions { at formatVersion values { fieldId value largeFileId attachmentSize } } } }',
      {'id': id},
    );
    return data['collectionObject'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> entryObjectReferences(
    String entryId,
  ) async {
    final data = await auth.authenticatedRequest(
      'query References(\$entryId: String!) { entryObjectReferences(entryId: \$entryId) { objectId fieldId mode missing name capturedAt properties { fieldId name kind value unitSnapshot { id version symbol dimension factor root objectFormatId } } } }',
      {'entryId': entryId},
    );
    return (data['entryObjectReferences'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> objectCopyPreview(
    String objectId,
    String targetCollectionId,
  ) async {
    final data = await auth.authenticatedRequest(
      'query CopyPreview(\$objectId: String!, \$targetCollectionId: String!) { objectCopyPreview(objectId: \$objectId, targetCollectionId: \$targetCollectionId) { sourceName targetName dataFormats units formulas objects entries relations conflicts allowed stockMovementCount } }',
      {'objectId': objectId, 'targetCollectionId': targetCollectionId},
    );
    return data['objectCopyPreview'] as Map<String, dynamic>;
  }

  Future<String> copyObject(String objectId, String targetCollectionId) async {
    final data = await auth.authenticatedRequest(
      'mutation CopyObject(\$objectId: String!, \$targetCollectionId: String!) { copyCollectionObject(objectId: \$objectId, targetCollectionId: \$targetCollectionId) { objectId } }',
      {'objectId': objectId, 'targetCollectionId': targetCollectionId},
    );
    return (data['copyCollectionObject'] as Map<String, dynamic>)['objectId']
        as String;
  }

  Future<Map<String, dynamic>> objectMovePreview(
    String objectId,
    String targetCollectionId,
  ) async {
    final data = await auth.authenticatedRequest(
      'query MovePreview(\$objectId: String!, \$targetCollectionId: String!) { objectMovePreview(objectId: \$objectId, targetCollectionId: \$targetCollectionId) { sourceName targetName dataFormats units formulas objects entries relations conflicts allowed stockMovementCount inboundReferences activeShares } }',
      {'objectId': objectId, 'targetCollectionId': targetCollectionId},
    );
    return data['objectMovePreview'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> moveObject(
    String objectId,
    String targetCollectionId,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation MoveObject(\$objectId: String!, \$targetCollectionId: String!) { moveCollectionObject(objectId: \$objectId, targetCollectionId: \$targetCollectionId) { objectId operationId } }',
      {'objectId': objectId, 'targetCollectionId': targetCollectionId},
    );
    return data['moveCollectionObject'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> shareObject(
    String objectId,
    String targetCollectionId,
    List<String> propertyFieldIds,
    String mode, {
    bool includeSensitive = false,
  }) async {
    final data = await auth.authenticatedRequest(
      'mutation ShareObject(\$objectId: String!, \$targetCollectionId: String!, \$propertyFieldIds: [String!]!, \$mode: String!, \$includeSensitive: Boolean) { shareCollectionObject(objectId: \$objectId, targetCollectionId: \$targetCollectionId, propertyFieldIds: \$propertyFieldIds, mode: \$mode, includeSensitive: \$includeSensitive) { id sourceCollectionId sourceFormatId objectId sourceName objectName propertyFieldIds sensitiveFieldIds mode createdAt revokedAt } }',
      {
        'objectId': objectId,
        'targetCollectionId': targetCollectionId,
        'propertyFieldIds': propertyFieldIds,
        'mode': mode,
        'includeSensitive': includeSensitive,
      },
    );
    return data['shareCollectionObject'] as Map<String, dynamic>;
  }

  Future<void> revokeObjectShare(
    String targetCollectionId,
    String grantId,
  ) async {
    await auth.authenticatedRequest(
      'mutation RevokeObjectShare(\$targetCollectionId: String!, \$grantId: String!) { revokeCollectionObjectShare(targetCollectionId: \$targetCollectionId, grantId: \$grantId) }',
      {'targetCollectionId': targetCollectionId, 'grantId': grantId},
    );
  }

  Future<Map<String, dynamic>> dataFormatCopyPreview(
    String formatId,
    String targetCollectionId,
    bool withEntries,
  ) async {
    final data = await auth.authenticatedRequest(
      'query FormatCopyPreview(\$formatId: String!, \$targetCollectionId: String!, \$withEntries: Boolean!) { dataFormatCopyPreview(formatId: \$formatId, targetCollectionId: \$targetCollectionId, withEntries: \$withEntries) { sourceName targetName dataFormats units formulas objects entries relations conflicts allowed stockMovementCount } }',
      {
        'formatId': formatId,
        'targetCollectionId': targetCollectionId,
        'withEntries': withEntries,
      },
    );
    return data['dataFormatCopyPreview'] as Map<String, dynamic>;
  }

  Future<String> copyDataFormat(
    String formatId,
    String targetCollectionId,
    bool withEntries,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation CopyFormat(\$formatId: String!, \$targetCollectionId: String!, \$withEntries: Boolean!) { copyCollectionDataFormat(formatId: \$formatId, targetCollectionId: \$targetCollectionId, withEntries: \$withEntries) { dataFormatId } }',
      {
        'formatId': formatId,
        'targetCollectionId': targetCollectionId,
        'withEntries': withEntries,
      },
    );
    return (data['copyCollectionDataFormat']
            as Map<String, dynamic>)['dataFormatId']
        as String;
  }

  Future<String> linkDataFormat(
    String formatId,
    String targetCollectionId,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation LinkFormat(\$formatId: String!, \$targetCollectionId: String!) { linkCollectionDataFormat(formatId: \$formatId, targetCollectionId: \$targetCollectionId) { dataFormatId } }',
      {'formatId': formatId, 'targetCollectionId': targetCollectionId},
    );
    return (data['linkCollectionDataFormat']
            as Map<String, dynamic>)['dataFormatId']
        as String;
  }

  Future<Map<String, dynamic>> linkedDataFormatUpdatePreview(
    String targetCollectionId,
    String targetFormatId,
  ) async {
    final data = await auth.authenticatedRequest(
      'query LinkedPreview(\$targetCollectionId: String!, \$targetFormatId: String!) { linkedDataFormatUpdatePreview(targetCollectionId: \$targetCollectionId, targetFormatId: \$targetFormatId) { targetFormatId sourceVersion acceptedVersion addedFields changedFields removedFields conflicts allowed stockMovementCount } }',
      {
        'targetCollectionId': targetCollectionId,
        'targetFormatId': targetFormatId,
      },
    );
    return data['linkedDataFormatUpdatePreview'] as Map<String, dynamic>;
  }

  Future<BrainyCollection> acceptLinkedDataFormatVersion(
    String targetCollectionId,
    String targetFormatId,
    int expectedSourceVersion,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation AcceptLinked(\$targetCollectionId: String!, \$targetFormatId: String!, \$expectedSourceVersion: Int!) { acceptLinkedDataFormatVersion(targetCollectionId: \$targetCollectionId, targetFormatId: \$targetFormatId, expectedSourceVersion: \$expectedSourceVersion) { $_collectionFields } }',
      {
        'targetCollectionId': targetCollectionId,
        'targetFormatId': targetFormatId,
        'expectedSourceVersion': expectedSourceVersion,
      },
    );
    return BrainyCollection.fromJson(
      data['acceptLinkedDataFormatVersion'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> detachLinkedDataFormat(
    String targetCollectionId,
    String targetFormatId,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation DetachLinked(\$targetCollectionId: String!, \$targetFormatId: String!) { detachLinkedDataFormat(targetCollectionId: \$targetCollectionId, targetFormatId: \$targetFormatId) { $_collectionFields } }',
      {
        'targetCollectionId': targetCollectionId,
        'targetFormatId': targetFormatId,
      },
    );
    return BrainyCollection.fromJson(
      data['detachLinkedDataFormat'] as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> objectVariableProperty(
    String entryId,
    String variableName,
    String propertyFieldId, {
    String? objectId,
  }) async {
    final data = await auth.authenticatedRequest(
      'query Variable(\$entryId: String!, \$variableName: String!, \$propertyFieldId: String!, \$objectId: String) { objectVariableProperty(entryId: \$entryId, variableName: \$variableName, propertyFieldId: \$propertyFieldId, objectId: \$objectId) { variableName objectId mode capturedAt property { fieldId name kind value unitSnapshot { id version symbol dimension factor root objectFormatId } } } }',
      {
        'entryId': entryId,
        'variableName': variableName,
        'propertyFieldId': propertyFieldId,
        'objectId': ?objectId,
      },
    );
    return data['objectVariableProperty'] as Map<String, dynamic>;
  }

  Future<BrainyEntry> duplicateObject(String id) async {
    final data = await auth.authenticatedRequest(
      'mutation Duplicate(\$id: String!) { duplicateCollectionObject(id: \$id) { $_entryFields } }',
      {'id': id},
    );
    return BrainyEntry.fromJson(
      data['duplicateCollectionObject'] as Map<String, dynamic>,
    );
  }

  Future<BrainyEntry> useObject(
    String id,
    String formatId,
    String fieldId,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation Use(\$objectId: String!, \$targetFormatId: String!, \$targetFieldId: String!) { useCollectionObject(objectId: \$objectId, targetFormatId: \$targetFormatId, targetFieldId: \$targetFieldId) { $_entryFields } }',
      {'objectId': id, 'targetFormatId': formatId, 'targetFieldId': fieldId},
    );
    return BrainyEntry.fromJson(
      data['useCollectionObject'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> saveUnit(
    String collectionId,
    Map<String, dynamic> input, {
    String? unitId,
  }) async {
    final data = await auth.authenticatedRequest(
      'mutation SaveUnit(\$collectionId: String!, \$unitId: String, \$input: CollectionUnitInput!) { saveCollectionUnit(collectionId: \$collectionId, unitId: \$unitId, input: \$input) { $_collectionFields } }',
      {'collectionId': collectionId, 'unitId': unitId, 'input': input},
    );
    return BrainyCollection.fromJson(
      data['saveCollectionUnit'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> recordExchangeRate(
    String collectionId,
    Map<String, dynamic> input,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation Rate(\$collectionId: String!, \$input: CollectionExchangeRateInput!) { recordCollectionExchangeRate(collectionId: \$collectionId, input: \$input) { $_collectionFields } }',
      {'collectionId': collectionId, 'input': input},
    );
    return BrainyCollection.fromJson(
      data['recordCollectionExchangeRate'] as Map<String, dynamic>,
    );
  }

  Future<
    ({String value, String fromSymbol, String toSymbol, DateTime? rateDate})
  >
  convertQuantity(
    String collectionId,
    String amount,
    String from,
    String to, {
    DateTime? asOf,
  }) async {
    final data = await auth.authenticatedRequest(
      'query Convert(\$collectionId: String!, \$amount: String!, \$from: String!, \$to: String!, \$asOf: String) { collectionQuantityConversion(collectionId: \$collectionId, amount: \$amount, from: \$from, to: \$to, asOf: \$asOf) { value fromSymbol toSymbol rateDate } }',
      {
        'collectionId': collectionId,
        'amount': amount,
        'from': from,
        'to': to,
        if (asOf != null) 'asOf': asOf.toUtc().toIso8601String(),
      },
    );
    final result = data['collectionQuantityConversion'] as Map<String, dynamic>;
    return (
      value: result['value'] as String,
      fromSymbol: result['fromSymbol'] as String,
      toSymbol: result['toSymbol'] as String,
      rateDate: result['rateDate'] == null
          ? null
          : DateTime.parse(result['rateDate'] as String),
    );
  }

  Future<
    ({int valid, int created, int skipped, List<Map<String, dynamic>> errors})
  >
  importEntriesBatch(String collectionId, Map<String, dynamic> input) async {
    final data = await auth.authenticatedRequest(
      'mutation Import(\$collectionId: String!, \$input: ImportEntriesInput!) { importEntriesBatch(collectionId: \$collectionId, input: \$input) { validCount createdCount skippedCount errors { sourceId message } } }',
      {'collectionId': collectionId, 'input': input},
    );
    final result = data['importEntriesBatch'] as Map<String, dynamic>;
    return (
      valid: (result['validCount'] as num).toInt(),
      created: (result['createdCount'] as num).toInt(),
      skipped: (result['skippedCount'] as num).toInt(),
      errors: (result['errors'] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> linkImportedObjects(
    String collectionId,
    String importKey,
    List<Map<String, dynamic>> links,
  ) async {
    await auth.authenticatedRequest(
      'mutation Links(\$collectionId: String!, \$importKey: String!, \$links: [ImportObjectLinkInput!]!) { linkImportedObjects(collectionId: \$collectionId, importKey: \$importKey, links: \$links) }',
      {'collectionId': collectionId, 'importKey': importKey, 'links': links},
    );
  }

  List<Map<String, dynamic>> _fieldInputs(
    List<
      ({String name, BrainyFieldKind kind, String? unit, List<String>? options})
    >
    fields,
  ) => [
    for (final field in fields)
      {
        'name': field.name,
        'kind': field.kind.wireName,
        if ((field.kind == BrainyFieldKind.number ||
                field.kind == BrainyFieldKind.measure) &&
            field.unit != null &&
            field.unit!.isNotEmpty)
          'unit': field.unit,
        if (field.kind == BrainyFieldKind.select ||
            field.kind == BrainyFieldKind.multiSelect)
          'options': field.options,
      },
  ];

  Future<BrainyCollection> addFormat(
    String collectionId,
    String name,
    String color,
    List<
      ({String name, BrainyFieldKind kind, String? unit, List<String>? options})
    >
    fields, {
    bool objectModel = false,
  }) async {
    final data = await auth.authenticatedRequest(
      'mutation AddFormat(\$id: String!, \$input: CollectionFormatInput!) { addCollectionFormat(collectionId: \$id, input: \$input) { $_collectionFields } }',
      {
        'id': collectionId,
        'input': {
          'name': name,
          'color': color,
          'fields': _fieldInputs(fields),
          'objectModel': objectModel,
        },
      },
    );
    return BrainyCollection.fromJson(
      data['addCollectionFormat'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> addFormatWithCode(String collectionId, String name, String color, List<Map<String, dynamic>> fields, {bool objectModel = false}) async {
    final data = await auth.authenticatedRequest('mutation(\$id:String!,\$input:CollectionFormatInput!){addCollectionFormat(collectionId:\$id,input:\$input){$_collectionFields}}', {'id': collectionId, 'input': {'name': name, 'color': color, 'fields': fields, 'objectModel': objectModel}});
    return BrainyCollection.fromJson(data['addCollectionFormat'] as Map<String, dynamic>);
  }

  Future<({int entryCount, List<String> populatedFieldIds})> formatImpact(
    String collectionId,
    String formatId,
  ) async {
    final data = await auth.authenticatedRequest(
      'query Impact(\$collectionId: String!, \$formatId: String!) { collectionFormatImpact(collectionId: \$collectionId, formatId: \$formatId) { entryCount populatedFieldIds } }',
      {'collectionId': collectionId, 'formatId': formatId},
    );
    final impact = data['collectionFormatImpact'] as Map<String, dynamic>;
    return (
      entryCount: (impact['entryCount'] as num).toInt(),
      populatedFieldIds: (impact['populatedFieldIds'] as List<dynamic>)
          .cast<String>(),
    );
  }

  Future<BrainyCollection> updateFormat(
    String collectionId,
    BrainyFormat format,
    String name,
    List<Map<String, dynamic>> fields,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation UpdateFormat(\$collectionId: String!, \$formatId: String!, \$input: UpdateCollectionFormatInput!) { updateCollectionFormat(collectionId: \$collectionId, formatId: \$formatId, input: \$input) { $_collectionFields } }',
      {
        'collectionId': collectionId,
        'formatId': format.id,
        'input': {
          'name': name,
          'expectedVersion': format.version,
          'fields': fields,
        },
      },
    );
    return BrainyCollection.fromJson(
      data['updateCollectionFormat'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> setFormatColor(
    String collectionId,
    String formatId,
    String color,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation SetFormatColor(\$collectionId: String!, \$formatId: String!, \$color: String!) { setCollectionFormatColor(collectionId: \$collectionId, formatId: \$formatId, color: \$color) { $_collectionFields } }',
      {'collectionId': collectionId, 'formatId': formatId, 'color': color},
    );
    return BrainyCollection.fromJson(
      data['setCollectionFormatColor'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> renameCollection(String id, String name) async {
    final data = await auth.authenticatedRequest(
      'mutation Rename(\$id: String!, \$name: String!) { renameCollection(id: \$id, name: \$name) { $_collectionFields } }',
      {'id': id, 'name': name},
    );
    return BrainyCollection.fromJson(
      data['renameCollection'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteCollection(String id) async {
    await auth.authenticatedRequest(
      'mutation Delete(\$id: String!) { deleteCollection(id: \$id) }',
      {'id': id},
    );
  }

  Future<List<BrainyEntry>> entries(String collectionId) async {
    final data = await auth.authenticatedRequest(
      'query Entries(\$id: String!) { collectionEntries(collectionId: \$id) { $_entryFields } }',
      {'id': collectionId},
    );
    return (data['collectionEntries'] as List<dynamic>)
        .map((item) => BrainyEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BrainyEntry> entry(String collectionId, String entryId) async {
    final data = await auth.authenticatedRequest(
      'query Entry(\$collectionId: String!, \$entryId: String!) { collectionEntry(collectionId: \$collectionId, entryId: \$entryId) { $_entryFields } }',
      {'collectionId': collectionId, 'entryId': entryId},
    );
    return BrainyEntry.fromJson(
      data['collectionEntry'] as Map<String, dynamic>,
    );
  }

  Future<BrainyEntryPage> entriesPage(
    String collectionId, {
    String? after,
    String? search,
    String? formatId,
    String? fieldId,
    String? operatorName,
    String? filterValue,
    String? viewId,
    int first = 30,
  }) async {
    final data = await auth.authenticatedRequest(
      'query Page(\$id: String!, \$first: Int!, \$after: String, \$search: String, \$formatId: String, \$filters: [EntryFieldFilterInput!], \$viewId: String) { collectionEntriesPage(collectionId: \$id, first: \$first, after: \$after, search: \$search, formatId: \$formatId, filters: \$filters, viewId: \$viewId) { entries { $_entryFields } nextCursor hasMore } }',
      {
        'id': collectionId,
        'first': first,
        if (after?.isNotEmpty == true) 'after': after,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (formatId?.isNotEmpty == true) 'formatId': formatId,
        if (viewId?.isNotEmpty == true) 'viewId': viewId,
        if (fieldId != null && filterValue?.trim().isNotEmpty == true)
          'filters': [
            {
              'fieldId': fieldId,
              'operator': operatorName ?? 'EQ',
              'value': filterValue!.trim(),
            },
          ],
      },
    );
    return BrainyEntryPage.fromJson(
      data['collectionEntriesPage'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> saveView(
    String collectionId,
    Map<String, dynamic> input, {
    String? viewId,
  }) async {
    final data = await auth.authenticatedRequest(
      'mutation SaveView(\$collectionId: String!, \$viewId: String, \$input: SavedCollectionViewInput!) { saveCollectionView(collectionId: \$collectionId, viewId: \$viewId, input: \$input) { $_collectionFields } }',
      {'collectionId': collectionId, 'viewId': viewId, 'input': input},
    );
    return BrainyCollection.fromJson(
      data['saveCollectionView'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> deleteView(
    String collectionId,
    String viewId,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation DeleteView(\$collectionId: String!, \$viewId: String!) { deleteCollectionView(collectionId: \$collectionId, viewId: \$viewId) { $_collectionFields } }',
      {'collectionId': collectionId, 'viewId': viewId},
    );
    return BrainyCollection.fromJson(
      data['deleteCollectionView'] as Map<String, dynamic>,
    );
  }

  Future<BrainyEntry> setTaskCompleted(
    String collectionId,
    String viewId,
    String entryId,
    bool done,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation TaskDone(\$collectionId: String!, \$viewId: String!, \$entryId: String!, \$done: Boolean!) { setCollectionTaskCompleted(collectionId: \$collectionId, viewId: \$viewId, entryId: \$entryId, done: \$done) { $_entryFields } }',
      {
        'collectionId': collectionId,
        'viewId': viewId,
        'entryId': entryId,
        'done': done,
      },
    );
    return BrainyEntry.fromJson(
      data['setCollectionTaskCompleted'] as Map<String, dynamic>,
    );
  }

  Future<BrainyEntry> setEntryRecurrence(
    String collectionId,
    String viewId,
    String entryId,
    Map<String, dynamic>? input,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation Recurrence(\$collectionId: String!, \$viewId: String!, \$entryId: String!, \$input: EntryRecurrenceInput) { setCollectionEntryRecurrence(collectionId: \$collectionId, viewId: \$viewId, entryId: \$entryId, input: \$input) { $_entryFields } }',
      {
        'collectionId': collectionId,
        'viewId': viewId,
        'entryId': entryId,
        'input': input,
      },
    );
    return BrainyEntry.fromJson(
      data['setCollectionEntryRecurrence'] as Map<String, dynamic>,
    );
  }

  Future<List<Map<String, dynamic>>> calendarOccurrences(
    String collectionId,
    String viewId,
    DateTime from,
    DateTime to,
  ) async {
    final data = await auth.authenticatedRequest(
      'query Calendar(\$collectionId: String!, \$viewId: String!, \$from: String!, \$to: String!) { collectionCalendarOccurrences(collectionId: \$collectionId, viewId: \$viewId, from: \$from, to: \$to) { entry { $_entryFields } startAt endAt timeZone recurring localDate localStartClock localEndClock } }',
      {
        'collectionId': collectionId,
        'viewId': viewId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return (data['collectionCalendarOccurrences'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, bool>> reminderCapabilities() async {
    final data = await auth.authenticatedRequest(
      'query { reminderCapabilities { email push } }',
      {},
    );
    return (data['reminderCapabilities'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value == true),
    );
  }

  Future<List<Map<String, dynamic>>> entryReminders(String entryId) async {
    final data = await auth.authenticatedRequest(
      'query Reminders(\$entryId: String!) { entryReminders(entryId: \$entryId) { id fieldId viewId timeZone timeOfDay minutesBefore channels state nextAt occurrenceAt attempts failure } }',
      {'entryId': entryId},
    );
    return (data['entryReminders'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> saveEntryReminder(
    String entryId,
    Map<String, dynamic> input, {
    String? reminderId,
  }) async {
    await auth.authenticatedRequest(
      'mutation SaveReminder(\$entryId: String!, \$input: EntryReminderInput!, \$reminderId: String) { saveEntryReminder(entryId: \$entryId, input: \$input, reminderId: \$reminderId) { id state } }',
      {'entryId': entryId, 'input': input, 'reminderId': reminderId},
    );
  }

  Future<void> cancelEntryReminder(String reminderId) async {
    await auth.authenticatedRequest(
      'mutation CancelReminder(\$id: String!) { cancelEntryReminder(reminderId: \$id) }',
      {'id': reminderId},
    );
  }

  Future<List<Map<String, dynamic>>> pushDevices() async {
    final data = await auth.authenticatedRequest(
      'query { pushDevices { id platform label lastSeenAt } }',
      {},
    );
    return (data['pushDevices'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> registerPushDevice(
    String token,
    String platform,
    String label, {
    String targetKind = 'TOKEN',
  }) async {
    await auth.authenticatedRequest(
      'mutation RegisterDevice(\$token: String!, \$platform: String!, \$label: String!, \$targetKind: String) { registerPushDevice(token: \$token, platform: \$platform, label: \$label, targetKind: \$targetKind) { id } }',
      {
        'token': token,
        'platform': platform,
        'label': label,
        'targetKind': targetKind,
      },
    );
  }

  Future<void> unregisterPushDevice(String id) async {
    await auth.authenticatedRequest(
      'mutation UnregisterDevice(\$id: String!) { unregisterPushDevice(id: \$id) }',
      {'id': id},
    );
  }

  Future<BrainyEntry> saveEntry(
    String collectionId,
    Map<String, String> values, {
    String? entryId,
    String? formatId,
    Map<String, Uint8List> attachments = const {},
    Map<String, String> largeFiles = const {},
    Map<String, Map<String, String>> measures = const {},
    String? clientMutationId,
    DateTime? expectedUpdatedAt,
  }) async {
    final data = await auth.authenticatedRequest(
      entryId == null
          ? 'mutation CreateEntry(\$id: String!, \$input: SaveEntryInput!) { createEntry(collectionId: \$id, input: \$input) { $_entryFields } }'
          : 'mutation UpdateEntry(\$id: String!, \$input: SaveEntryInput!) { updateEntry(id: \$id, input: \$input) { $_entryFields } }',
      {
        'id': entryId ?? collectionId,
        'input': {
          'formatId': formatId,
          'clientMutationId': clientMutationId,
          'expectedUpdatedAt': expectedUpdatedAt?.toUtc().toIso8601String(),
          'values': [
            for (final item in values.entries)
              if ((item.value.trim().isNotEmpty ||
                      measures[item.key]?['status'] == 'ABSENT') &&
                  !attachments.containsKey(item.key) &&
                  !largeFiles.containsKey(item.key))
                {
                  'fieldId': item.key,
                  'value': item.value.trim(),
                  if (measures[item.key] != null)
                    'measureValue': measures[item.key],
                },
            for (final item in largeFiles.entries)
              if (values[item.key]?.trim().isNotEmpty ?? false)
                {
                  'fieldId': item.key,
                  'value': values[item.key]!.trim(),
                  'largeFileId': item.value,
                },
            for (final item in attachments.entries)
              if (values[item.key]?.trim().isNotEmpty ?? false)
                {
                  'fieldId': item.key,
                  'value': values[item.key]!.trim(),
                  'attachmentBase64': base64Encode(item.value),
                  'attachmentMimeType': 'application/octet-stream',
                },
          ],
        },
      },
    );
    return BrainyEntry.fromJson(
      data[entryId == null ? 'createEntry' : 'updateEntry']
          as Map<String, dynamic>,
    );
  }

  Future<({String fileName, Uint8List bytes, String mimeType})> entryAttachment(
    String entryId,
    String fieldId,
  ) async {
    final data = await auth.authenticatedRequest(
      'query Attachment(\$entryId: String!, \$fieldId: String!) { entryAttachment(entryId: \$entryId, fieldId: \$fieldId) { fileName base64 size mimeType } }',
      {'entryId': entryId, 'fieldId': fieldId},
    );
    final attachment = data['entryAttachment'] as Map<String, dynamic>;
    return (
      fileName: attachment['fileName'] as String,
      bytes: base64Decode(attachment['base64'] as String),
      mimeType: attachment['mimeType'] as String? ?? 'application/octet-stream',
    );
  }

  Future<BrainyCollection> addCollectionMember(
    String collectionId,
    String email,
    BrainyCollectionRole role, {
    List<String>? sharedFieldIds,
    List<String>? sensitiveFieldIds,
  }) async {
    final roleName = role == BrainyCollectionRole.owner
        ? 'OWNER'
        : role == BrainyCollectionRole.editor
            ? 'EDITOR'
            : 'READER';
    final data = await auth.authenticatedRequest(
      'mutation AddMember(\$collectionId: String!, \$email: String!, \$role: CollectionRole!, \$sharedFieldIds: [String!], \$sensitiveFieldIds: [String!]) { addCollectionMember(collectionId: \$collectionId, email: \$email, role: \$role, sharedFieldIds: \$sharedFieldIds, sensitiveFieldIds: \$sensitiveFieldIds) { $_collectionFields } }',
      {
        'collectionId': collectionId,
        'email': email,
        'role': roleName,
        'sharedFieldIds': sharedFieldIds,
        'sensitiveFieldIds': sensitiveFieldIds,
      },
    );
    return BrainyCollection.fromJson(data['addCollectionMember'] as Map<String, dynamic>);
  }

  Future<BrainyCollection> removeCollectionMember(
    String collectionId,
    String memberUserId,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation RemoveMember(\$collectionId: String!, \$memberUserId: String!) { removeCollectionMember(collectionId: \$collectionId, memberUserId: \$memberUserId) { $_collectionFields } }',
      {
        'collectionId': collectionId,
        'memberUserId': memberUserId,
      },
    );
    return BrainyCollection.fromJson(data['removeCollectionMember'] as Map<String, dynamic>);
  }

  Future<List<BrainyAuditLog>> collectionAuditLogs(String collectionId) async {
    final data = await auth.authenticatedRequest(
      'query AuditLogs(\$collectionId: String!) { collectionAuditLogs(collectionId: \$collectionId) { id collectionId userId action details occurredAt } }',
      {'collectionId': collectionId},
    );
    return ((data['collectionAuditLogs'] as List<dynamic>?) ?? const [])
        .map((item) => BrainyAuditLog.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteEntry(String id) async {
    await auth.authenticatedRequest(
      'mutation DeleteEntry(\$id: String!) { deleteEntry(id: \$id) }',
      {'id': id},
    );
  }
}
