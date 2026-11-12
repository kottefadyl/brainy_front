import 'dart:convert';

import 'package:brainy/auth_api.dart';
import 'package:brainy/brainy_theme.dart';
import 'package:brainy/collections_api.dart';
import 'package:brainy/person_field_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// T54: collaborator field (people chosen among the owner and the owner's collaborators).
class _PeopleApi extends CollectionsApi {
  _PeopleApi() : super(AuthApi());
  @override
  Future<List<BrainyPerson>> collectionPeople(String collectionId) async => [
        (userId: 'kevin', name: 'Kevin', hasPhoto: false),
        (userId: 'ivan', name: 'Ivan', hasPhoto: false),
        (userId: 'julien', name: 'Julien', hasPhoto: false),
      ];
}

const _field = BrainyField(id: 'by', name: 'Effectuée par', kind: BrainyFieldKind.collaborator);

BrainyEntry _entry() => BrainyEntry.fromJson({
      'id': 'e1',
      'formatId': 'f1',
      'createdAt': '2026-11-12T10:00:00Z',
      'updatedAt': '2026-11-12T10:00:00Z',
      'values': [
        {'fieldId': 'by', 'value': 'Ivan, Awa', 'personIds': ['ivan', 'awa'], 'personNames': ['Ivan', 'Awa']},
      ],
    });

Future<TextEditingController> _pump(WidgetTester tester, {String collectionId = 'c1', BrainyEntry? entry, bool dark = false}) async {
  final controller = TextEditingController(text: personFieldEditableValue(entry, _field));
  await tester.pumpWidget(MaterialApp(
    theme: dark ? BrainyTheme.dark : BrainyTheme.light,
    home: Scaffold(body: StatefulBuilder(builder: (context, setState) => PersonFieldInput(
          api: _PeopleApi(),
          collectionId: collectionId,
          field: _field,
          controller: controller,
          french: true,
          stored: entry?.people['by'] ?? const [],
          onChanged: () => setState(() {}),
        ))),
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  test('the wire name and the saved people are read from the API', () {
    expect(BrainyFieldKind.collaborator.wireName, 'COLLABORATOR');
    final entry = _entry();
    expect(entry.values['by'], 'Ivan, Awa');
    expect(entry.people['by']!.map((person) => person.name), ['Ivan', 'Awa']);
    expect(jsonDecode(personFieldEditableValue(entry, _field)), ['ivan', 'awa']);
    expect(personFieldEditableValue(null, _field), '');
  });

  testWidgets('owner first, several people chosen, choice removed', (tester) async {
    final controller = await _pump(tester);
    expect(find.text('Kevin · propriétaire'), findsOneWidget);
    await tester.tap(find.text('Ivan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Julien'));
    await tester.pumpAndSettle();
    expect(jsonDecode(controller.text), ['ivan', 'julien']);
    await tester.tap(find.text('Ivan'));
    await tester.pumpAndSettle();
    expect(jsonDecode(controller.text), ['julien']);
    await tester.tap(find.text('Julien'));
    await tester.pumpAndSettle();
    expect(controller.text, '', reason: 'an empty choice leaves the field out of the entry');
  });

  testWidgets('a person whose collaboration ended stays on the entry and can be removed (dark theme)', (tester) async {
    final controller = await _pump(tester, collectionId: 'c2', entry: _entry(), dark: true);
    expect(find.text('Awa'), findsOneWidget);
    await tester.tap(find.text('Awa'));
    await tester.pumpAndSettle();
    expect(jsonDecode(controller.text), ['ivan']);
    expect(find.text('Awa'), findsNothing, reason: 'a former collaborator cannot be chosen again');
  });
}
