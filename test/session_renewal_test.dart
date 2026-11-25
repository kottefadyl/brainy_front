import 'dart:convert';

import 'package:brainy/auth_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = {
  'id': 'u1', 'name': 'Ada', 'email': 'ada@example.test', 'profession': '', 'job': '',
  'fieldOfStudy': '', 'interests': <String>[], 'hobbies': <String>[], 'profileCompleted': true,
  'hasProfilePhoto': false, 'onboardingCompleted': true, 'viewPreferences': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restoring a session renews its token', () async {
    FlutterSecureStorage.setMockInitialValues({'brainy_session': 'old'});
    final queries = <String>[];
    final api = AuthApi(client: MockClient((request) async {
      queries.add((jsonDecode(request.body) as Map)['query'] as String);
      expect(request.headers['Authorization'], 'Bearer old');
      return http.Response(jsonEncode({'data': {'renewSession': {'token': 'new', 'user': _user}}}), 200);
    }));
    final user = await api.restoreSession();
    expect(user?.id, 'u1');
    expect(queries.single, contains('renewSession'));
    expect(await const FlutterSecureStorage().read(key: 'brainy_session'), 'new');
  });

  test('an unreachable API keeps the stored session, a rejected one removes it', () async {
    FlutterSecureStorage.setMockInitialValues({'brainy_session': 'old'});
    var calls = 0;
    final offline = AuthApi(client: MockClient((_) async { calls++; throw Exception('offline'); }));
    await expectLater(offline.restoreSession(), throwsA(isA<AuthApiException>()));
    expect(calls, 2);
    expect(await const FlutterSecureStorage().read(key: 'brainy_session'), 'old');

    final rejected = AuthApi(client: MockClient((_) async => http.Response(jsonEncode({
      'errors': [{'message': 'Invalid or expired session', 'extensions': {'code': 'UNAUTHENTICATED'}}],
    }), 200)));
    expect(await rejected.restoreSession(), isNull);
    expect(await const FlutterSecureStorage().read(key: 'brainy_session'), isNull);
  });
}
