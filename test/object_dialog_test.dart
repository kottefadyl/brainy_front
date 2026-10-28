import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/object_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ObjectAuthApi extends AuthApi {
  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables,
  ) async {
    if (query.contains('objectModelTemplates')) {
      return {'objectModelTemplates': <Map<String, dynamic>>[]};
    }
    if (query.contains('collectionObjectsPage')) {
      return {
        'collectionObjectsPage': {
          'entries': [
            {
              'id': 'object-1',
              'formatId': 'product',
              'sourceObjectId': null,
              'values': [
                {'fieldId': 'name', 'value': 'Bottle'},
              ],
              'createdAt': '2026-01-01T00:00:00Z',
              'updatedAt': '2026-01-01T00:00:00Z',
            },
          ],
          'nextCursor': null,
          'hasMore': false,
        },
      };
    }
    if (query.contains('collectionObject(')) {
      return {
        'collectionObject': {
          'id': 'object-1',
          'formatId': 'product',
          'sourceObjectId': null,
          'values': [
            {'fieldId': 'name', 'value': 'Bottle'},
          ],
          'createdAt': '2026-01-01T00:00:00Z',
          'updatedAt': '2026-01-01T00:00:00Z',
          'revisions': [
            {
              'at': '2025-12-31T00:00:00Z',
              'formatVersion': 1,
              'values': [
                {'fieldId': 'name', 'value': 'Bottle old'},
              ],
            },
          ],
        },
      };
    }
    throw StateError('Unexpected GraphQL request: $query');
  }
}

class _ConversionAuthApi extends _ObjectAuthApi {
  _ConversionAuthApi(this.collectionJson);

  final Map<String, dynamic> collectionJson;
  Map<String, dynamic>? confirmation;

  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables,
  ) async {
    if (query.contains('collectionFormatImpact')) {
      return {
        'collectionFormatImpact': {
          'entryCount': 2,
          'populatedFieldIds': <String>['catalog-name'],
        },
      };
    }
    if (query.contains('setCollectionFormatObjectModel')) {
      confirmation = Map<String, dynamic>.from(variables);
      return {
        'setCollectionFormatObjectModel': {
          ...collectionJson,
          'formats': [
            for (final format in collectionJson['formats'] as List<dynamic>)
              if ((format as Map<String, dynamic>)['id'] == 'catalog')
                {...format, 'objectModel': true, 'version': 2}
              else
                format,
          ],
        },
      };
    }
    return super.authenticatedRequest(query, variables);
  }
}

void main() {
  testWidgets(
    'object library keeps detail and create action usable at 320 px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final collection = BrainyCollection.fromJson({
        'id': 'collection-1',
        'name': 'Shop',
        'fields': [
          {'id': 'note', 'name': 'Text', 'kind': 'TEXT'},
        ],
        'formats': [
          {
            'id': 'product',
            'name': 'Product',
            'color': '#EDF9F3',
            'version': 1,
            'objectModel': true,
            'fields': [
              {'id': 'name', 'name': 'Name', 'kind': 'TITLE'},
            ],
          },
          {
            'id': 'note-format',
            'name': 'Note',
            'color': '#EEF5FF',
            'version': 1,
            'objectModel': false,
            'fields': [
              {'id': 'note', 'name': 'Text', 'kind': 'TEXT'},
            ],
          },
        ],
      });
      ObjectEditorRequest? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  chosen = await showDialog<ObjectEditorRequest>(
                    context: context,
                    builder: (_) => ObjectDialog(
                      collection: collection,
                      api: CollectionsApi(_ObjectAuthApi()),
                      onCollection: (_) {},
                      onEntriesChanged: () {},
                    ),
                  );
                },
                child: const Text('Open objects'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open objects'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bottle'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Bottle'), findsOneWidget);
      await tester.tap(find.text('Bottle'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Previous versions: 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Previous versions: 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Create object'),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Create object'));
      await tester.pumpAndSettle();
      expect(chosen?.formatId, 'product');
      expect(chosen?.entry, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('converting existing entries needs explicit confirmation', (
    tester,
  ) async {
    final collectionJson = <String, dynamic>{
      'id': 'collection-1',
      'name': 'Shop',
      'fields': [
        {'id': 'product-name', 'name': 'Name', 'kind': 'TITLE'},
      ],
      'formats': [
        {
          'id': 'product',
          'name': 'Product',
          'color': '#EDF9F3',
          'version': 1,
          'objectModel': true,
          'fields': [
            {'id': 'product-name', 'name': 'Name', 'kind': 'TITLE'},
          ],
        },
        {
          'id': 'catalog',
          'name': 'Catalog',
          'color': '#EEF5FF',
          'version': 1,
          'objectModel': false,
          'fields': [
            {'id': 'catalog-name', 'name': 'Name', 'kind': 'TITLE'},
          ],
        },
      ],
    };
    final auth = _ConversionAuthApi(collectionJson);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<ObjectEditorRequest>(
                context: context,
                builder: (_) => ObjectDialog(
                  collection: BrainyCollection.fromJson(collectionJson),
                  api: CollectionsApi(auth),
                  onCollection: (_) {},
                  onEntriesChanged: () {},
                ),
              ),
              child: const Text('Open objects'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open objects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add an object model'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<String>).at(1),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catalog').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use for objects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use for objects'));
    await tester.pumpAndSettle();
    expect(find.text('Convert to objects?'), findsOneWidget);
    expect(auth.confirmation, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.confirmation, isNull);
    await tester.tap(find.text('Use for objects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(auth.confirmation?['expectedEntryCount'], 2);
    expect(auth.confirmation?['formatId'], 'catalog');
    expect(tester.takeException(), isNull);
  });
}
