import 'package:brainy/book_format_roles.dart';
import 'package:brainy/collections_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// T47/3: the owner places any data format in the book.
void main() {
  testWidgets('front matter keeps its role; other data formats can be placed or hidden', (tester) async {
    final calls = <(String, String?)>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BookFormatRoles(
      formats: const [
        BrainyFormat(id: 'cover', name: 'Couverture', color: '#EEF5FF', fields: []),
        BrainyFormat(id: 'chapter', name: 'Chapitre', color: '#EDF9F3', fields: []),
        BrainyFormat(id: 'note', name: 'Note', color: '#FFF5EB', fields: []),
      ],
      roles: const {'cover': 'COVER', 'chapter': 'CHAPTER'},
      french: true,
      busyFormatId: '',
      onChanged: (formatId, role) => calls.add((formatId, role)),
    )))));
    await tester.tap(find.text('Formats de données dans le livre'));
    await tester.pumpAndSettle();
    expect(find.text('Couverture'), findsNothing, reason: 'front matter is not offered');
    expect(find.text('Chapitre'), findsWidgets);
    await tester.tap(find.text('Non affiché'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Section').last);
    await tester.pumpAndSettle();
    expect(calls, [('note', 'SECTION')]);
  });
}
