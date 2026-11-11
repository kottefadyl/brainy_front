import 'dart:convert';

import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/link_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// T48: saved link previews.
const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

class _Auth extends AuthApi {
  int calls = 0;
  bool available = true;
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    calls++;
    final url = variables['url'] as String;
    return {
      'linkPreview': available
          ? {'url': url, 'available': true, 'title': 'This Is Why You’ll Never Achieve Your Goals', 'description': 'YOUCAN', 'siteName': 'YouTube', 'image': 'data:image/png;base64,$_png', 'video': true}
          : {'url': url, 'available': false, 'siteName': 'httpbin.org', 'video': false},
    };
  }
}

const _format = BrainyFormat(id: 'link', name: 'Lien', color: '#EDF9F3', fields: [
  BrainyField(id: 'title', name: 'Titre', kind: BrainyFieldKind.title),
  BrainyField(id: 'url', name: 'URL', kind: BrainyFieldKind.link),
]);
BrainyEntry _entry(String url) => BrainyEntry(id: 'e', values: {'title': 'Seth Godin', 'url': url}, createdAt: DateTime.utc(2026, 11, 11), updatedAt: DateTime.utc(2026, 11, 11), formatId: 'link');

void main() {
  test('only web addresses are previewed', () {
    expect(previewableUrl('https://youtube.com/shorts/fWB9blq0H34'), 'https://youtube.com/shorts/fWB9blq0H34');
    expect(previewableUrl(' http://example.com '), 'http://example.com');
    expect(previewableUrl('mailto:someone@example.com'), isNull);
    expect(previewableUrl('just some words'), isNull);
    expect(previewableUrl('ftp://example.com/file'), isNull);
    expect(previewableUrl(''), isNull);
    expect(linkHost('https://www.github.com/x'), 'github.com');
    final data = LinkPreviewData.fromJson({'url': 'u', 'available': true, 'image': 'data:image/png;base64,$_png', 'video': true});
    expect(data.image, base64Decode(_png));
  });

  test('previews appear only in Saved links collections', () {
    final api = CollectionsApi(_Auth());
    const links = BrainyCollection(id: 'c', name: 'Liens', fields: [], formats: [_format], templateId: 'links');
    const notes = BrainyCollection(id: 'n', name: 'Notes', fields: [], formats: [_format], templateId: 'notes');
    expect(linkPreviewFor(api, links, _format, _entry('https://example.com/a'), french: true), isA<LinkPreviewCard>());
    expect(linkPreviewFor(api, notes, _format, _entry('https://example.com/a'), french: true), isNull);
    expect(linkPreviewFor(api, links, _format, _entry('pas un lien'), french: true), isNull);
  });

  for (final (width, dark) in [(390.0, false), (390.0, true), (1280.0, false), (1280.0, true)]) {
    testWidgets('card shows image, title, description and site at $width px (${dark ? 'dark' : 'light'})', (tester) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _Auth();
      final api = CollectionsApi(auth);
      final url = 'https://youtube.com/shorts/test-$width-$dark';
      await tester.pumpWidget(MaterialApp(theme: dark ? BrainyTheme.dark : BrainyTheme.light, home: Scaffold(body: Column(children: [LinkPreviewCard(api: api, url: url, french: true), LinkPreviewCard(api: api, url: url, french: true)]))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('This Is Why You’ll Never Achieve Your Goals'), findsNWidgets(2));
      expect(find.text('YOUCAN'), findsNWidgets(2));
      expect(find.text('YouTube'), findsNWidgets(2));
      expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
      expect(auth.calls, 1, reason: 'one request per address');
    });
  }

  testWidgets('a site without preview shows its address only', (tester) async {
    final auth = _Auth()..available = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LinkPreviewCard(api: CollectionsApi(auth), url: 'https://httpbin.org/json', french: true))));
    await tester.pumpAndSettle();
    expect(find.text('httpbin.org'), findsOneWidget);
    expect(find.text('Aperçu indisponible pour ce site'), findsOneWidget);
  });
}
