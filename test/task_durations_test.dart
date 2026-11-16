import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/duration.dart';
import 'package:brainy/task_agenda_view.dart';
import 'package:brainy/task_durations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Durations: typed in the field unit or with words, stored as exact seconds; planned and spent time in task views.
const _format = BrainyFormat(id: 'task', name: 'Tâche', color: '#FFF5EB', fields: [
  BrainyField(id: 'title', name: 'Titre', kind: BrainyFieldKind.title),
  BrainyField(id: 'done', name: 'Terminée', kind: BrainyFieldKind.boolean),
  BrainyField(id: 'start', name: 'Début', kind: BrainyFieldKind.date),
  BrainyField(id: 'end', name: 'Fin ou échéance', kind: BrainyFieldKind.date),
  BrainyField(id: 'repeat', name: 'Répétition', kind: BrainyFieldKind.select, options: ['Une seule fois', 'Chaque jour']),
  BrainyField(id: 'estimate', name: 'Durée estimée', kind: BrainyFieldKind.duration, unit: 'min'),
  BrainyField(id: 'spent', name: 'Temps passé', kind: BrainyFieldKind.duration, unit: 'min'),
]);
const _planner = {'formatId': 'task', 'doneFieldId': 'done', 'startFieldId': 'start', 'endFieldId': 'end', 'repeatFieldId': 'repeat', 'intervalFieldId': 'n', 'weekdaysFieldId': 'w'};
const _collection = BrainyCollection(id: 'c', name: 'Maison', fields: [], formats: [_format], templateId: 'tasks', taskPlanner: {..._planner, 'estimateFieldId': 'estimate', 'spentFieldId': 'spent'});
const _older = BrainyCollection(id: 'c', name: 'Maison', fields: [], formats: [_format], templateId: 'tasks', taskPlanner: _planner);

Map<String, dynamic> _entry(String id, Map<String, String> values) => {'id': id, 'formatId': 'task', 'createdAt': '2026-11-01T08:00:00Z', 'updatedAt': '2026-11-01T08:00:00Z', 'values': [for (final item in values.entries) {'fieldId': item.key, 'value': item.value}]};

class _Auth extends AuthApi {
  final added = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    if (query.contains('addTaskDurationFields')) {
      added.add(variables);
      return {'addTaskDurationFields': {'id': 'c'}};
    }
    return {
      'taskAgenda': {
        'occurrences': [
          {'entryId': 'report', 'date': '2026-11-11', 'done': false, 'overdue': false, 'repeating': false},
          {'entryId': 'review', 'date': '2026-11-11', 'done': true, 'overdue': false, 'repeating': false},
        ],
        'entries': [
          _entry('report', {'title': 'Rapport', 'end': '2026-11-11', 'estimate': '2h', 'spent': '1h 30min'}),
          _entry('review', {'title': 'Relecture', 'end': '2026-11-11', 'estimate': '45min', 'spent': '1h'}),
        ],
      },
    };
  }
}

Future<void> _pump(WidgetTester tester, Widget child, {required double width, required bool dark}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: dark ? BrainyTheme.dark : BrainyTheme.light, home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child))));
  await tester.pumpAndSettle();
}

void main() {
  test('durations are typed in the field unit or with words, never in months', () {
    expect(parseDuration('45', 'min'), 2700);
    expect(parseDuration('2', 'h'), 7200);
    expect(parseDuration('1:30'), 5400);
    expect(parseDuration('2 h 30', 'min'), 9000);
    expect(parseDuration('1,5 h', 'min'), 5400);
    expect(parseDuration('1j 4h', 'min'), 100800);
    expect(parseDuration('2 sem', 'd'), 1209600);
    expect(parseDuration('90 s', 'min'), 90);
    expect(parseDuration('2', null), 7200, reason: 'without a unit a bare number is hours, as hours:minutes was');
    expect(parseDuration('2 mois', 'd'), isNull);
    expect(parseDuration('30 h 2 d', 'min'), isNull, reason: 'units go from the largest to the smallest');
    expect(formatDuration(100800, true), '1 j 4 h');
    expect(formatDuration(694800, false), '1 wk 1 d 1 h');
    expect(formatDuration(694800, false, short: true), '1 wk 1 d');
    expect(displayDuration('1h 30min', 'min', false), '1 h 30 min');
    expect(displayDuration('1:30', null, false), '1:30');
    expect(durationHelp('1 h 30', 'min', true), '= 1 h 30 min');
  });

  for (final (width, dark) in [(390.0, false), (1280.0, true)]) {
    for (final calendar in [false, true]) {
      testWidgets('${calendar ? 'calendar' : 'day'}: planned, left and spent time at $width px', (tester) async {
        await _pump(tester, TaskAgendaView(api: CollectionsApi(_Auth()), collection: _collection, calendar: calendar, french: true, today: '2026-11-11', onEdit: (_) async {}, onNewTask: () async {}, onCollectionChanged: () async {}), width: width, dark: dark);
        expect(find.textContaining('2 h 45 min prévues'), findsOneWidget);
        expect(find.textContaining('2 h restantes'), findsOneWidget);
        expect(find.textContaining('2 h 30 min passées'), findsOneWidget);
        expect(find.text('1 h 30 min passées sur 2 h'), findsOneWidget);
        expect(find.text('1 h passées sur 45 min'), findsOneWidget);
        expect(find.textContaining('Ajouter les durées'), findsNothing);
        if (calendar && width > 640) expect(find.text('2 h 45 min'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('an older task list offers to add the duration fields', (tester) async {
    final auth = _Auth();
    var reloaded = false;
    await _pump(tester, TaskAgendaView(api: CollectionsApi(auth), collection: _older, calendar: false, french: true, today: '2026-11-11', onEdit: (_) async {}, onNewTask: () async {}, onCollectionChanged: () async => reloaded = true), width: 390, dark: false);
    await tester.tap(find.text('Ajouter les durées'));
    await tester.pumpAndSettle();
    expect(auth.added.single, {'id': 'c', 'language': 'fr'});
    expect(reloaded, isTrue);
  });
}
