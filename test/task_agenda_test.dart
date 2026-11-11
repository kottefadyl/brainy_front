import 'package:brainy/auth_api.dart';
import 'package:brainy/boolean_field_input.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/task_agenda_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// T49: Day and Calendar task views, per-day checks and checkbox fields.
const _format = BrainyFormat(id: 'task', name: 'Tâche', color: '#FFF5EB', fields: [
  BrainyField(id: 'title', name: 'Titre', kind: BrainyFieldKind.title),
  BrainyField(id: 'done', name: 'Terminée', kind: BrainyFieldKind.boolean),
  BrainyField(id: 'start', name: 'Début', kind: BrainyFieldKind.date),
  BrainyField(id: 'end', name: 'Fin ou échéance', kind: BrainyFieldKind.date),
  BrainyField(id: 'repeat', name: 'Répétition', kind: BrainyFieldKind.select, options: ['Une seule fois', 'Chaque jour']),
]);
const _collection = BrainyCollection(id: 'c', name: 'Maison', fields: [], formats: [_format], templateId: 'tasks', taskPlanner: {'formatId': 'task', 'doneFieldId': 'done', 'startFieldId': 'start', 'endFieldId': 'end', 'repeatFieldId': 'repeat', 'intervalFieldId': 'n', 'weekdaysFieldId': 'w'});

Map<String, dynamic> _entry(String id, Map<String, String> values) => {'id': id, 'formatId': 'task', 'createdAt': '2026-11-01T08:00:00Z', 'updatedAt': '2026-11-01T08:00:00Z', 'values': [for (final item in values.entries) {'fieldId': item.key, 'value': item.value}]};

class _Auth extends AuthApi {
  final checks = <Map<String, dynamic>>[];
  final ranges = <String>[];
  @override
  Future<Map<String, dynamic>> authenticatedRequest(String query, Map<String, dynamic> variables, {Duration timeout = const Duration(seconds: 12)}) async {
    if (query.contains('setTaskDayDone')) {
      checks.add(variables);
      return {'setTaskDayDone': {'id': variables['entry']}};
    }
    ranges.add('${variables['from']}..${variables['to']}');
    final day = variables['from'] as String;
    final from = variables['from'] as String, to = variables['to'] as String;
    final occurrences = <Map<String, dynamic>>[];
    for (var date = from; date.compareTo(to) <= 0; date = addDays(date, 1)) {
      occurrences.add({'entryId': 'water', 'date': date, 'done': checks.any((item) => item['date'] == date && item['done'] == true), 'overdue': false, 'repeating': true});
      if (date == '2026-11-11') occurrences.add({'entryId': 'book', 'date': date, 'done': false, 'overdue': true, 'repeating': false});
    }
    return {'taskAgenda': {'occurrences': day.isEmpty ? [] : occurrences, 'entries': [_entry('water', {'title': 'Arroser les plantes', 'repeat': 'Chaque jour'}), _entry('book', {'title': 'Rendre le livre', 'end': '2026-11-09'})]}};
  }
}

void main() {
  test('the task form shows only the fields of the chosen Repeat', () {
    const planner = BrainyCollection(id: 'c', name: 'T', fields: [], formats: [_format], templateId: 'tasks', taskPlanner: {'formatId': 'task', 'doneFieldId': 'done', 'startFieldId': 'start', 'endFieldId': 'end', 'repeatFieldId': 'repeat', 'intervalFieldId': 'n', 'weekdaysFieldId': 'w', 'completedFieldId': 'at'});
    expect(hiddenTaskFieldIds(planner, 'task', {'repeat': 'Une seule fois'}), {'n', 'w'});
    expect(hiddenTaskFieldIds(planner, 'task', {}), {'n', 'w'});
    expect(hiddenTaskFieldIds(planner, 'task', {'repeat': 'Tous les N jours'}), {'w', 'done', 'at'});
    expect(hiddenTaskFieldIds(planner, 'task', {'repeat': 'Some weekdays'}), {'n', 'done', 'at'});
    expect(hiddenTaskFieldIds(planner, 'other', {'repeat': 'Chaque jour'}), isEmpty);
    expect(deviceZoneOrOffset(), isNotEmpty);
  });

  test('day helpers', () {
    expect(addDays('2026-12-31', 1), '2027-01-01');
    expect(weekStart('2026-11-11'), '2026-11-09');
    expect(addMonths('2026-01-31', 1), '2026-02-01');
    expect(dayTitle('2026-11-11', true), 'Mercredi 11 novembre 2026');
  });

  for (final (width, dark) in [(390.0, false), (390.0, true), (1280.0, false), (1280.0, true)]) {
    for (final calendar in [false, true]) {
      testWidgets('${calendar ? 'calendar' : 'day'} view at $width px (${dark ? 'dark' : 'light'})', (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth();
        await tester.pumpWidget(MaterialApp(theme: dark ? BrainyTheme.dark : BrainyTheme.light, home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: TaskAgendaView(api: CollectionsApi(auth), collection: _collection, calendar: calendar, french: true, today: '2026-11-11', onEdit: (_) async {}, onNewTask: () async {})))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(auth.ranges.first, calendar ? '2026-10-26..2026-12-06' : '2026-11-11..2026-11-11');
        expect(find.text('Arroser les plantes'), findsWidgets);
        expect(find.text('EN RETARD  1'), findsOneWidget);
        expect(find.text('Échéance 9 nov.'), findsOneWidget);
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Arroser les plantes'));
        await tester.pumpAndSettle();
        expect(auth.checks.single, containsPair('date', '2026-11-11'));
        expect(auth.checks.single, containsPair('done', true));
        expect(find.text('Faites : 1 sur 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a yes/no field is a checkbox that keeps an empty answer empty', (tester) async {
    var value = '';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, setState) => BooleanFieldInput(label: 'Terminée', value: value, french: true, onChanged: (next) => setState(() => value = next))))));
    expect(find.text('—'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(value, 'true');
    expect(find.text('Oui'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(value, 'false');
    expect(find.text('Non'), findsOneWidget);
  });
}
