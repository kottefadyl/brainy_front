import 'package:brainy/collections_api.dart';
import 'package:brainy/data_source_api.dart';
import 'package:brainy/data_source_form_page.dart';
import 'package:brainy/data_source_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same content gives the same delivery ID, different content another',
    () {
      const csv = 'id;temp\nS1;21,5\n';
      expect(deliveryIdFor(csv), deliveryIdFor(csv));
      expect(deliveryIdFor(csv), isNot(deliveryIdFor('$csv\nS2;19')));
      expect(
        RegExp(r'^[\w.:-]{1,100}$').hasMatch(deliveryIdFor(csv)),
        isTrue,
        reason: 'accepted by the API',
      );
    },
  );

  test(
    'a delivery run keeps counts, rejections and the fact/reception delay',
    () {
      final run = DataSourceRun.fromJson({
        'id': 'r1',
        'origin': 'PUSH',
        'state': 'COMPLETED',
        'total': 8,
        'processed': 8,
        'createdCount': 2,
        'updatedCount': 0,
        'unchangedCount': 0,
        'olderCount': 0,
        'rejectedCount': 6,
        'ignoredColumns': ['extra'],
        'receivedAt': '2026-11-08T10:00:00.000Z',
        'durationMs': 18,
        'rowsPerSecond': 444.44,
        'maxLagSeconds': 7200,
        'rejections': [
          {
            'row': 4,
            'recordId': 'S3',
            'code': 'UNIT_MISMATCH',
            'message': 'Température: received unit °F, expected °C',
          },
        ],
      });
      expect(run.active, isFalse);
      expect(run.rejections!.single.recordId, 'S3');
      expect(
        rejectionLabel(run.rejections!.single.code, true),
        'Unité différente',
      );
      expect(runStateLabel('FAILED', false), 'Stopped by an error');
    },
  );

  test('French error texts explain a missing column', () {
    expect(
      dataSourceErrorText(
        Exception('MISSING_COLUMN: Missing column: temp, unite'),
        true,
      ),
      'Colonne absente du fichier : temp, unite',
    );
    expect(
      dataSourceErrorText(
        Exception('Only a collection owner can perform this action'),
        false,
      ),
      contains('collection owner'),
    );
  });

  testWidgets(
    'the form explains why it cannot be saved yet, then returns the mapping',
    (tester) async {
      const format = BrainyFormat(
        id: 'f1',
        name: 'Relevé',
        color: '#EEF5FF',
        fields: [
          BrainyField(id: 'a', name: 'Capteur', kind: BrainyFieldKind.title),
          BrainyField(id: 'b', name: 'Pièce', kind: BrainyFieldKind.attachment),
        ],
      );
      const collection = BrainyCollection(
        id: 'c1',
        name: 'Capteurs',
        fields: [],
        formats: [format],
      );
      DataSourceInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await Navigator.push<DataSourceInput>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DataSourceFormPage(
                        collection: collection,
                        french: false,
                      ),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Name the data source to continue.'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Pièce'),
        findsNothing,
        reason: 'attachments cannot be filled by a source',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'North station',
      );
      await tester.pump();
      expect(find.text('Name the data source to continue.'), findsNothing);
      await tester.tap(find.text('Create data source'));
      await tester.pumpAndSettle();
      expect(result?.name, 'North station');
      expect(result?.recordIdColumn, 'id');
      expect(result?.mappings.single.column, 'Capteur');
      expect(result?.decimalSeparator, 'DOT');
    },
  );
}
