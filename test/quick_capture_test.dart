
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:brainy/auth_api.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/quick_capture_sheet.dart';
import 'package:brainy/quick_entry_sheet.dart';

class CaptureApi extends CollectionsApi {
  CaptureApi() : super(AuthApi());
  final existing = BrainyEntry(id: 'already', formatId: 'format', values: const {'link': 'https://example.org'}, createdAt: DateTime.utc(2026, 10, 1), updatedAt: DateTime.utc(2026, 10, 1));
  Map<String, String>? saved;
  @override
  Future<List<BrainyEntry>> duplicateLinks(String collectionId, String formatId, String fieldId, String url, {String? excludeEntryId}) async => [existing];
  @override
  Future<BrainyEntry> saveEntry(String collectionId, Map<String, String> values, {Map<String, Map<String, String>> measures = const {}, String? entryId, String? formatId, Map<String, Uint8List> attachments = const {}, Map<String, String> largeFiles = const {}, String? clientMutationId, DateTime? expectedUpdatedAt}) async {
    saved = values;
    return BrainyEntry(id: 'new', formatId: formatId, values: values, createdAt: DateTime.utc(2026, 10, 27), updatedAt: DateTime.utc(2026, 10, 27));
  }
}

class SaleApi extends CaptureApi {
  @override
  Future<BrainyEntryPage> entriesPage(String collectionId, {String? after, String? search, String? formatId, String? fieldId, String? operatorName, String? filterValue, String? viewId}) async => const BrainyEntryPage(entries: [], hasMore: false);
}

void main() {
  testWidgets('mobile capture warns before saving a duplicate link', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = CaptureApi();
    final collection = BrainyCollection(id: 'collection', name: 'Notes', fields: const [], formats: const [BrainyFormat(id: 'format', name: 'Capture', color: '#EEF5FF', fields: [BrainyField(id: 'title', name: 'Title', kind: BrainyFieldKind.title), BrainyField(id: 'link', name: 'Link', kind: BrainyFieldKind.link), BrainyField(id: 'note', name: 'Note', kind: BrainyFieldKind.longText)])]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => ElevatedButton(onPressed: () => showQuickCaptureSheet(context, api: api, collections: [collection], userId: 'test', french: false, incoming: const {'text': 'https://example.org'}), child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Remember this article');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('This link already exists.'), findsOneWidget);
    expect(api.saved, isNull);
    await tester.tap(find.text('Add anyway'));
    await tester.pumpAndSettle();
    expect(api.saved?['link'], 'https://example.org');
    expect(api.saved?['note'], 'Remember this article');
    expect(tester.takeException(), isNull);
  });

  testWidgets('configured quick sale saves with current date in two taps', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'brainy:quick-entry:test:sale': '{"values":{"qty":"2","amount":"3.50"},"hidden":["qty","amount"],"today":["date"]}'});
    final api = SaleApi();
    final collection = BrainyCollection(id: 'sales', name: 'Sales', fields: const [], formats: const [BrainyFormat(id: 'sale', name: 'Sale', color: '#FFF5EB', fields: [BrainyField(id: 'date', name: 'Date', kind: BrainyFieldKind.date), BrainyField(id: 'qty', name: 'Quantity', kind: BrainyFieldKind.number), BrainyField(id: 'amount', name: 'Amount', kind: BrainyFieldKind.number)])]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => ElevatedButton(onPressed: () => showQuickEntrySheet(context, api: api, collection: collection, userId: 'test', french: false), child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(api.saved?['qty'], '2');
    expect(api.saved?['amount'], '3.50');
    expect(api.saved?['date'], DateTime.now().toIso8601String().substring(0, 10));
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Android share bridge delivers pending link and preserves content on network error', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('brainy/quick_capture'),
      (call) async => call.method == 'takePending' ? <String, String>{'title': 'Field Guide', 'text': 'https://example.org/field-guide'} : null,
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('brainy/quick_capture'), null));
    final pending = await QuickCaptureBridge.takePending();
    expect(pending?['text'], 'https://example.org/field-guide');

    final failingApi = _FailingCaptureApi();
    final collection = BrainyCollection(id: 'collection', name: 'Notes', fields: const [], formats: const [BrainyFormat(id: 'format', name: 'Capture', color: '#EEF5FF', fields: [BrainyField(id: 'title', name: 'Title', kind: BrainyFieldKind.title), BrainyField(id: 'link', name: 'Link', kind: BrainyFieldKind.link), BrainyField(id: 'note', name: 'Note', kind: BrainyFieldKind.longText)])]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => ElevatedButton(onPressed: () => showQuickCaptureSheet(context, api: failingApi, collections: [collection], userId: 'test', french: false, incoming: pending), child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Keep on network failure');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your content is kept'), findsOneWidget);
    expect(find.text('https://example.org/field-guide'), findsOneWidget);
    expect(find.text('Keep on network failure'), findsOneWidget);
  });
}

class _FailingCaptureApi extends CaptureApi {
  @override
  Future<List<BrainyEntry>> duplicateLinks(String collectionId, String formatId, String fieldId, String url, {String? excludeEntryId}) async => const [];
  @override
  Future<BrainyEntry> saveEntry(String collectionId, Map<String, String> values, {Map<String, Map<String, String>> measures = const {}, String? entryId, String? formatId, Map<String, Uint8List> attachments = const {}, Map<String, String> largeFiles = const {}, String? clientMutationId, DateTime? expectedUpdatedAt}) async {
    throw StateError('Network unreachable');
  }
}

