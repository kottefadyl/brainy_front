// T32 — data sources (connectors): GraphQL calls and models.
import 'collections_api.dart';

/// Field kinds a data source can fill (same list as the API).
const dataSourceKinds = {
  'TITLE',
  'TEXT',
  'LONG_TEXT',
  'CHARACTER',
  'LINK',
  'DATE',
  'DATETIME',
  'TIME',
  'DURATION',
  'NUMBER',
  'MEASURE',
  'BOOLEAN',
  'SELECT',
  'CODE',
};

const maxDeliveryBytes = 4000000;

class DataSourceMapping {
  const DataSourceMapping({
    required this.column,
    required this.fieldId,
    this.unitColumn,
  });
  final String column;
  final String fieldId;
  final String? unitColumn;
  factory DataSourceMapping.fromJson(Map<String, dynamic> json) =>
      DataSourceMapping(
        column: json['column'] as String,
        fieldId: json['fieldId'] as String,
        unitColumn: json['unitColumn'] as String?,
      );
  Map<String, dynamic> toJson() => {
    'column': column,
    'fieldId': fieldId,
    'unitColumn': unitColumn,
  };
}

class DataSource {
  const DataSource({
    required this.id,
    required this.name,
    required this.formatId,
    required this.recordIdColumn,
    required this.decimalSeparator,
    required this.delimiter,
    required this.updatePolicy,
    required this.mappings,
    this.observedAtColumn,
    this.qualityColumn,
    this.statusColumn,
    this.keyHint,
  });
  final String id;
  final String name;
  final String formatId;
  final String recordIdColumn;
  final String? observedAtColumn;
  final String? qualityColumn;
  final String? statusColumn;
  final String decimalSeparator;
  final String delimiter;
  final String updatePolicy;
  final List<DataSourceMapping> mappings;
  final String? keyHint;

  factory DataSource.fromJson(Map<String, dynamic> json) => DataSource(
    id: json['id'] as String,
    name: json['name'] as String,
    formatId: json['formatId'] as String,
    recordIdColumn: json['recordIdColumn'] as String,
    observedAtColumn: json['observedAtColumn'] as String?,
    qualityColumn: json['qualityColumn'] as String?,
    statusColumn: json['statusColumn'] as String?,
    decimalSeparator: json['decimalSeparator'] as String,
    delimiter: json['delimiter'] as String,
    updatePolicy: json['updatePolicy'] as String,
    mappings: (json['mappings'] as List<dynamic>)
        .map((item) => DataSourceMapping.fromJson(item as Map<String, dynamic>))
        .toList(),
    keyHint: json['keyHint'] as String?,
  );
}

class DataSourceInput {
  const DataSourceInput({
    required this.name,
    required this.formatId,
    required this.recordIdColumn,
    required this.mappings,
    this.observedAtColumn,
    this.qualityColumn,
    this.statusColumn,
    this.decimalSeparator = 'DOT',
    this.delimiter = ',',
    this.updatePolicy = 'UPDATE',
  });
  final String name;
  final String formatId;
  final String recordIdColumn;
  final String? observedAtColumn;
  final String? qualityColumn;
  final String? statusColumn;
  final String decimalSeparator;
  final String delimiter;
  final String updatePolicy;
  final List<DataSourceMapping> mappings;
  Map<String, dynamic> toJson() => {
    'name': name,
    'formatId': formatId,
    'recordIdColumn': recordIdColumn,
    'observedAtColumn': observedAtColumn,
    'qualityColumn': qualityColumn,
    'statusColumn': statusColumn,
    'decimalSeparator': decimalSeparator,
    'delimiter': delimiter,
    'updatePolicy': updatePolicy,
    'mappings': [for (final item in mappings) item.toJson()],
  };
}

class DataSourceRejection {
  const DataSourceRejection({
    required this.row,
    required this.code,
    required this.message,
    this.recordId,
  });
  final int row;
  final String? recordId;
  final String code;
  final String message;
  factory DataSourceRejection.fromJson(Map<String, dynamic> json) =>
      DataSourceRejection(
        row: (json['row'] as num).toInt(),
        recordId: json['recordId'] as String?,
        code: json['code'] as String,
        message: json['message'] as String,
      );
}

class DataSourceRun {
  const DataSourceRun({
    required this.id,
    required this.origin,
    required this.state,
    required this.total,
    required this.processed,
    required this.createdCount,
    required this.updatedCount,
    required this.unchangedCount,
    required this.olderCount,
    required this.rejectedCount,
    required this.ignoredColumns,
    required this.receivedAt,
    required this.durationMs,
    this.failure,
    this.rowsPerSecond,
    this.maxLagSeconds,
    this.rejections,
  });
  final String id;
  final String origin;
  final String state;
  final int total;
  final int processed;
  final int createdCount;
  final int updatedCount;
  final int unchangedCount;
  final int olderCount;
  final int rejectedCount;
  final List<String> ignoredColumns;
  final DateTime receivedAt;
  final int durationMs;
  final String? failure;
  final double? rowsPerSecond;
  final int? maxLagSeconds;
  final List<DataSourceRejection>? rejections;

  bool get active => state == 'QUEUED' || state == 'RUNNING';

