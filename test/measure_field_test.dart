import 'package:brainy/app_strings.dart';
import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _CaptureAuth extends AuthApi {
  Map<String, dynamic>? input;

  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    input = variables['input'] as Map<String, dynamic>;
    return {
      'createEntry': {
        'id': 'e',
        'values': [
          {
            'fieldId': 'm',
            'value': '',
            'measureValue': {'status': 'ABSENT', 'uncertainty': null},
          },
        ],
        'createdAt': '2026-11-09T10:00:00.000Z',
        'updatedAt': '2026-11-09T10:00:00.000Z',
      },
    };
  }
}

void main() {
  test('an absent measure is sent without a value and read back', () async {
    final auth = _CaptureAuth();
    final entry = await CollectionsApi(auth).saveEntry(
      'c',
      {'m': '', 'other': ''},
      measures: {
        'm': {'status': 'ABSENT'},
      },
    );
    expect(auth.input!['values'], [
      {
        'fieldId': 'm',
        'value': '',
        'measureValue': {'status': 'ABSENT'},
      },
    ]);
    expect(entry.measures['m'], {'status': 'ABSENT'});
  });

  test('measure details travel with the value', () async {
    final auth = _CaptureAuth();
    await CollectionsApi(auth).saveEntry(
      'c',
      {'m': '12.5'},
      measures: {
        'm': {'status': 'ESTIMATED', 'uncertainty': '0.05', 'uncertaintyType': 'RELATIVE'},
      },
    );
    final value = (auth.input!['values'] as List).single as Map;
    expect(value['value'], '12.5');
    expect((value['measureValue'] as Map)['uncertaintyType'], 'RELATIVE');
  });

  test('an API refusal without a translation keeps its reason in French', () {
    expect(
      AppStrings('fr').error(const AuthApiException('A brand new refusal')),
      'Une erreur est survenue : A brand new refusal',
    );
    expect(
      AppStrings('fr').error(StateError('internal')),
      'Une erreur est survenue. Réessayez.',
    );
    expect(
      AppStrings('fr').error(const AuthApiException('A formula already exists')),
      'Une erreur est survenue : A formula already exists',
    );
  });
}
