import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/period_totals_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthApi {
  final analysed = <Map<String, dynamic>>[];
  Map<String, dynamic>? saved;
  String month = '1500.5';

  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (query.contains('analyseCollection')) {
      final input = variables['input'] as Map<String, dynamic>;
      analysed.add(input);
      final from = input['from'] as String;
      final value = from.endsWith('-01-01')
          ? '250000'
          : from.endsWith('-01')
          ? month
          : '700';
      return {
        'analyseCollection': {
          'rows': [
            {'group': 'all', 'label': 'all', 'value': value, 'count': 1},
          ],
        },
      };
    }
    if (query.contains('createEntry')) {
      saved = variables['input'] as Map<String, dynamic>;
      return {
        'createEntry': {
          'id': 'e',
          'collectionId': 'c',
          'formatId': 'f',
          'values': saved!['values'],
          'createdAt': '2026-11-09T10:00:00Z',
          'updatedAt': '2026-11-09T10:00:00Z',
        },
      };
    }
    throw StateError('Unexpected query: $query');
  }
}

const _format = BrainyFormat(
  id: 'f',
  name: 'Bilan du jour',
  color: '#EAF8FA',
  fields: [
    BrainyField(id: 'd', name: 'Date', kind: BrainyFieldKind.date),
    BrainyField(id: 'a', name: 'Montant', kind: BrainyFieldKind.number),
  ],
);

BrainyCollection _collection({BrainyPeriodTotals? totals}) => BrainyCollection(
  id: 'c',
  name: 'KT personal',
  fields: _format.fields,
  formats: const [_format],
  periodTotals: totals,
);

const _config = BrainyPeriodTotals(
  formatId: 'f',
  dateFieldId: 'd',
  amountFieldId: 'a',
);

void main() {
  group('periodRanges', () {
    test('uses a Monday to Sunday week', () {
      final ranges = periodRanges(DateTime(2026, 11, 9)); // A Monday.
      expect(ranges.week, (from: '2026-11-09', to: '2026-11-15'));
      final sunday = periodRanges(DateTime(2026, 11, 8));
      expect(sunday.week, (from: '2026-11-02', to: '2026-11-08'));
    });

    test('covers the whole month and year, across a boundary', () {
      final ranges = periodRanges(DateTime(2028, 2, 10));
      expect(ranges.month, (from: '2028-02-01', to: '2028-02-29'));
      expect(ranges.year, (from: '2028-01-01', to: '2028-12-31'));
      final newYear = periodRanges(DateTime(2027, 1, 1)); // A Friday.
      expect(newYear.week, (from: '2026-12-28', to: '2027-01-03'));
    });
  });

  test('parseAmount accepts a French amount and refuses text', () {
    expect(parseAmount('12 500,50'), '12500.50');
    expect(parseAmount('3000'), '3000');
    expect(parseAmount('abc'), isNull);
    expect(parseAmount(''), isNull);
    expect(parseAmount('-5'), isNull);
  });

  test('formatAmount groups thousands without rounding', () {
    expect(formatAmount('1234567.5', french: true), '1 234 567,5');
    expect(formatAmount('1234567.5', french: false), '1,234,567.5');
    expect(formatAmount('900', french: true), '900');
    expect(
      formatAmount('12345678901234567890.25', french: false),
      '12,345,678,901,234,567,890.25',
    );
  });

  group('PeriodTotalsPanel', () {
    Future<_Auth> pump(WidgetTester tester, BrainyCollection collection, VoidCallback onSaved) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _Auth();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PeriodTotalsPanel(
                api: CollectionsApi(auth),
                collection: collection,
                entries: const [],
                french: true,
                onSaved: onSaved,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('shows the three totals and saves in one step at 320 px', (tester) async {
      var saved = 0;
      final auth = await pump(tester, _collection(totals: _config), () => saved++);
      expect(find.text('1 500,5'), findsOneWidget);
      expect(find.text('700'), findsOneWidget);
      expect(find.text('250 000'), findsOneWidget);
      expect(auth.analysed.map((item) => item['operation']).toSet(), {'SUM'});

      await tester.enterText(find.byType(TextField).first, '12 500,50');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final values = (auth.saved!['values'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(auth.saved!['formatId'], 'f');
      expect(values.firstWhere((item) => item['fieldId'] == 'a')['value'], '12500.50');
      expect(values.firstWhere((item) => item['fieldId'] == 'd')['value'], isoDay(DateTime.now()));
      expect(saved, 1);
      expect(find.text('Enregistré : 12 500,50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('refuses a value that is not an amount', (tester) async {
      var saved = 0;
      final auth = await pump(tester, _collection(totals: _config), () => saved++);
      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Saisissez un montant, par exemple 12500.'), findsOneWidget);
      expect(auth.saved, isNull);
      expect(saved, 0);
    });

    testWidgets('stays empty for a collection without the configuration', (tester) async {
      final auth = await pump(tester, _collection(), () {});
      expect(find.text('Ce mois-ci'), findsNothing);
      expect(auth.analysed, isEmpty);
    });
  });
}
