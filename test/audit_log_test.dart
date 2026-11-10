import 'package:brainy/audit_log_screen.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter_test/flutter_test.dart';

BrainyAuditLog _log(String action, String? details, {String userId = 'u1'}) =>
    BrainyAuditLog(id: 'a', collectionId: 'c', userId: userId, action: action, details: details, occurredAt: DateTime.utc(2026, 11, 10, 9, 30));

void main() {
  test('privacy actions get natural labels in both languages, unknown codes stay readable', () {
    expect(auditActionLabel('SENSITIVE_AGGREGATE_ALERT', french: true), 'Alerte : requêtes sensibles répétées');
    expect(auditActionLabel('READ_SENSITIVE_AGGREGATE', french: false), 'Sensitive analysis served');
    expect(auditActionLabel('SOME_NEW_THING', french: true), 'some new thing');
    expect(isPrivacyAction('UPDATE_ENTRY'), isFalse);
  });

  test('details drop the technical query key and alerts are told in plain words', () {
    expect(auditDetailText(_log('READ_SENSITIVE_AGGREGATE', 'Data format f1; operation SUM; query 0123456789abcdef; observations 8'), french: false), 'Sum · 8 observations');
    expect(auditDetailText(_log('READ_SENSITIVE_AGGREGATE', 'Data format f1; operation AVERAGE; query 0123456789abcdef; observations 57'), french: true), 'Moyenne · 57 observations');
    expect(auditDetailText(_log('REFUSED_SENSITIVE_AGGREGATE', 'Data format f1; operation MEDIAN; query 0123456789abcdef; refused: group below 5'), french: true), 'Médiane · refusée : group below 5');
    expect(auditDetailText(_log('SENSITIVE_AGGREGATE_ALERT', 'BURST: the same sensitive question was asked repeatedly within an hour; data format f1; query 0123456789abcdef'), french: true),
        'la même question a été posée de nombreuses fois en une heure');
    expect(auditDetailText(_log('UPDATE_ENTRY', null), french: true), '');
  });

  test('the actor is the member name, the owner, or a plain member', () {
    final collection = BrainyCollection.fromJson({
      'id': 'c', 'name': 'Clinic', 'ownerId': 'owner', 'formats': [], 'fields': [],
      'members': [{'userId': 'u1', 'email': 'ana@example.test', 'name': 'Ana', 'role': 'EDITOR', 'addedAt': '2026-11-01T00:00:00Z'}],
    });
    expect(auditActor(_log('X', null), collection, french: false), 'Ana');
    expect(auditActor(_log('X', null, userId: 'owner'), collection, french: true), 'Propriétaire');
    expect(auditActor(_log('X', null, userId: 'ghost'), collection, french: false), 'Member');
  });
}
