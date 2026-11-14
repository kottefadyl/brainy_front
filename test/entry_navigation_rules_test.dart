import 'package:brainy/entries_pager.dart';
import 'package:brainy/format_entry_rules_inputs.dart';
import 'package:brainy/view_memory.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// Large lists, remembered views, entry limits and required fields.
void main() {
  test('an entry limit is empty (no limit) or a whole number from 1', () {
    expect(parseMaxEntries(''), (ok: true, value: null));
    expect(parseMaxEntries(' 1 '), (ok: true, value: 1));
    expect(parseMaxEntries('250'), (ok: true, value: 250));
    expect(parseMaxEntries('0').ok, isFalse);
    expect(parseMaxEntries('2.5').ok, isFalse);
    expect(parseMaxEntries('-3').ok, isFalse);
  });

  test('required fields left empty are named, in both languages', () {
    final fields = [
      (name: 'Place', required: true, filled: false),
      (name: 'Depth', required: false, filled: false),
      (name: 'Date', required: true, filled: true),
    ];
    expect(missingRequiredMessage(fields, false), 'Fill in the required fields: Place.');
    expect(missingRequiredMessage(fields, true), 'Champs obligatoires à remplir : Place.');
    expect(missingRequiredMessage([(name: 'Date', required: true, filled: true)], false), isNull);
    expect(requiredLabel('Place', true), 'Place *');
    expect(requiredLabel('Depth', false), 'Depth');
  });

  test('totals are grouped for reading', () {
    expect(groupedNumber(4512, french: false), '4,512');
    expect(groupedNumber(4512, french: true), '4 512');
    expect(groupedNumber(30, french: false), '30');
    expect(EntriesPager.needed(offset: 0, total: 12, shown: 12, hasMore: false), isFalse);
    expect(EntriesPager.needed(offset: 0, total: 4512, shown: 30, hasMore: true), isTrue);
  });

  test('the chosen collection, view and page size survive a restart', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final views = [{'id': 'by-date'}];
    final first = ViewMemory('user-1');
    await first.load();
    first.remember(collectionId: 'journal', viewId: 'by-date');
    first.rememberPageSize(100);
    await Future<void>.delayed(Duration.zero);

    final reopened = ViewMemory('user-1');
    await reopened.load();
    expect(reopened.collectionId, 'journal');
    expect(reopened.viewIdFor('journal', views), 'by-date');
    expect(reopened.viewIdFor('journal', const []), isNull, reason: 'a deleted view falls back to the default list');
    expect(reopened.pageSize, 100);
    expect(ViewMemory('user-2').pageSize, 30);
  });

  test('the account copy wins and every change is saved back to the account', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final saved = <Map<String, dynamic>>[];
    final memory = ViewMemory('user-3', saveToAccount: (preferences) async => saved.add(preferences));
    await memory.load();
    memory.adopt({'lastCollectionId': 'garden', 'pageSize': 50, 'views': [{'collectionId': 'garden', 'viewId': 'week'}]});
    expect(memory.collectionId, 'garden');
    expect(memory.viewIdFor('garden', [{'id': 'week'}]), 'week');
    expect(memory.pageSize, 50);
    memory.remember(collectionId: 'journal', viewId: 'by-date');
    memory.rememberPageSize(100);
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    expect(saved, hasLength(1), reason: 'quick changes make one save');
    expect(saved.single['lastCollectionId'], 'journal');
    expect(saved.single['pageSize'], 100);
    expect(saved.single['views'], containsAll([{'collectionId': 'garden', 'viewId': 'week'}, {'collectionId': 'journal', 'viewId': 'by-date'}]));
    memory.dispose();
  });
}
