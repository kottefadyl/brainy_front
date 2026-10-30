import 'collections_api.dart';

class LedgerApi {
  const LedgerApi(this.api);
  final CollectionsApi api;

  Future<BrainyCollection> enable(String collectionId, String formatId) async {
    final data = await api.auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$formatId:String!){enableLedger(collectionId:\$collectionId,formatId:\$formatId){${CollectionsApi.workflowCollectionFields}}}',
      {'collectionId': collectionId, 'formatId': formatId},
    );
    return BrainyCollection.fromJson(data['enableLedger'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> verify(String collectionId, String formatId) async {
    final data = await api.auth.authenticatedRequest(
      'query(\$collectionId:String!,\$formatId:String!){verifyLedger(collectionId:\$collectionId,formatId:\$formatId){valid checked headHash redactionHash problem}}',
      {'collectionId': collectionId, 'formatId': formatId},
    );
    return data['verifyLedger'] as Map<String, dynamic>;
  }

  Future<String> proof(String collectionId, String formatId) async {
    final data = await api.auth.authenticatedRequest(
      'query(\$collectionId:String!,\$formatId:String!){ledgerProof(collectionId:\$collectionId,formatId:\$formatId)}',
      {'collectionId': collectionId, 'formatId': formatId},
    );
    return data['ledgerProof'] as String;
  }

  Future<String> balance(String collectionId, String formatId, String fieldId) async {
    final data = await api.auth.authenticatedRequest(
      'query(\$collectionId:String!,\$formatId:String!,\$fieldId:String!){ledgerBalance(collectionId:\$collectionId,formatId:\$formatId,fieldId:\$fieldId)}',
      {'collectionId': collectionId, 'formatId': formatId, 'fieldId': fieldId},
    );
    return data['ledgerBalance'] as String;
  }

  Future<BrainyEntry> correct(String originalId, Map<String, String> values) async {
    final data = await api.auth.authenticatedRequest(
      'mutation(\$originalId:String!,\$input:SaveEntryInput!){correctLedgerEntry(originalId:\$originalId,input:\$input){${CollectionsApi.workflowEntryFields}}}',
      {'originalId': originalId, 'input': {'values': [for (final item in values.entries) if (item.value.trim().isNotEmpty) {'fieldId': item.key, 'value': item.value.trim()}]}},
    );
    return BrainyEntry.fromJson(data['correctLedgerEntry'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> redact(String collectionId, String formatId, String entryId, List<String> fieldIds, String reason) async {
    final data = await api.auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$formatId:String!,\$entryId:String!,\$fieldIds:[String!]!,\$reason:String!){redactLedgerFields(collectionId:\$collectionId,formatId:\$formatId,entryId:\$entryId,fieldIds:\$fieldIds,reason:\$reason){valid checked headHash redactionHash problem}}',
      {'collectionId': collectionId, 'formatId': formatId, 'entryId': entryId, 'fieldIds': fieldIds, 'reason': reason},
    );
    return data['redactLedgerFields'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyStock(String collectionId, String productId) async {
    final data = await api.auth.authenticatedRequest('query(\$collectionId:String!,\$productId:String!){verifyStockLedger(collectionId:\$collectionId,productId:\$productId){valid checked headHash redactionHash problem}}', {'collectionId': collectionId, 'productId': productId});
    return data['verifyStockLedger'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sealStock(String collectionId, String productId) async {
    final data = await api.auth.authenticatedRequest('mutation(\$collectionId:String!,\$productId:String!){sealStockHistory(collectionId:\$collectionId,productId:\$productId){valid checked headHash redactionHash problem}}', {'collectionId': collectionId, 'productId': productId});
    return data['sealStockHistory'] as Map<String, dynamic>;
  }

  Future<String> stockProof(String collectionId, String productId) async {
    final data = await api.auth.authenticatedRequest('query(\$collectionId:String!,\$productId:String!){stockLedgerProof(collectionId:\$collectionId,productId:\$productId)}', {'collectionId': collectionId, 'productId': productId});
    return data['stockLedgerProof'] as String;
  }
}
