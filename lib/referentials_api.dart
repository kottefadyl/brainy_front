import 'collections_api.dart';

/// Referential previews (T39/1) and server-side code search for large lists (T39/3).

/// Below Vercel's 4.5 MB request limit, with room for the rest of the request.
const maxReferentialBytes = 4200000;

/// JSON when the name or the first character says so, CSV otherwise.
String referentialFormatOf(String fileName, String content) =>
    RegExp(r'\.json$', caseSensitive: false).hasMatch(fileName) || RegExp(r'^\s*[\[{]').hasMatch(content) ? 'JSON' : 'CSV';

/// A list stored apart: its codes are not sent with the collection.
bool isLargeCodeList(Map<String, dynamic>? list) => list?['external'] == true;

class FoundCode {
  const FoundCode({required this.code, required this.label, this.path = const [], this.level = 1, this.active = true, this.hasChildren = false});

  factory FoundCode.fromJson(Map<String, dynamic> json) => FoundCode(
    code: json['code'] as String,
    label: json['label'] as String? ?? json['code'] as String,
    path: (json['path'] as List<dynamic>? ?? const []).cast<String>(),
    level: json['level'] as int? ?? 1,
    active: json['active'] as bool? ?? true,
    hasChildren: json['hasChildren'] as bool? ?? false,
  );

  final String code;
  final String label;
  final List<String> path;
  final int level;
  final bool active;
  final bool hasChildren;
}

class ReferentialPreview {
  const ReferentialPreview({required this.codeCount, required this.levels, required this.large, required this.errors, required this.sample});

  factory ReferentialPreview.fromJson(Map<String, dynamic> json) => ReferentialPreview(
    codeCount: json['codeCount'] as int,
    levels: json['levels'] as int,
    large: json['large'] as bool,
    errors: [for (final item in (json['errors'] as List<dynamic>).cast<Map<String, dynamic>>()) (row: item['row'] as int, message: item['message'] as String)],
    sample: (json['sample'] as List<dynamic>).cast<Map<String, dynamic>>(),
  );

  final int codeCount;
  final int levels;
  final bool large;
  final List<({int row, String message})> errors;
  final List<Map<String, dynamic>> sample;
}

/// What a code picker needs from a large list; tests pass their own.
class RemoteCodeSource {
  const RemoteCodeSource({required this.search, required this.byValue});

  /// At most 50 codes: matches of [query], or the children of [parentCode] (roots when null).
  final Future<List<FoundCode>> Function(String query, String? parentCode) search;

  /// The saved codes, with their labels.
  final Future<List<Map<String, dynamic>>> Function(List<String> codes) byValue;
}

extension ReferentialsApi on CollectionsApi {
  Future<ReferentialPreview> previewReferential(String format, String content) async {
    final data = await auth.authenticatedRequest(
      r'query($f:String!,$c:String!){previewReferential(format:$f,content:$c){codeCount levels large errors{row message} sample{code labelEn labelFr parentCode active}}}',
      {'f': format, 'c': content},
      timeout: const Duration(minutes: 1),
    );
    return ReferentialPreview.fromJson(data['previewReferential'] as Map<String, dynamic>);
  }

  RemoteCodeSource remoteCodes(String collectionId, String listId, {required bool french}) => RemoteCodeSource(
    search: (query, parentCode) async {
      final data = await auth.authenticatedRequest(
        r'query($c:String!,$l:String!,$q:String,$p:String,$lang:String){searchClassificationCodes(collectionId:$c,listId:$l,query:$q,parentCode:$p,language:$lang,limit:50){code label path level active hasChildren}}',
        {'c': collectionId, 'l': listId, 'q': query.isEmpty ? null : query, 'p': parentCode, 'lang': french ? 'fr' : 'en'},
      );
      return [for (final item in (data['searchClassificationCodes'] as List<dynamic>).cast<Map<String, dynamic>>()) FoundCode.fromJson(item)];
    },
    byValue: (codes) async {
      if (codes.isEmpty) return const [];
      final data = await auth.authenticatedRequest(
        r'query($c:String!,$l:String!,$codes:[String!]!){classificationCodesByValue(collectionId:$c,listId:$l,codes:$codes){code labelEn labelFr parentCode active}}',
        {'c': collectionId, 'l': listId, 'codes': codes},
      );
      return (data['classificationCodesByValue'] as List<dynamic>).cast<Map<String, dynamic>>();
    },
  );
}
