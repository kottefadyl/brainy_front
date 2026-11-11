// T52: collaborators (personal link, acceptance, list, end of collaboration).
import 'package:flutter/foundation.dart';

import 'auth_api.dart';
import 'collections_api.dart';

class BrainyCollaborator {
  const BrainyCollaborator({required this.userId, required this.name, required this.email, required this.since, required this.hasPhoto});

  final String userId, name, email;
  final DateTime since;
  final bool hasPhoto;

  factory BrainyCollaborator.fromJson(Map<String, dynamic> json) => BrainyCollaborator(
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        since: DateTime.tryParse(json['since'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        hasPhoto: json['hasPhoto'] as bool? ?? false,
      );
}

typedef CollaborationInvitePreview = ({String inviterName, bool isSelf, bool alreadyCollaborator});

/// Address of the web app, where collaboration links open (same rule as contribution links).
String webAppBase() {
  const configured = String.fromEnvironment('WEB_APP_URL');
  if (configured.isNotEmpty) return configured;
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:3001' : 'http://localhost:3001';
}

String collaborationLink(String token) => '${webAppBase()}/invite/${Uri.encodeComponent(token)}';

/// Token found in a pasted link (`…/invite/<token>`) or a bare token; null when there is none.
String? inviteTokenFrom(String text) {
  final trimmed = text.trim();
  final fromLink = RegExp(r'/invite/([A-Za-z0-9_-]{16,64})').firstMatch(trimmed);
  if (fromLink != null) return fromLink.group(1);
  return RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(trimmed) ? trimmed : null;
}

/// French text of the collaboration errors returned by the API.
String collaboratorError(Object error, bool french) {
  final message = error.toString();
  const rules = {
    'Share only with your collaborators': ('Share only with your collaborators: send them your collaboration link first.', 'Partagez seulement avec vos collaborateurs : envoyez-leur d’abord votre lien de collaboration.'),
    'This collaboration link is no longer valid': ('This collaboration link is no longer valid. Ask the sender for a new one.', 'Ce lien de collaboration n’est plus valable. Demandez-en un nouveau à la personne qui vous l’a envoyé.'),
    'You cannot collaborate with yourself': ('This is your own link: send it to a colleague so they can accept it.', 'C’est votre propre lien : envoyez-le à un collègue pour qu’il l’accepte.'),
    'Collaborator not found': ('This collaborator no longer exists.', 'Ce collaborateur n’existe plus.'),
    'Only a collection owner': ('Only the collection owner can do this.', 'Seul le propriétaire de la collection peut effectuer cette action.'),
  };
  for (final rule in rules.entries) {
    if (message.contains(rule.key)) return french ? rule.value.$2 : rule.value.$1;
  }
  return message.replaceFirst('Exception: ', '');
}

class CollaboratorsApi {
  CollaboratorsApi(this.auth);
  final AuthApi auth;

  static const _fields = 'userId name email since hasPhoto';

  Future<String> inviteToken() async => (await auth.authenticatedRequest('query{collaborationInviteToken}', {}))['collaborationInviteToken'] as String;

  Future<String> regenerate() async => (await auth.authenticatedRequest('mutation{regenerateCollaborationInvite}', {}))['regenerateCollaborationInvite'] as String;

  Future<CollaborationInvitePreview> preview(String token) async {
    final data = (await auth.authenticatedRequest('query(\$token:String!){collaborationInvite(token:\$token){inviterName isSelf alreadyCollaborator}}', {'token': token}))['collaborationInvite'] as Map<String, dynamic>;
    return (inviterName: data['inviterName'] as String, isSelf: data['isSelf'] as bool, alreadyCollaborator: data['alreadyCollaborator'] as bool);
  }

  Future<BrainyCollaborator> accept(String token) async =>
      BrainyCollaborator.fromJson((await auth.authenticatedRequest('mutation(\$token:String!){acceptCollaboration(token:\$token){$_fields}}', {'token': token}))['acceptCollaboration'] as Map<String, dynamic>);

  Future<List<BrainyCollaborator>> list() async => [
        for (final item in (await auth.authenticatedRequest('query{collaborators{$_fields}}', {}))['collaborators'] as List<dynamic>)
          BrainyCollaborator.fromJson(item as Map<String, dynamic>),
      ];

  Future<String?> photo(String userId) async => (await auth.authenticatedRequest('query(\$userId:String!){collaboratorPhoto(userId:\$userId)}', {'userId': userId}))['collaboratorPhoto'] as String?;

  Future<void> end(String userId) => auth.authenticatedRequest('mutation(\$userId:String!){endCollaboration(userId:\$userId)}', {'userId': userId});

  /// Shares [collection] with a collaborator, keeping any field restriction already set (T28).
  Future<void> share(BrainyCollection collection, String userId, BrainyCollectionRole role) {
    final member = collection.members.where((item) => item.userId == userId).firstOrNull;
    return auth.authenticatedRequest(
      'mutation(\$c:String!,\$u:String!,\$r:CollectionRole!,\$s:[String!],\$p:[String!]){addCollectionMember(collectionId:\$c,memberUserId:\$u,role:\$r,sharedFieldIds:\$s,sensitiveFieldIds:\$p){id}}',
      {'c': collection.id, 'u': userId, 'r': role == BrainyCollectionRole.editor ? 'EDITOR' : 'READER', 's': member?.sharedFieldIds, 'p': member?.sensitiveFieldIds},
    );
  }

  Future<void> unshare(String collectionId, String userId) => auth.authenticatedRequest(
        'mutation(\$c:String!,\$u:String!){removeCollectionMember(collectionId:\$c,memberUserId:\$u){id}}',
        {'c': collectionId, 'u': userId},
      );
}
