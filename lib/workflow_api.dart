import 'collections_api.dart';

extension WorkflowApi on CollectionsApi {
  Future<BrainyCollection> setWorkflow(
    String collectionId,
    String formatId,
    Map<String, dynamic> input,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$formatId:String!,\$input:WorkflowDefinitionInput!){setCollectionFormatWorkflow(collectionId:\$collectionId,formatId:\$formatId,input:\$input){${CollectionsApi.workflowCollectionFields}}}',
      {'collectionId': collectionId, 'formatId': formatId, 'input': input},
    );
    return BrainyCollection.fromJson(
      data['setCollectionFormatWorkflow'] as Map<String, dynamic>,
    );
  }

  Future<BrainyCollection> addWorkflowTemplate(
    String collectionId,
    String templateId,
    String color,
    String language,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$collectionId:String!,\$templateId:String!,\$color:String!,\$language:String){addCollectionWorkflowTemplate(collectionId:\$collectionId,templateId:\$templateId,color:\$color,language:\$language){${CollectionsApi.workflowCollectionFields}}}',
      {
        'collectionId': collectionId,
        'templateId': templateId,
        'color': color,
        'language': language,
      },
    );
    return BrainyCollection.fromJson(
      data['addCollectionWorkflowTemplate'] as Map<String, dynamic>,
    );
  }

  Future<BrainyEntry> transitionWorkflowEntry(
    String entryId,
    String to,
    DateTime expectedUpdatedAt,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$entryId:String!,\$to:String!,\$expectedUpdatedAt:String!){transitionWorkflowEntry(entryId:\$entryId,to:\$to,expectedUpdatedAt:\$expectedUpdatedAt){${CollectionsApi.workflowEntryFields}}}',
      {
        'entryId': entryId,
        'to': to,
        'expectedUpdatedAt': expectedUpdatedAt.toUtc().toIso8601String(),
      },
    );
    return BrainyEntry.fromJson(
      data['transitionWorkflowEntry'] as Map<String, dynamic>,
    );
  }

  Future<BrainyEntry> assignWorkflowEntry(
    String entryId,
    Map<String, dynamic> input,
  ) async {
    final data = await auth.authenticatedRequest(
      'mutation(\$entryId:String!,\$input:WorkflowAssignmentInput!){assignWorkflowEntry(entryId:\$entryId,input:\$input){${CollectionsApi.workflowEntryFields}}}',
      {'entryId': entryId, 'input': input},
    );
    return BrainyEntry.fromJson(
      data['assignWorkflowEntry'] as Map<String, dynamic>,
    );
  }

  Future<List<Map<String, dynamic>>> workflowNotifications() async {
    final data = await auth.authenticatedRequest(
      'query{workflowNotifications{id collectionId entryId kind actorUserId createdAt readAt}}',
      {},
    );
    return (data['workflowNotifications'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> readWorkflowNotification(String id) async {
    await auth.authenticatedRequest(
      r'mutation($id:String!){readWorkflowNotification(id:$id)}',
      {'id': id},
    );
  }
}