  factory DataSourceRun.fromJson(Map<String, dynamic> json) => DataSourceRun(
    id: json['id'] as String,
    origin: json['origin'] as String,
    state: json['state'] as String,
    total: (json['total'] as num).toInt(),
    processed: (json['processed'] as num).toInt(),
    createdCount: (json['createdCount'] as num).toInt(),
    updatedCount: (json['updatedCount'] as num).toInt(),
    unchangedCount: (json['unchangedCount'] as num).toInt(),
    olderCount: (json['olderCount'] as num).toInt(),
    rejectedCount: (json['rejectedCount'] as num).toInt(),
    ignoredColumns: (json['ignoredColumns'] as List<dynamic>).cast<String>(),
    receivedAt: DateTime.parse(json['receivedAt'] as String).toLocal(),
    durationMs: (json['durationMs'] as num).toInt(),
    failure: json['failure'] as String?,
    rowsPerSecond: (json['rowsPerSecond'] as num?)?.toDouble(),
    maxLagSeconds: (json['maxLagSeconds'] as num?)?.toInt(),
    rejections: (json['rejections'] as List<dynamic>?)
        ?.map(
          (item) => DataSourceRejection.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );
}

/// Same content → same delivery ID, so a file sent twice is never imported twice.
String deliveryIdFor(String content) {
  var a = 0x811c9dc5;
  var b = 0x01000193;
  for (final unit in content.codeUnits) {
    a = ((a ^ unit) * 0x01000193) & 0xffffffff;
    b = ((b ^ unit) * 0x811c9dc5 + 0x9e3779b9) & 0xffffffff;
  }
  String hex(int value) => value.toRadixString(16).padLeft(8, '0');
  return 'file-${hex(a)}${hex(b)}-${content.length}';
}

class DataSourceApi {
  const DataSourceApi(this.api);
  final CollectionsApi api;

  static const _source =
      'id name formatId recordIdColumn observedAtColumn qualityColumn statusColumn decimalSeparator delimiter updatePolicy mappings { column fieldId unitColumn } keyHint';
  static const _run =
      'id origin state total processed createdCount updatedCount unchangedCount olderCount rejectedCount ignoredColumns failure receivedAt durationMs rowsPerSecond maxLagSeconds';

  Future<Map<String, dynamic>> _call(
    String query,
    Map<String, dynamic> variables,
  ) => api.auth.authenticatedRequest(query, variables);

  Future<List<DataSource>> list(String collectionId) async {
    final data = await _call(
      'query(\$c:String!){dataSources(collectionId:\$c){$_source}}',
      {'c': collectionId},
    );
    return (data['dataSources'] as List<dynamic>)
        .map((item) => DataSource.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DataSource> save(
    String collectionId,
    DataSourceInput input, {
    String? sourceId,
  }) async {
    final data = sourceId == null
        ? await _call(
            'mutation(\$c:String!,\$i:DataSourceInput!){createDataSource(collectionId:\$c,input:\$i){$_source}}',
            {'c': collectionId, 'i': input.toJson()},
          )
        : await _call(
            'mutation(\$s:String!,\$i:DataSourceInput!){updateDataSource(sourceId:\$s,input:\$i){$_source}}',
            {'s': sourceId, 'i': input.toJson()},
          );
    return DataSource.fromJson(
      (data['createDataSource'] ?? data['updateDataSource'])
          as Map<String, dynamic>,
    );
  }

  Future<void> remove(String sourceId) => _call(
    'mutation(\$s:String!){deleteDataSource(sourceId:\$s)}',
    {'s': sourceId},
  );

  Future<String> rotateKey(String sourceId) async {
    final data = await _call(
      'mutation(\$s:String!){rotateDataSourceKey(sourceId:\$s){key}}',
      {'s': sourceId},
    );
    return (data['rotateDataSourceKey'] as Map<String, dynamic>)['key']
        as String;
  }

  Future<void> revokeKey(String sourceId) => _call(
    'mutation(\$s:String!){revokeDataSourceKey(sourceId:\$s){id}}',
    {'s': sourceId},
  );

  Future<DataSourceRun> upload(
    String sourceId,
    String content,
    String contentType,
  ) async {
    final data = await _call(
      'mutation(\$s:String!,\$d:String!,\$c:String!,\$t:String!){uploadDataSourceDelivery(sourceId:\$s,deliveryId:\$d,content:\$c,contentType:\$t){$_run}}',
      {
        's': sourceId,
        'd': deliveryIdFor(content),
        'c': content,
        't': contentType,
      },
    );
    return DataSourceRun.fromJson(
      data['uploadDataSourceDelivery'] as Map<String, dynamic>,
    );
  }

  Future<List<DataSourceRun>> runs(String sourceId) async {
    final data = await _call(
      'query(\$s:String!){dataSourceRuns(sourceId:\$s){$_run}}',
      {'s': sourceId},
    );
    return (data['dataSourceRuns'] as List<dynamic>)
        .map((item) => DataSourceRun.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DataSourceRun> run(String runId) async {
    final data = await _call(
      'query(\$r:String!){dataSourceRun(runId:\$r){$_run rejections{row recordId code message}}}',
      {'r': runId},
    );
    return DataSourceRun.fromJson(
      data['dataSourceRun'] as Map<String, dynamic>,
    );
  }

  Future<String> rejectionsCsv(String runId) async {
    final data = await _call(
      'query(\$r:String!){dataSourceRejectionsCsv(runId:\$r)}',
      {'r': runId},
    );
    return data['dataSourceRejectionsCsv'] as String;
  }

  Future<void> cancel(String runId) => _call(
    'mutation(\$r:String!){cancelDataSourceRun(runId:\$r){id}}',
    {'r': runId},
  );
  Future<void> resume(String runId) => _call(
    'mutation(\$r:String!){resumeDataSourceRun(runId:\$r){id}}',
    {'r': runId},
  );
  Future<void> retry(String runId) => _call(
    'mutation(\$r:String!){retryDataSourceRejections(runId:\$r){id}}',
    {'r': runId},
  );
}
