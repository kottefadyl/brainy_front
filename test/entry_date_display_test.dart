import 'package:brainy/app_strings.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/entry_clipboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const date = BrainyField(id: 'd', name: 'Début', kind: BrainyFieldKind.date);
  const moment = BrainyField(id: 'm', name: 'Moment', kind: BrainyFieldKind.datetime);

  test('a stored date reads in the app language', () {
    expect(displayEntryValue(date, '2026-11-20', AppStrings('fr')), '20 nov. 2026');
    expect(displayEntryValue(date, '2026-11-20', AppStrings('en')), 'Nov 20, 2026');
  });

  test('a value that is not a date stays as written', () {
    expect(displayEntryValue(date, 'bientôt', AppStrings('fr')), 'bientôt');
    expect(displayEntryValue(date, '2026-13-01', AppStrings('fr')), '2026-13-01');
  });

  test('a stored date and time reads in local time', () {
    final stored = DateTime(2026, 3, 1, 14, 5).toUtc().toIso8601String();
    expect(displayEntryValue(moment, stored, AppStrings('fr')), '1 mars 2026, 14:05');
    expect(displayEntryValue(moment, stored, AppStrings('en')), 'Mar 1, 2026, 2:05 PM');
  });
}
