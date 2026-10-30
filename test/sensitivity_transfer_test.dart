import 'package:flutter_test/flutter_test.dart';

import 'package:brainy/collection_transfer.dart';
import 'package:brainy/collections_api.dart';

class _ExportApi extends Fake implements CollectionsApi {
  _ExportApi(this.page);

  final BrainyEntryPage page;

  @override
  Future<BrainyEntryPage> entriesPage(
    String collectionId, {
    String? after,
    String? search,
    String? formatId,
    String? fieldId,
    String? operatorName,
    String? filterValue,
    String? viewId,
  }) async => page;

  @override
  Future<List<Map<String, dynamic>>> entryLinks(
    String collectionId,
    String entryId, {
    bool includeDeleted = false,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> relations(
    String collectionId,
    String entryId,
  ) async => [
    {
      'id': 'relation',
      'fromEntryId': entryId,
      'toEntryId': entryId,
      'kind': 'ASSOCIATION',
      'label': 'related',
      'snapshotValue': 'private snapshot',
      'snapshotUnit': 'private unit',
      'snapshotFieldId': 'private-field',
    },
  ];
}

void main() {
  test(
    'collection exports omit protected values unless explicitly included',
    () async {
      const fields = [
        BrainyField(id: 'title', name: 'Title', kind: BrainyFieldKind.title),
        BrainyField(
          id: 'legacy-position',
          name: 'Position',
          kind: BrainyFieldKind.position,
        ),
        BrainyField(
          id: 'public-position',
          name: 'Approximate position',
          kind: BrainyFieldKind.position,
          sensitivity: 'ORDINARY',
        ),
        BrainyField(
          id: 'diagnosis',
          name: 'Diagnosis',
          kind: BrainyFieldKind.text,
          sensitivity: 'SENSITIVE',
        ),
      ];
      const format = BrainyFormat(
        id: 'format',
        name: 'Records',
        color: '#EEF5FF',
        fields: fields,
        workflow: {'stateFieldId': 'diagnosis'},
      );
      final collection = BrainyCollection(
        id: 'collection',
        name: 'Private records',
        fields: fields,
        formats: const [format],
        sharedObjects: const [
          {'objectName': 'private object'},
        ],
      );
      final entry = BrainyEntry(
        id: 'entry',
        formatId: format.id,
        values: const {
          'title': 'Record A',
          'legacy-position': '{"latitude":6.5,"longitude":3.3}',
          'public-position': '{"latitude":6.5,"longitude":3.3}',
          'diagnosis': 'private diagnosis',
        },
        objectSnapshots: const {
          'title': [
            {'value': 'private snapshot'},
          ],
        },
        workflow: const {
          'history': [
            {'from': 'private', 'to': 'closed'},
          ],
        },
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final api = _ExportApi(BrainyEntryPage(entries: [entry], hasMore: false));

      final safe = await BrainyTransfer.export(collection, api);
      final safeFields = (safe.formats.single['fields'] as List)
          .cast<Map<String, dynamic>>()
          .map((field) => field['id'])
          .toList();
      expect(safeFields, ['title', 'public-position']);
      final safeValues = (safe.entries.single['values'] as List)
          .cast<Map<String, dynamic>>();
      expect(safeValues.map((value) => value['fieldId']), [
        'title',
        'public-position',
      ]);
      expect(safeValues.first, isNot(contains('objectSnapshots')));
      expect(safe.entries.single, isNot(contains('workflowHistory')));
      expect(safe.source['sharedObjects'], isEmpty);
      expect(safe.relations.single, isNot(contains('snapshotValue')));

      final full = await BrainyTransfer.export(
        collection,
        api,
        includeSensitive: true,
      );
      expect((full.formats.single['fields'] as List).length, fields.length);
      expect((full.entries.single['values'] as List).length, fields.length);
      expect(full.entries.single, contains('workflowHistory'));
      expect(full.source['sharedObjects'], isNotEmpty);
      expect(full.relations.single['snapshotValue'], 'private snapshot');
    },
  );
}
