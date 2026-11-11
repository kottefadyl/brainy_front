import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/auth_api.dart';
import 'package:brainy/app_strings.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/profile_photo.dart';
import 'package:brainy/profile_screen.dart';
import 'package:brainy/profile_suggest_field.dart';
import 'package:brainy/workspace_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image/image.dart' as img;

/// Native review of the profile photo and suggestion fields (no account, no network).
/// `flutter run -d windows -t tool/profile_preview.dart --dart-define=VISUAL_OUTPUT=folder`
void main() => runApp(const _Preview());

Future<String> _outputDir(String name) async {
  const requested = String.fromEnvironment('VISUAL_OUTPUT');
  final directory = Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/$name');
  await directory.create(recursive: true);
  return directory.path;
}

String _samplePhoto() {
  final image = img.Image(width: 240, height: 240);
  for (final pixel in image) {
    pixel
      ..r = 90 + pixel.x * 150 ~/ 240
      ..g = 120 + pixel.y * 100 ~/ 240
      ..b = 220;
  }
  return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(image))}';
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  double _width = 390;
  bool _dark = false;
  int _run = 0;
  bool _bars = false;

  @override
  void initState() {
    super.initState();
    profilePhotoNotifier.value = _samplePhoto();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  EditableText? _firstEditable<T extends Widget>() {
    EditableText? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget is EditableText) {
        found = element.widget as EditableText;
        return;
      }
      element.visitChildren(visit);
    }
    void findField(Element element) {
      if (found != null) return;
      if (element.widget is T) {
        element.visitChildren(visit);
        return;
      }
      element.visitChildren(findField);
    }
    (_boundary.currentContext! as Element).visitChildren(findField);
    return found;
  }

  Element? _lastTagsField() {
    Element? last;
    void visit(Element element) {
      if (element.widget is SuggestTagsField) {
        void inner(Element child) {
          if (child.widget is EditableText) last = child;
          child.visitChildren(inner);
        }
        element.visitChildren(inner);
        return;
      }
      element.visitChildren(visit);
    }
    (_boundary.currentContext! as Element).visitChildren(visit);
    return last;
  }

  Future<void> _shot(String output, String name) async {
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _capture() async {
    final output = await _outputDir('brainy-profile');
    for (final width in [390.0, 1100.0]) {
      for (final dark in [false, true]) {
        setState(() {
          _width = width;
          _dark = dark;
          _run++;
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _shot(output, 'profile-${width.toInt()}-${dark ? 'dark' : 'light'}');
        final field = _firstEditable<SuggestTextField>();
        field?.focusNode.requestFocus();
        field?.controller.text = 'dév';
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _shot(output, 'profile-${width.toInt()}-${dark ? 'dark' : 'light'}-suggest');
        FocusManager.instance.primaryFocus?.unfocus();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final hobbies = _lastTagsField();
        if (hobbies != null) {
          await Scrollable.ensureVisible(hobbies, alignment: 1);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          (hobbies.widget as EditableText).focusNode.requestFocus();
          await Future<void>.delayed(const Duration(milliseconds: 700));
          await _shot(output, 'profile-${width.toInt()}-${dark ? 'dark' : 'light'}-hobbies');
          FocusManager.instance.primaryFocus?.unfocus();
        }
      }
    }
    setState(() => _bars = true);
    for (final width in [320.0, 1100.0]) {
      for (final dark in [false, true]) {
        setState(() {
          _width = width;
          _dark = dark;
        });
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _shot(output, 'bars-${width.toInt()}-${dark ? 'dark' : 'light'}');
      }
    }
    debugPrint('PREVIEW_COMPLETE $output');
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
      final size = Size(_width, media.size.height);
      return Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _boundary,
          child: SizedBox.fromSize(size: size, child: MediaQuery(data: media.copyWith(size: size), child: child!)),
        ),
      );
    },
    home: _bars
        ? Scaffold(
            body: Column(children: [
              WorkspaceMobileBar(
                languageControl: const LanguageMenu(onDark: true),
                onCapture: () {},
                onOpenCollections: () {},
                account: ProfileAccountButton(name: 'Camille Durand', onPressed: () {}, showName: false),
              ),
              const SizedBox(height: 16),
              if (_width > 900)
                WorkspaceTopBar(
                  selectedName: 'Sport',
                  languageControl: const LanguageMenu(fullName: true),
                  onCapture: () {},
                  onRefresh: () async {},
                  account: ProfileAccountButton(name: 'Camille Durand', onPressed: () {}),
                ),
            ]),
          )
        : ProfileScreen(
      key: ValueKey(_run),
      user: const AppUser(
        id: 'u',
        name: 'Camille',
        email: 'camille@example.test',
        profession: 'Infirmier',
        interests: ['Astronomie', 'Énigmes médiévales'],
        hobbies: ['Randonnée'],
        profileCompleted: true,
        hasProfilePhoto: true,
      ),
      api: AuthApi(),
      onSaved: (_) {},
      onSignOut: () async {},
      onCancel: () {},
    ),
  );
}
