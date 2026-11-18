import 'package:brainy/collections_api.dart';
import 'package:brainy/format_choice_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formats = [
    for (var i = 1; i <= 9; i++)
      BrainyFormat(id: 'f$i', name: 'Format $i', color: '#E8F1FF', fields: [BrainyField(id: 'a$i', name: 'Title', kind: BrainyFieldKind.title)]),
  ];

  Future<String> pump(WidgetTester tester, String selected) async {
    var chosen = selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) => SingleChildScrollView(
          child: FormatChoiceCards(formats: formats, selectedId: chosen, label: 'Choose a data format', isFrench: false, tintOf: (_) => const Color(0xFFE8F1FF), nameOf: (format) => format.name, onChanged: (id) => setState(() => chosen = id)),
        )),
      ),
    ));
    return chosen;
  }

  testWidgets('more than 6 data formats: 6 cards, the chosen one among them, and a list of all', (tester) async {
    await pump(tester, 'f1');
    final cards = find.descendant(of: find.byType(Wrap), matching: find.byType(InkWell));
    expect(cards, findsNWidgets(6));
    expect(find.descendant(of: find.byType(Wrap), matching: find.text('Format 9')), findsNothing);
    expect(find.text('All data formats (9)'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Format 9').last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(Wrap), matching: find.text('Format 9')), findsOneWidget, reason: 'the chosen data format joins the cards');
    expect(find.descendant(of: find.byType(Wrap), matching: find.text('Format 6')), findsNothing);
    expect(cards, findsNWidgets(6));
  });
}
