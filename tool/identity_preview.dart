// Native-only review harness: fake data, real workspace, no account or API.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:brainy/auth_api.dart';
import 'package:brainy/app_theme_button.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/workspace_screen.dart';
import 'package:brainy/workspace_format_cards.dart';
import 'package:brainy/workspace_entry_row.dart';

class IdentityPreviewApi extends AuthApi {
  static final formats = [
    for (var i = 0; i < 3; i++)
      {
        'id': 'format-$i',
        'name': ['Entraînement', 'Lecture', 'Observations'][i],
        'color': ['#EEF5FF', '#EDF9F3', '#FFF5EB'][i],
        'fields': [
          {'id': 'title', 'name': 'Titre', 'kind': 'TITLE'},
          {'id': 'notes', 'name': 'Description', 'kind': 'TEXT'},
          {'id': 'time', 'name': 'Durée', 'kind': 'NUMBER', 'unit': 'min'},
          {'id': 'equipment', 'name': 'Équipement', 'kind': 'TEXT'},
          {'id': 'instructions', 'name': 'Instructions', 'kind': 'LONG_TEXT'},
        ],
      },
  ];
  @override
  Future<Map<String, dynamic>> authenticatedRequest(
    String query,
    Map<String, dynamic> variables, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (query.contains('collectionsList')) {
      return {
        'collectionsList': [
          for (var i = 0; i < 18; i++)
            {
              'id': 'collection-$i',
              'name': i == 0
                  ? 'Mes activités'
                  : 'Collection personnelle ${i + 1}',
              'fields': formats[0]['fields'],
              'formats': formats,
            },
        ],
      };
    }
    if (query.contains('collectionEntriesPage')) {
      return {
        'collectionEntriesPage': {
          'entries': [
            for (var i = 0; i < 3; i++)
              {
                'id': 'entry-$i',
                'formatId': 'format-$i',
                'createdAt': '2026-11-06T08:15:00Z',
                'updatedAt': i == 0
                    ? '2026-11-06T09:30:00Z'
                    : '2026-11-06T08:15:00Z',
                'values': [
                  {
                    'fieldId': 'title',
                    'value': [
                      'Une promenade au bord du lac',
                      'Quelques pages avant de dormir',
                      'Une idée à garder pour demain',
                    ][i],
                  },
                  {
                    'fieldId': 'notes',
                    'value': 'Les petits moments qui font du bien, à retrouver facilement.',
                  },
                ],
              },
          ],
          'hasMore': false,
          'nextCursor': null,
        },
      };
    }
    throw StateError('This visual fixture does not perform mutations');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IdentityPreview());
}

class IdentityPreview extends StatefulWidget {
  const IdentityPreview({super.key});
  @override
  State<IdentityPreview> createState() => _IdentityPreviewState();
}

class _IdentityPreviewState extends State<IdentityPreview> {
  final _boundary = GlobalKey();
  final _api = IdentityPreviewApi();
  bool _dark = false;
  double _width = 390;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Element? _find(bool Function(Widget) matches) {
    Element? found;
    void visit(Element element) {
      if (matches(element.widget)) {
        found ??= element;
        return;
      }
      element.visitChildElements(visit);
    }

    (_boundary.currentContext as Element?)?.visitChildElements(visit);
    return found;
  }

  Future<void> _capture() async {
    const requested = String.fromEnvironment('VISUAL_OUTPUT');
    final output = Directory(
      requested.isNotEmpty
          ? requested
          : '${Directory.systemTemp.path}/brainy-identity',
    );
    await output.create(recursive: true);
    await Future<void>.delayed(const Duration(seconds: 2));
    for (final width
        in Platform.isAndroid ? [390.0, 320.0] : [1280.0, 390.0, 320.0]) {
      for (final dark in [false, true]) {
        if (!mounted) return;
        setState(() {
          _width = width;
          _dark = dark;
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        for (final view in ['collection', 'entries', 'formats']) {
          final target = _find(
            (widget) => view != 'entries'
                ? widget is WorkspaceFormatCards
                : widget is WorkspaceEntryRow,
          );
          if (target != null) {
            if (view == 'collection') {
              Scrollable.of(target).position.jumpTo(0);
            } else {
              await Scrollable.ensureVisible(
                target,
                alignment: view == 'formats' ? 0 : .6,
                duration: const Duration(milliseconds: 150),
              );
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await WidgetsBinding.instance.endOfFrame;
          final boundary =
              _boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/$view-${dark ? 'dark' : 'light'}-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }
      }
    }
    debugPrint('IDENTITY_REVIEW_COMPLETE ${output.path}');
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    themeAnimationDuration: Duration.zero,
    theme: _dark ? BrainyTheme.dark : BrainyTheme.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _width,
              height: 900,
              child: RepaintBoundary(
                key: _boundary,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(_width, 900),
                    padding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                  ),
                  child: WorkspaceScreen(
                    user: const AppUser(
                      id: 'visual-fixture',
                      name: 'Compte de démonstration',
                      email: 'visual@example.test',
                      profileCompleted: true,
                    ),
                    api: _api,
                    onSignOut: () async {},
                    themeButton: AppThemeButton(
                      onPressed: () => setState(() => _dark = !_dark),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
