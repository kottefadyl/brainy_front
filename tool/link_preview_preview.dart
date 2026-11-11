import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/link_preview_card.dart';
import 'package:brainy/workspace_entry_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image/image.dart' as img;

/// Native review of T48 saved link previews (no account, no network).
/// `flutter run -d windows -t tool/link_preview_preview.dart --dart-define=VISUAL_OUTPUT=folder`
void main() => runApp(const _Preview());

String _image() {
  final image = img.Image(width: 320, height: 320);
  for (final pixel in image) {
    pixel
      ..r = 40 + pixel.x * 120 ~/ 320
      ..g = 30 + pixel.y * 60 ~/ 320
      ..b = 70;
  }
  return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(image))}';
}

class _Auth extends AuthApi {
  final image = _image();
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    final url = variables['url'] as String;
    if (url.contains('youtube')) return {'linkPreview': {'url': url, 'available': true, 'title': 'This Is Why You’ll Never Achieve Your Goals', 'description': 'YOUCAN', 'siteName': 'YouTube', 'image': image, 'video': true}};
    if (url.contains('example')) return {'linkPreview': {'url': url, 'available': true, 'title': 'Example Domain', 'siteName': 'example.com', 'video': false}};
    return {'linkPreview': {'url': url, 'available': false, 'siteName': 'httpbin.org', 'video': false}};
  }
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  final _api = CollectionsApi(_Auth());
  double _width = 390;
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    const requested = String.fromEnvironment('VISUAL_OUTPUT');
    final directory = Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/brainy-links');
    await directory.create(recursive: true);
    for (final width in [390.0, 1100.0]) {
      for (final dark in [false, true]) {
        setState(() { _width = width; _dark = dark; });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await (await boundary.toImage()).toByteData(format: ui.ImageByteFormat.png);
        await File('${directory.path}/links-${width.toInt()}-${dark ? 'dark' : 'light'}.png').writeAsBytes(bytes!.buffer.asUint8List());
      }
    }
    debugPrint('PREVIEW_COMPLETE ${directory.path}');
    exit(0);
  }

  Widget _row(String title, String url) => WorkspaceEntryRow(color: '#EDF9F3', title: title, formatName: 'Lien', created: '11 nov. 2026, 10:01', preview: url, onDetails: () {}, onAction: (_) {}, attachment: LinkPreviewCard(api: _api, url: url, french: true));

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BrainyTheme.light,
        darkTheme: BrainyTheme.dark,
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final size = Size(_width, media.size.height);
          return Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: _boundary, child: SizedBox.fromSize(size: size, child: MediaQuery(data: media.copyWith(size: size), child: child!))));
        },
        home: Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [
          _row('Seth Godin', 'https://youtube.com/shorts/fWB9blq0H34'),
          const SizedBox(height: 10),
          _row('Example', 'https://example.com/'),
          const SizedBox(height: 10),
          _row('Sans aperçu', 'https://httpbin.org/json'),
        ])),
      );
}
