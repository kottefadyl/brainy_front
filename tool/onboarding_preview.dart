import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Native review of the T50 welcome guide (no account, no network).
/// `flutter run -d windows -t tool/onboarding_preview.dart --dart-define=VISUAL_OUTPUT=folder`
void main() => runApp(const _Preview());

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  double _width = 390;
  bool _dark = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    const requested = String.fromEnvironment('VISUAL_OUTPUT');
    final directory = Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/brainy-onboarding');
    await directory.create(recursive: true);
    for (final (width, dark) in [(390.0, false), (1280.0, true)]) {
      for (var page = 0; page < 5; page++) {
        setState(() { _width = width; _dark = dark; _page = page; });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await (await boundary.toImage()).toByteData(format: ui.ImageByteFormat.png);
        await File('${directory.path}/guide-${width.toInt()}-${dark ? 'dark' : 'light'}-${page + 1}.png').writeAsBytes(bytes!.buffer.asUint8List());
      }
    }
    debugPrint('PREVIEW_COMPLETE ${directory.path}');
    exit(0);
  }

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
          final size = Size(_width, _width < 500 ? 844 : media.size.height);
          return Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: _boundary, child: SizedBox.fromSize(size: size, child: MediaQuery(data: media.copyWith(size: size), child: child!))));
        },
        home: OnboardingScreen(key: ValueKey('$_page-$_width-$_dark'), initialPage: _page, user: const AppUser(id: 'u', name: 'Awa Diallo', email: 'a@example.test', profileCompleted: true), api: AuthApi(), onFinished: (_, {created = false, openTemplates = false}) {}),
      );
}
