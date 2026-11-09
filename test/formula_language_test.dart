import 'dart:convert';

import 'package:brainy/collections_api.dart';
import 'package:brainy/formula_completion.dart';
import 'package:brainy/formula_language.dart';
import 'package:flutter_test/flutter_test.dart';

BrainyCollection _collection() => BrainyCollection.fromJson({
  'id': 'c',
  'name': 'Shop',
  'fields': [],
  'formats': [
    {
      'id': 'sale',
      'name': 'Sale',
      'color': '#EEF5FF',
      'version': 1,
      'fields': [
        {'id': 'price', 'name': 'Prix', 'kind': 'NUMBER', 'unit': null},
        {'id': 'qty', 'name': 'Quantity', 'kind': 'NUMBER', 'unit': null},
        {'id': 'label', 'name': 'Label', 'kind': 'TEXT', 'unit': null},
        {'id': 'when', 'name': 'When', 'kind': 'DATE', 'unit': null},
        {'id': 'item', 'name': 'Item', 'kind': 'OBJECT_REF', 'unit': null, 'targetObjectFormatId': 'product', 'multiple': false},
      ],
    },
    {
      'id': 'product',
      'name': 'Product',
      'color': '#EDF9F3',
      'version': 1,
      'fields': [
        {'id': 'cost', 'name': 'Cost', 'kind': 'NUMBER', 'unit': null},
      ],
    },
  ],
});

void main() {
  late FormulaContext en, fr;
  setUp(() {
    final collection = _collection();
    en = FormulaContext(collection: collection, format: collection.formats.first, french: false);
    fr = FormulaContext(collection: collection, format: collection.formats.first, french: true);
  });

  test('builds the same expression as the web', () {
    expect(parseFormula('[Prix] * 0,8', fr), {
      'kind': 'operation',
      'operator': 'MULTIPLY',
      'args': [
        {'kind': 'field', 'fieldId': 'price'},
        {'kind': 'number', 'value': '0.8'},
      ],
    });
    expect(parseFormula('SI([Prix] > 10; 1; 0)', fr)['kind'], 'conditional');
    expect(parseFormula('[Item].[Cost]', en), {
      'kind': 'property',
      'referenceFieldId': 'item',
      'propertyFieldId': 'cost',
    });
    expect(parseFormula('-[Prix]', en)['operator'], 'MULTIPLY');
    expect(parseFormula('ROUND([Prix]; 2)', en)['digits'], 2);
  });

  test('accents and case never matter in function names', () {
    expect(parseFormula('année([When])', fr), parseFormula('ANNEE([When])', fr));
  });

  test('reports understandable errors in the interface language', () {
    expect(
      () => parseFormula('[Nope]', fr),
      throwsA(isA<FormulaSyntaxError>().having((e) => e.message, 'message', 'Champ introuvable : Nope')),
    );
    expect(
      () => parseFormula('[Prix', en),
      throwsA(isA<FormulaSyntaxError>().having((e) => e.message, 'message', 'The closing bracket ] is missing.')),
    );
    expect(
      () => parseFormula('SI([Prix])', fr),
      throwsA(isA<FormulaSyntaxError>().having((e) => e.message, 'message', 'SI attend 3 valeur(s), reçu 1.')),
    );
  });

  test('prints an expression back to text it can parse again', () {
    for (final text in ['([Prix] + 2) * [Quantity]', '[Prix] - ([Quantity] - 1)', 'IF([Prix] > 10 AND [Quantity] < 5; 1; 0)', '[Item].[Cost] / 2']) {
      final node = parseFormula(text, en);
      expect(printFormula(jsonEncode(node), en), text);
    }
    expect(printFormula('{"kind":"mystery"}', en), isNull);
    expect(printFormula('not json', en), isNull);
  });

  test('suggests fields, linked properties and functions at the caret', () {
    final fields = formulaCompletionsAt('[Pr', 3, fr)!;
    expect(fields.from, 0);
    expect(fields.items.single.insert, '[Prix]');
    final linked = formulaCompletionsAt('[Item].', 7, en)!;
    expect(linked.items.single.label, 'Cost');
    expect(formulaCompletionsAt('ARR', 3, fr)!.items.single.insert, 'ARRONDI(');
    expect(formulaCompletionsAt('"AR', 3, fr), isNull);
    expect(formulaFunctionAt('SI([Prix] > ', 12)?.id, 'if');
  });

  test('translates API errors for French users', () {
    final collection = en.collection;
    expect(formulaErrorMessage('Cannot divide by zero', collection, true), 'Division par zéro impossible.');
    expect(formulaErrorMessage('Expected a date but found text', collection, true), 'Une date est attendue, pas un texte.');
    expect(formulaErrorMessage('Cannot divide by zero', collection, false), 'Cannot divide by zero');
  });
}
