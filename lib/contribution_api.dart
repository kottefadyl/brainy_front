import 'collections_api.dart';

extension ContributionApi on CollectionsApi {
  static const _link =
      'id collectionId formatId fieldIds titleEn titleFr consentEn consentFr allowAnonymous expiresAt revokedAt createdAt';
  static const _submission =
      'id linkId formatId status receivedAt respondentEmail acceptedEntryId duplicateOf values{fieldId value} events{kind at actorId}';

  Future<Map<String, dynamic>> createContributionLink(
    String collectionId,
    Map<String, dynamic> input,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$input:CreateContributionLinkInput!){createContributionLink(collectionId:\$collectionId,input:\$input){token link{$_link}}}',
      {'collectionId': collectionId, 'input': input},
    );
    return data['createContributionLink'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> contributionLinks(
    String collectionId,
  ) async {
    final data = await auth.authenticatedRequest(
      'query(\$collectionId:String!){contributionLinks(collectionId:\$collectionId){$_link}}',
      {'collectionId': collectionId},
    );
    return (data['contributionLinks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> revokeContributionLink(String id) async {
    await auth.authenticatedRequest(
      'mutation(\$id:String!){revokeContributionLink(id:\$id){id}}',
      {'id': id},
    );
  }

  Future<List<Map<String, dynamic>>> contributionSubmissions(
    String collectionId,
  ) async {
    final data = await auth.authenticatedRequest(
      'query(\$collectionId:String!){contributionSubmissions(collectionId:\$collectionId){$_submission}}',
      {'collectionId': collectionId},
    );
    return (data['contributionSubmissions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> correctContribution(
    String id,
    List<Map<String, String>> values,
  ) async {
    await auth.authenticatedRequest(
      'mutation(\$id:String!,\$values:[EntryValueInput!]!){correctContribution(id:\$id,values:\$values){id}}',
      {'id': id, 'values': values},
    );
  }

  Future<void> reviewContribution(
    String id,
    String action, {
    String? duplicateOf,
  }) async {
    await auth.authenticatedRequest(
      'mutation(\$id:String!,\$action:String!,\$duplicateOf:String){reviewContribution(id:\$id,action:\$action,duplicateOf:\$duplicateOf){id}}',
      {'id': id, 'action': action, 'duplicateOf': ?duplicateOf},
    );
  }

  Future<void> eraseContribution(String id) async {
    await auth.authenticatedRequest(
      'mutation(\$id:String!){eraseContribution(id:\$id)}',
      {'id': id},
    );
  }
}
