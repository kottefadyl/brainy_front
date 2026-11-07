import 'dart:convert';

import 'package:http/http.dart' as http;

import 'collections_api.dart';

/// T45 — domain packages: pilots, preview, local-copy install/update, detach and structure export.
class DomainPackageSummary {
  const DomainPackageSummary({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.packageJson,
  });
  factory DomainPackageSummary.fromJson(Map<String, dynamic> json) =>
      DomainPackageSummary(
        id: json['id'] as String,
        version: json['version'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        packageJson: json['packageJson'] as String,
      );
  final String id, version, name, description, packageJson;
}

class DomainPackagePreview {
  DomainPackagePreview.fromJson(Map<String, dynamic> json)
    : packageId = json['packageId'] as String,
      version = json['version'] as String,
      name = json['name'] as String,
      description = json['description'] as String,
      notice = json['notice'] as String,
      author = json['author'] as String,
      license = json['license'] as String,
      publishedAt = json['publishedAt'] as String,
      signatureStatus = json['signatureStatus'] as String,
      keyFingerprint = json['keyFingerprint'] as String?,
      mode = json['mode'] as String,
      installedVersion = json['installedVersion'] as String?,
      dataFormats = _strings(json['dataFormats']),
      addedFields = _strings(json['addedFields']),
      units = _strings(json['units']),
      codeLists = _strings(json['codeLists']),
      views = _strings(json['views']),
      formulas = _strings(json['formulas']),
      stockRules = _strings(json['stockRules']),
      exampleObjects = json['exampleObjects'] as int,
      dependencies = _strings(json['dependencies']),
      adjustments = _strings(json['adjustments']),
      conflicts = _strings(json['conflicts']),
      allowed = json['allowed'] as bool;
  final String packageId,
      version,
      name,
      description,
      notice,
      author,
      license,
      publishedAt,
      signatureStatus,
      mode;
  final String? keyFingerprint, installedVersion;
  final List<String> dataFormats,
      addedFields,
      units,
      codeLists,
      views,
      formulas,
      stockRules,
      dependencies,
      adjustments,
      conflicts;
  final int exampleObjects;
  final bool allowed;
}

class DomainPackageInstall {
  DomainPackageInstall.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      packageId = json['packageId'] as String,
      version = json['version'] as String,
      name = json['name'] as String,
      author = json['author'] as String,
      license = json['license'] as String,
      dataFormatCount = json['dataFormatCount'] as int;
  final String id, packageId, version, name, author, license;
  final int dataFormatCount;
}

class DomainPackageExport {
  DomainPackageExport.fromJson(Map<String, dynamic> json)
    : packageJson = json['packageJson'] as String,
      fileName = json['fileName'] as String,
      warnings = _strings(json['warnings']),
      dataFormats = json['dataFormats'] as int;
  final String packageJson, fileName;
  final List<String> warnings;
  final int dataFormats;
}

List<String> _strings(Object? value) => [
  for (final item in value as List<dynamic>) item as String,
];

const _previewFields =
    'packageId version name description notice author license publishedAt signatureStatus keyFingerprint mode installedVersion dataFormats addedFields units codeLists views formulas stockRules exampleObjects dependencies adjustments conflicts allowed';
const maxDomainPackageBytes = 512 * 1024;

class DomainPackageApi {
  const DomainPackageApi(this.api);
  final CollectionsApi api;

  Future<List<DomainPackageSummary>> pilots(String language) async {
    final data = await api.auth.authenticatedRequest(
      r'query($language:String){domainPackagePilots(language:$language){id version name description packageJson}}',
      {'language': language},
    );
    return [
      for (final item in data['domainPackagePilots'] as List<dynamic>)
        DomainPackageSummary.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<DomainPackagePreview> preview(
    String packageJson,
    String language, {
    String? collectionId,
  }) async {
    final data = await api.auth.authenticatedRequest(
      'query(\$packageJson:String!,\$collectionId:String,\$language:String){previewDomainPackage(packageJson:\$packageJson,collectionId:\$collectionId,language:\$language){$_previewFields}}',
      {
        'packageJson': packageJson,
        'collectionId': collectionId,
        'language': language,
      },
    );
    return DomainPackagePreview.fromJson(
      data['previewDomainPackage'] as Map<String, dynamic>,
    );
  }

  Future<String> install(
    String packageJson,
    String language, {
    String? collectionId,
    String? collectionName,
  }) async {
    final data = await api.auth.authenticatedRequest(
      r'mutation($packageJson:String!,$collectionId:String,$collectionName:String,$language:String){installDomainPackage(packageJson:$packageJson,collectionId:$collectionId,collectionName:$collectionName,language:$language){collectionId}}',
      {
        'packageJson': packageJson,
        'collectionId': collectionId,
        'collectionName': collectionName,
        'language': language,
      },
      timeout: const Duration(seconds: 40),
    );
    return (data['installDomainPackage']
            as Map<String, dynamic>)['collectionId']
        as String;
  }

  Future<List<DomainPackageInstall>> installs(String collectionId) async {
    final data = await api.auth.authenticatedRequest(
      r'query($collectionId:String!){domainPackageInstalls(collectionId:$collectionId){id packageId version name author license dataFormatCount}}',
      {'collectionId': collectionId},
    );
    return [
      for (final item in data['domainPackageInstalls'] as List<dynamic>)
        DomainPackageInstall.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> detach(String installId) => api.auth.authenticatedRequest(
    r'mutation($installId:String!){detachDomainPackage(installId:$installId)}',
    {'installId': installId},
  );

  Future<DomainPackageExport> export(
    String collectionId,
    Map<String, String> input,
    String language,
  ) async {
    final data = await api.auth.authenticatedRequest(
      r'query($collectionId:String!,$input:DomainPackageExportInput!,$language:String){exportDomainPackage(collectionId:$collectionId,input:$input,language:$language){packageJson fileName warnings dataFormats}}',
      {'collectionId': collectionId, 'input': input, 'language': language},
    );
    return DomainPackageExport.fromJson(
      data['exportDomainPackage'] as Map<String, dynamic>,
    );
  }

  /// Reads a package from an https link. Only the client downloads it; the server never fetches URLs.
  static Future<String> fetchLink(String link) async {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('https');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 ||
        response.bodyBytes.length > maxDomainPackageBytes) {
      throw const FormatException('download');
    }
    return utf8.decode(response.bodyBytes);
  }
}
