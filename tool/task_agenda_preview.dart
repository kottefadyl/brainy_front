import 'dart:io';
import 'dart:ui' as ui;

import 'package:brainy/auth_api.dart';
import 'package:brainy/boolean_field_input.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/task_agenda_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Native review of T49 task views (no account, no network).
/// `flutter run -d windows -t tool/task_agenda_preview.dart --dart-define=VISUAL_OUTPUT=folder`
void main() => runApp(const _Preview());

const _format = BrainyFormat(id: 'task', name: 'Tâche', color: '#FFF5EB', fields: [BrainyField(id: 'title', name: 'Titre', kind: BrainyFieldKind.title)]);
const _collection = BrainyCollection(id: 'c', name: 'Maison', fields: [], formats: [_format], templateId: 'tasks', taskPlanner: {'formatId': 'task', 'doneFieldId': 'd', 'startFieldId': 'start', 'endFieldId': 'end', 'repeatFieldId': 'repeat', 'intervalFieldId': 'n', 'weekdaysFieldId': 'w'});
const _tasks = {'water': ('Arroser les plantes', 'Chaque jour', 1), 'bins': ('Sortir les poubelles', 'Certains jours de la semaine', 2), 'litter': ('Changer la litière', 'Tous les N jours', 3), 'rent': ('Payer le loyer', 'Chaque mois', 30)};

class _Auth extends AuthApi {
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    if (query.contains('setTaskDayDone')) return {'setTaskDayDone': {'id': 'x'}};
    final from = variables['from'] as String, to = variables['to'] as String;
    final occurrences = <Map<String, dynamic>>[];
    var index = 0;
    for (var date = from; date.compareTo(to) <= 0; date = addDays(date, 1), index++) {
      for (final task in _tasks.entries) {
        if (index % task.value.$3 == 0) occurrences.add({'entryId': task.key, 'date': date, 'done': date.compareTo('2026-11-11') < 0 && (index + task.key.length) % 3 != 0, 'overdue': false, 'repeating': true});
      }
      if (date.compareTo('2026-11-10') >= 0 && date.compareTo('2026-11-14') <= 0) occurrences.add({'entryId': 'paint', 'date': date, 'done': false, 'overdue': false, 'repeating': false});
      if (date == '2026-11-11') occurrences.add({'entryId': 'book', 'date': date, 'done': false, 'overdue': true, 'repeating': false});
    }
    Map<String, dynamic> entry(String id, Map<String, String> values) => {'id': id, 'formatId': 'task', 'createdAt': '2026-11-01T08:00:00Z', 'updatedAt': '2026-11-01T08:00:00Z', 'values': [for (final item in values.entries) {'fieldId': item.key, 'value': item.value}]};
    return {'taskAgenda': {'occurrences': occurrences, 'entries': [
      for (final task in _tasks.entries) entry(task.key, {'title': task.value.$1, 'repeat': task.value.$2}),
      entry('paint', {'title': 'Peindre la clôture', 'start': '2026-11-10', 'end': '2026-11-14'}),
      entry('book', {'title': 'Rendre le livre', 'end': '2026-11-09'}),
    ]}};
  }
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _boundary = GlobalKey();
  double _width = 390;
  bool _dark = false, _calendar = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    const requested = String.fromEnvironment('VISUAL_OUTPUT');
    final directory = Directory(requested.isNotEmpty ? requested : '${Directory.systemTemp.path}/brainy-tasks');
    await directory.create(recursive: true);
    for (final calendar in [false, true]) {
      for (final width in [390.0, 1280.0]) {
        for (final dark in [false, true]) {
          setState(() { _width = width; _dark = dark; _calendar = calendar; _run++; });
          await Future<void>.delayed(const Duration(milliseconds: 800));
          final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final bytes = await (await boundary.toImage()).toByteData(format: ui.ImageByteFormat.png);
          await File('${directory.path}/tasks-${calendar ? 'calendar' : 'day'}-${width.toInt()}-${dark ? 'dark' : 'light'}.png').writeAsBytes(bytes!.buffer.asUint8List());
        }
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
          final size = Size(_width, media.size.height);
          return Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: _boundary, child: SizedBox.fromSize(size: size, child: MediaQuery(data: media.copyWith(size: size), child: child!))));
        },
        home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_calendar) BooleanFieldInput(label: 'Terminée', value: 'true', french: true, onChanged: (_) {}),
          TaskAgendaView(key: ValueKey(_run), api: CollectionsApi(_Auth()), collection: _collection, calendar: _calendar, french: true, today: '2026-11-11', onEdit: (_) async {}, onNewTask: () async {}),
        ]))),
      );
}
