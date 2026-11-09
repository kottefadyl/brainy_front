import 'dart:convert';

import 'collections_api.dart';
import 'number_units.dart';

/// Port of the web's formula language (`lib/formula-functions.ts` and
/// `lib/formula-language.ts`). Both clients must produce the same expressions.
typedef FormulaNode = Map<String, dynamic>;
typedef FormulaFail = Never Function(String fr, String en);
typedef FormulaBuild = FormulaNode Function(List<FormulaNode> args, FormulaFail fail);

enum FormulaFunctionCategory { logic, number, date, text, relation }

class FormulaFunction {
  const FormulaFunction(
    this.id,
    this.fr,
    this.en,
    this.category,
    this.min,
    this.max,
    this.paramsFr,
    this.paramsEn,
    this.helpFr,
    this.helpEn, {
    this.build,
    this.related,
  });
  final String id, fr, en, paramsFr, paramsEn, helpFr, helpEn;
  final FormulaFunctionCategory category;
  final int min, max;
  final FormulaBuild? build;

  /// Set for functions that take a path to linked objects rather than values.
  final String? related;

  String name(bool french) => french ? fr : en;
  String signature(bool french) =>
      '${name(french)}(${french ? paramsFr : paramsEn})';
  String help(bool french) => french ? helpFr : helpEn;
}

const _accents = {
  'A': 'ÀÁÂÃÄÅ',
  'C': 'Ç',
  'E': 'ÈÉÊË',
  'I': 'ÌÍÎÏ',
  'N': 'Ñ',
  'O': 'ÒÓÔÕÖ',
  'U': 'ÙÚÛÜ',
  'Y': 'ÝŸ',
};

final _unaccent = {
  for (final entry in _accents.entries)
    for (final char in entry.value.split('')) char: entry.key,
};

/// Case and accents never matter in function names: ANNÉE and annee match.
String foldFormulaName(String text) => text
    .toUpperCase()
    .split('')
    .map((char) => _unaccent[char] ?? char)
    .join();

const _textKinds = {
  'textField',
  'textLiteral',
  'textProperty',
  'unitOf',
  'coalesceText',
  'upper',
  'lower',
  'proper',
  'concat',
  'substring',
  'formatText',
};

FormulaNode _coalesceNode(List<FormulaNode> args) => {
  'kind': _textKinds.contains(args[0]['kind']) ? 'coalesceText' : 'coalesce',
  'args': args,
};

String _literal(FormulaNode node, FormulaFail fail, String fr, String en) {
  if (node['kind'] != 'textLiteral') fail(fr, en);
  return node['value'] as String;
}

FormulaBuild _one(String kind, String key) => (a, _) => {'kind': kind, key: a[0]};
FormulaBuild _many(String kind) => (a, _) => {'kind': kind, 'args': a};
FormulaBuild _diff(String unit) =>
    (a, _) => {'kind': 'dateDiff', 'unit': unit, 'end': a[0], 'start': a[1]};
FormulaBuild _part(String name) =>
    (a, _) => {'kind': 'datePart', 'part': name, 'date': a[0]};
FormulaBuild _durationIn(String unit) =>
    (a, _) => {'kind': 'durationIn', 'unit': unit, 'duration': a[0]};
FormulaBuild _logical(String operator) =>
    (a, _) => {'kind': 'logical', 'operator': operator, 'args': a};

const _many64 = 64;
const _logic = FormulaFunctionCategory.logic;
const _number = FormulaFunctionCategory.number;
const _date = FormulaFunctionCategory.date;
const _text = FormulaFunctionCategory.text;
const _relation = FormulaFunctionCategory.relation;

final List<FormulaFunction> formulaFunctions = [
  FormulaFunction("if", "SI", "IF", _logic, 3, 3, "condition; si_vrai; si_faux", "condition; if_true; if_false", "Donne une valeur ou une autre selon la condition.", "Gives one value or another depending on the condition.", build: (a, _) => {'kind': 'conditional', 'condition': a[0], 'then': a[1], 'else': a[2]}),
  FormulaFunction("and", "ET", "AND", _logic, 1, _many64, "condition1; condition2; …", "condition1; condition2; …", "Vrai si toutes les conditions sont vraies. S'écrit aussi a ET b.", "True when every condition is true. Also written a AND b.", build: _logical("AND")),
  FormulaFunction("or", "OU", "OR", _logic, 1, _many64, "condition1; condition2; …", "condition1; condition2; …", "Vrai si au moins une condition est vraie. S'écrit aussi a OU b.", "True when at least one condition is true. Also written a OR b.", build: _logical("OR")),
  FormulaFunction("not", "NON", "NOT", _logic, 1, 1, "condition", "condition", "Inverse une condition.", "Reverses a condition.", build: _one("not", "arg")),
  FormulaFunction("coalesce", "COALESCENCE", "COALESCE", _logic, 2, _many64, "valeur; repli; …", "value; fallback; …", "Donne la première valeur présente. S'écrit aussi a ?? b.", "Gives the first value that is present. Also written a ?? b.", build: (a, _) => _coalesceNode(a)),
  FormulaFunction("min", "MIN", "MIN", _number, 2, _many64, "a; b; …", "a; b; …", "La plus petite des valeurs.", "The smallest of the values.", build: _many("min")),
  FormulaFunction("max", "MAX", "MAX", _number, 2, _many64, "a; b; …", "a; b; …", "La plus grande des valeurs.", "The largest of the values.", build: _many("max")),
  FormulaFunction("abs", "ABS", "ABS", _number, 1, 1, "x", "x", "Valeur absolue.", "Absolute value.", build: _one("abs", "value")),
  FormulaFunction("floor", "PLANCHER", "FLOOR", _number, 1, 1, "x", "x", "Arrondit vers le bas à l'entier.", "Rounds down to a whole number.", build: _one("floor", "value")),
  FormulaFunction("ceil", "PLAFOND", "CEIL", _number, 1, 1, "x", "x", "Arrondit vers le haut à l'entier.", "Rounds up to a whole number.", build: _one("ceil", "value")),
  FormulaFunction("modulo", "MODULO", "MOD", _number, 2, 2, "a; b", "a; b", "Reste de la division de a par b.", "Remainder of a divided by b.", build: (a, _) => {'kind': 'modulo', 'left': a[0], 'right': a[1]}),
  FormulaFunction("round", "ARRONDI", "ROUND", _number, 2, 3, "x; décimales; \"HALF_EVEN\"", "x; decimals; \"HALF_EVEN\"", "Arrondit à 0–6 décimales. Option : arrondi au pair.", "Rounds to 0–6 decimals. Option: round half to even.", build: (a, fail) {
    if (a[1]['kind'] != 'number' || a[1]['unit'] != null) fail("Indiquez le nombre de décimales avec un nombre simple.", "Give the number of decimals as a plain number.");
    final mode = a.length > 2 ? _literal(a[2], fail, "Le mode d'arrondi s'écrit entre guillemets.", "Write the rounding mode in quotes.") : "HALF_UP";
    return {'kind': 'round', 'digits': num.parse(a[1]['value'] as String), 'mode': mode, 'value': a[0]};
  }),
  FormulaFunction("date", "DATE", "DATE", _date, 1, 1, "\"2026-03-01\"", "\"2026-03-01\"", "Une date fixe, au format année-mois-jour.", "A fixed date, written year-month-day.", build: (a, fail) => {'kind': 'dateLiteral', 'value': _literal(a[0], fail, "Écrivez la date entre guillemets : \"2026-03-01\".", "Write the date in quotes: \"2026-03-01\".")}),
  FormulaFunction("diffDays", "DIFF_JOURS", "DIFF_DAYS", _date, 2, 2, "fin; début", "end; start", "Nombre de jours entre deux dates.", "Number of days between two dates.", build: _diff("DAYS")),
  FormulaFunction("diffHours", "DIFF_HEURES", "DIFF_HOURS", _date, 2, 2, "fin; début", "end; start", "Nombre d'heures entre deux dates.", "Number of hours between two dates.", build: _diff("HOURS")),
  FormulaFunction("diffMonths", "DIFF_MOIS", "DIFF_MONTHS", _date, 2, 2, "fin; début", "end; start", "Nombre de mois complets entre deux dates.", "Number of complete months between two dates.", build: _diff("MONTHS")),
  FormulaFunction("addDays", "AJOUTER_JOURS", "ADD_DAYS", _date, 2, 2, "date; n", "date; n", "Décale une date de n jours, négatif pour reculer.", "Shifts a date by n days, negative to go back.", build: (a, _) => {'kind': 'addDays', 'date': a[0], 'days': a[1]}),
  FormulaFunction("startOfMonth", "DEBUT_MOIS", "START_OF_MONTH", _date, 1, 1, "date", "date", "Premier jour du mois.", "First day of the month.", build: _one("startOfMonth", "date")),
  FormulaFunction("endOfMonth", "FIN_MOIS", "END_OF_MONTH", _date, 1, 1, "date", "date", "Dernier jour du mois.", "Last day of the month.", build: _one("endOfMonth", "date")),
  FormulaFunction("year", "ANNEE", "YEAR", _date, 1, 1, "date", "date", "L'année d'une date.", "The year of a date.", build: _part("YEAR")),
  FormulaFunction("month", "MOIS", "MONTH", _date, 1, 1, "date", "date", "Le mois d'une date, de 1 à 12.", "The month of a date, from 1 to 12.", build: _part("MONTH")),
  FormulaFunction("day", "JOUR", "DAY", _date, 1, 1, "date", "date", "Le jour du mois.", "The day of the month.", build: _part("DAY")),
  FormulaFunction("weekday", "JOUR_SEMAINE", "WEEKDAY", _date, 1, 1, "date", "date", "Jour de la semaine : lundi = 1, dimanche = 7.", "Day of the week: Monday = 1, Sunday = 7.", build: _part("WEEKDAY")),
  FormulaFunction("inMinutes", "DUREE_EN_MINUTES", "DURATION_IN_MINUTES", _date, 1, 1, "durée", "duration", "Convertit une durée en minutes.", "Converts a duration to minutes.", build: _durationIn("MINUTES")),
  FormulaFunction("inHours", "DUREE_EN_HEURES", "DURATION_IN_HOURS", _date, 1, 1, "durée", "duration", "Convertit une durée en heures.", "Converts a duration to hours.", build: _durationIn("HOURS")),
  FormulaFunction("upper", "MAJUSCULE", "UPPER", _text, 1, 1, "texte", "text", "Met le texte en majuscules.", "Converts text to upper case.", build: _one("upper", "text")),
  FormulaFunction("lower", "MINUSCULE", "LOWER", _text, 1, 1, "texte", "text", "Met le texte en minuscules.", "Converts text to lower case.", build: _one("lower", "text")),
  FormulaFunction("proper", "PROPRE", "PROPER", _text, 1, 1, "texte", "text", "Met une majuscule au début de chaque mot.", "Capitalises the start of each word.", build: _one("proper", "text")),
  FormulaFunction("concat", "CONCATENER", "CONCAT", _text, 2, _many64, "texte1; texte2; …", "text1; text2; …", "Assemble plusieurs textes.", "Joins several texts.", build: _many("concat")),
  FormulaFunction("length", "LONGUEUR", "LEN", _text, 1, 1, "texte", "text", "Nombre de caractères.", "Number of characters.", build: _one("textLength", "text")),
  FormulaFunction("substring", "SOUS_CHAINE", "SUBSTRING", _text, 3, 3, "texte; début; longueur", "text; start; length", "Extrait une partie du texte, en comptant à partir de 1.", "Extracts part of a text, counting from 1.", build: (a, _) => {'kind': 'substring', 'text': a[0], 'start': a[1], 'length': a[2]}),
  FormulaFunction("format", "TEXTE", "TEXT", _text, 2, 3, "valeur; \"format\"; \"fr\"", "value; \"format\"; \"fr\"", "Écrit un nombre (\"0.00\", \"#,##0.00\") ou une date (\"DD/MM/YYYY\") en texte.", "Writes a number (\"0.00\", \"#,##0.00\") or a date (\"DD/MM/YYYY\") as text.", build: (a, fail) {
    final pattern = _literal(a[1], fail, "Écrivez le format entre guillemets.", "Write the format in quotes.");
    final locale = a.length > 2 ? _literal(a[2], fail, "Écrivez la langue entre guillemets : \"fr\" ou \"en\".", "Write the language in quotes: \"fr\" or \"en\".") : null;
    return {'kind': 'formatText', 'value': a[0], 'pattern': pattern, 'locale': ?locale};
  }),
  FormulaFunction("unit", "UNITE", "UNIT", _text, 1, 1, "valeur", "value", "L'unité d'une valeur, en texte.", "The unit of a value, as text.", build: _one("unitOf", "value")),
  const FormulaFunction("sumRelated", "SOMME_LIES", "SUM_RELATED", _relation, 1, 1, "[Liens].[Propriété]", "[Links].[Property]", "Somme d'une propriété des objets liés.", "Sum of a property of the linked objects.", related: "sumRelated"),
  const FormulaFunction("avgRelated", "MOYENNE_LIES", "AVG_RELATED", _relation, 1, 1, "[Liens].[Propriété]", "[Links].[Property]", "Moyenne d'une propriété des objets liés.", "Average of a property of the linked objects.", related: "avgRelated"),
  const FormulaFunction("minRelated", "MIN_LIES", "MIN_RELATED", _relation, 1, 1, "[Liens].[Propriété]", "[Links].[Property]", "Plus petite valeur parmi les objets liés.", "Smallest value among the linked objects.", related: "minRelated"),
  const FormulaFunction("maxRelated", "MAX_LIES", "MAX_RELATED", _relation, 1, 1, "[Liens].[Propriété]", "[Links].[Property]", "Plus grande valeur parmi les objets liés.", "Largest value among the linked objects.", related: "maxRelated"),
  const FormulaFunction("countRelated", "COMPTE_LIES", "COUNT_RELATED", _relation, 1, 1, "[Liens] ou [Liens].[Propriété]", "[Links] or [Links].[Property]", "Nombre d'objets liés, ou de ceux qui ont la propriété.", "Number of linked objects, or of those with the property.", related: "countRelated"),
];

final Map<String, FormulaFunction> _byName = {
  for (final item in formulaFunctions) ...{item.fr: item, item.en: item},
};

FormulaFunction? findFormulaFunction(String name) =>
    _byName[foldFormulaName(name)];
FormulaFunction _functionById(String id) =>
    formulaFunctions.firstWhere((item) => item.id == id);

class FormulaContext {
  const FormulaContext({
    required this.collection,
    required this.format,
    required this.french,
  });
  final BrainyCollection collection;
  final BrainyFormat format;
  final bool french;
}

class FormulaSyntaxError implements Exception {
  const FormulaSyntaxError(this.message);
  final String message;
}

const _textFieldKinds = {
  BrainyFieldKind.text,
  BrainyFieldKind.title,
  BrainyFieldKind.code,
  BrainyFieldKind.link,
};
const _orWords = ['OU', 'OR'];
const _andWords = ['ET', 'AND'];
const _comparisons = {
  '=': 'EQ',
  '==': 'EQ',
  '!=': 'NEQ',
  '<>': 'NEQ',
  '<': 'LT',
  '<=': 'LTE',
  '>': 'GT',
  '>=': 'GTE',
};
const _comparisonSymbols = {
  'EQ': '=',
  'NEQ': '!=',
  'LT': '<',
  'LTE': '<=',
  'GT': '>',
  'GTE': '>=',
};
const _operators = ['??', '<=', '>=', '!=', '<>', '==', '=', '<', '>', '+', '-', '*', '/', '(', ')', ';', ',', '.'];

enum _TokenType { number, string, ref, word, op }

class _Token {
  const _Token(this.type, this.value, {this.unit});
  final _TokenType type;
  final String value;
  final String? unit;
}

String? _unitId(String name, FormulaContext context) {
  for (final item in context.collection.units) {
    if (item.symbol == name || item.id == name) return item.id;
  }
  for (final item in numberUnits) {
    if (item.code == name || item.symbol == name) return item.code;
  }
  return const ['d', 'bpm', 'item'].contains(name) ? name : null;
}

final _numberPattern = RegExp(r'^\d+(?:[.,]\d+)?');
final _unitPattern = RegExp(
  r'^\s*(?:\{([^}]*)\}|([\p{L}°%€$£₦][\p{L}\p{N}°]*)(?!\s*\())',
  unicode: true,
);
final _wordPattern = RegExp(r'^[\p{L}_][\p{L}\p{N}_]*', unicode: true);
final _spacePattern = RegExp(r'\s');

List<_Token> _tokenize(String text, FormulaContext context) {
  final fr = context.french;
  final tokens = <_Token>[];
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (_spacePattern.hasMatch(char)) {
      index += 1;
      continue;
    }
    if (char == '"' || char == '[') {
      final close = char == '"' ? '"' : ']';
      final value = StringBuffer();
      index += 1;
      while (index < text.length && text[index] != close) {
        if (text[index] == r'\' && index + 1 < text.length) index += 1;
        value.write(text[index]);
        index += 1;
      }
      if (index >= text.length) {
        throw FormulaSyntaxError(
          char == '"'
              ? (fr ? 'Il manque le guillemet fermant.' : 'The closing quote is missing.')
              : (fr ? 'Il manque le crochet fermant ].' : 'The closing bracket ] is missing.'),
        );
      }
      index += 1;
      tokens.add(_Token(char == '"' ? _TokenType.string : _TokenType.ref, value.toString()));
      continue;
    }
    final number = _numberPattern.firstMatch(text.substring(index));
    if (number != null) {
      index += number[0]!.length;
      final value = number[0]!.replaceFirst(',', '.');
      final unit = _unitPattern.firstMatch(text.substring(index));
      final name = unit?[1] ?? unit?[2];
      final id = name == null ? null : _unitId(name, context);
      if (unit != null && id != null) {
        index += unit[0]!.length;
      } else if (unit?[1] != null) {
        throw FormulaSyntaxError(fr ? 'Unité inconnue : ${unit![1]}' : 'Unknown unit: ${unit![1]}');
      }
      tokens.add(_Token(_TokenType.number, value, unit: id));
      continue;
    }
    final word = _wordPattern.firstMatch(text.substring(index));
    if (word != null) {
      tokens.add(_Token(_TokenType.word, word[0]!));
      index += word[0]!.length;
      continue;
    }
    final at = index;
    final operator = _operators.where((item) => text.startsWith(item, at)).firstOrNull;
    if (operator == null) {
      throw FormulaSyntaxError(fr ? 'Caractère inattendu : $char' : 'Unexpected character: $char');
    }
    tokens.add(_Token(_TokenType.op, operator));
    index += operator.length;
  }
  return tokens;
}

bool _sameName(String a, String b) => a.toLowerCase() == b.toLowerCase();

BrainyFormat? _formatById(FormulaContext context, String? id) =>
    context.collection.formats.where((item) => item.id == id).firstOrNull;

class _Parser {
  _Parser(this.context, this.tokens);

  final FormulaContext context;
  final List<_Token> tokens;
  var index = 0;

  bool get fr => context.french;

  Never fail(String frMessage, String enMessage) =>
      throw FormulaSyntaxError(fr ? frMessage : enMessage);

  _Token? get peek => index < tokens.length ? tokens[index] : null;
  bool isOp(String value) => peek?.type == _TokenType.op && peek?.value == value;
  bool isWord(List<String> words) =>
      peek?.type == _TokenType.word && words.contains(foldFormulaName(peek!.value));
  bool eatOp(String value) {
    if (!isOp(value)) return false;
    index += 1;
    return true;
  }

  Never unexpected() {
    final token = peek;
    if (token != null) fail('Texte inattendu : ${token.value}', 'Unexpected text: ${token.value}');
    fail('La formule est incomplète.', 'The formula is incomplete.');
  }

  List<String> referenceSegments(String first) {
    final segments = [first];
    while (isOp('.')) {
      index += 1;
      if (peek?.type != _TokenType.ref) {
        fail('Choisissez une propriété entre crochets après le point.', 'Choose a property in brackets after the dot.');
      }
      segments.add(tokens[index].value);
      index += 1;
    }
    return segments;
  }

  FormulaNode fieldNode(List<String> segments) {
    if (segments[0].startsWith('=') && segments.length == 1) {
      final name = segments[0].substring(1).trim();
      for (final item in context.collection.formulas) {
        if (item['formatId'] == context.format.id && _sameName(item['name'] as String, name)) {
          return {'kind': 'formula', 'formulaId': item['id']};
        }
      }
      fail('Formule introuvable : $name', 'Formula not found: $name');
    }
    BrainyFormat? format = context.format;
    final steps = <BrainyField>[];
    for (final (position, name) in segments.indexed) {
      final field = format?.fields.where((item) => _sameName(item.name, name)).firstOrNull;
      if (field == null) fail('Champ introuvable : $name', 'Field not found: $name');
      steps.add(field);
      if (position == segments.length - 1) break;
      if (field.kind != BrainyFieldKind.objectRef) {
        fail('${field.name} n\'est pas une référence d\'objet.', '${field.name} is not an object reference.');
      }
      if (field.multiple) {
        fail('${field.name} lie plusieurs objets : utilisez SOMME_LIES ou une fonction voisine.', '${field.name} links several objects: use SUM_RELATED or a similar function.');
      }
      format = _formatById(context, field.targetObjectFormatId);
    }
    final last = steps.last;
    if (steps.length == 1) {
      if (last.kind == BrainyFieldKind.number) return {'kind': 'field', 'fieldId': last.id};
      if (last.kind == BrainyFieldKind.date || last.kind == BrainyFieldKind.datetime) {
        return {'kind': 'dateField', 'fieldId': last.id};
      }
      if (_textFieldKinds.contains(last.kind)) return {'kind': 'textField', 'fieldId': last.id};
      if (last.kind == BrainyFieldKind.duration) return {'kind': 'durationField', 'fieldId': last.id};
      if (last.kind == BrainyFieldKind.objectRef) {
        fail('Ajoutez un point après ${last.name} pour choisir une propriété.', 'Add a dot after ${last.name} to choose a property.');
      }
      fail('Le champ ${last.name} ne peut pas servir dans une formule.', 'The field ${last.name} cannot be used in a formula.');
    }
    final kind = last.kind == BrainyFieldKind.number
        ? 'property'
        : _textFieldKinds.contains(last.kind)
        ? 'textProperty'
        : null;
    if (kind == null) {
      fail('La propriété ${last.name} ne peut pas servir dans une formule.', 'The property ${last.name} cannot be used in a formula.');
    }
    final through = steps.sublist(1, steps.length - 1).map((item) => item.id).toList();
    return {
      'kind': kind,
      'referenceFieldId': steps[0].id,
      if (through.isNotEmpty) 'through': through,
      'propertyFieldId': last.id,
    };
  }

  FormulaNode relatedNode(String kind, List<String> segments) {
    final reference = context.format.fields.where((item) => _sameName(item.name, segments[0])).firstOrNull;
    if (reference?.kind != BrainyFieldKind.objectRef) {
      fail('Choisissez un champ de référence d\'objet.', 'Choose an object reference field.');
    }
    final target = _formatById(context, reference!.targetObjectFormatId);
    if (segments.length > 2) {
      fail('Choisissez une seule propriété des objets liés.', 'Choose a single property of the linked objects.');
    }
    if (segments.length == 1) {
      if (kind == 'countRelated') return {'kind': kind, 'referenceFieldId': reference.id};
      fail('Ajoutez la propriété à utiliser : [${reference.name}].[…]', 'Add the property to use: [${reference.name}].[…]');
    }
    final property = target?.fields.where((item) => _sameName(item.name, segments[1])).firstOrNull;
    if (property == null) fail('Propriété introuvable : ${segments[1]}', 'Property not found: ${segments[1]}');
    return {'kind': kind, 'referenceFieldId': reference.id, 'propertyFieldId': property.id};
  }

  FormulaNode parseCall(String name) {
    final definition = findFormulaFunction(name);
    if (definition == null) fail('Fonction inconnue : $name', 'Unknown function: $name');
    final label = definition.name(fr);
    eatOp('(');
    if (definition.related != null) {
      if (peek?.type != _TokenType.ref) {
        fail('$label attend un champ de référence entre crochets.', '$label needs a reference field in brackets.');
      }
      final first = tokens[index].value;
      index += 1;
      final node = relatedNode(definition.related!, referenceSegments(first));
      if (!eatOp(')')) unexpected();
      return node;
    }
    final args = <FormulaNode>[];
    if (!isOp(')')) {
      do {
        args.add(parseOr());
      } while (eatOp(';') || eatOp(','));
    }
    if (!eatOp(')')) unexpected();
    if (args.length < definition.min || args.length > definition.max) {
      final expected = definition.min == definition.max
          ? '${definition.min}'
          : definition.max > 32
          ? (fr ? 'au moins ${definition.min}' : 'at least ${definition.min}')
          : '${definition.min}–${definition.max}';
      fail('$label attend $expected valeur(s), reçu ${args.length}.', '$label takes $expected value(s), got ${args.length}.');
    }
    return definition.build!(args, fail);
  }

  FormulaNode parsePrimary() {
    final token = peek;
    if (token == null) unexpected();
    if (eatOp('(')) {
      final inner = parseOr();
      if (!eatOp(')')) unexpected();
      return inner;
    }
    switch (token.type) {
      case _TokenType.number:
        index += 1;
        return {'kind': 'number', 'value': token.value, 'unit': ?token.unit};
      case _TokenType.string:
        index += 1;
        return {'kind': 'textLiteral', 'value': token.value};
      case _TokenType.ref:
        index += 1;
        return fieldNode(referenceSegments(token.value));
      case _TokenType.word:
        index += 1;
        if (isOp('(')) return parseCall(token.value);
        final word = foldFormulaName(token.value);
        if (word == 'VRAI' || word == 'TRUE') return {'kind': 'boolean', 'value': true};
        if (word == 'FAUX' || word == 'FALSE') return {'kind': 'boolean', 'value': false};
        fail('Mot inconnu : ${token.value}. Mettez les noms de champs entre crochets : [${token.value}]', 'Unknown word: ${token.value}. Put field names in brackets: [${token.value}]');
      case _TokenType.op:
        unexpected();
    }
  }

  FormulaNode parseUnary() {
    if (!eatOp('-')) return parsePrimary();
    final operand = parseUnary();
    if (operand['kind'] == 'number' && !'${operand['value']}'.startsWith('-')) {
      return {...operand, 'value': '-${operand['value']}'};
    }
    return {
      'kind': 'operation',
      'operator': 'MULTIPLY',
      'args': [
        operand,
        {'kind': 'number', 'value': '-1'},
      ],
    };
  }

  FormulaNode binaryLevel(FormulaNode Function() next, Map<String, String> operators) {
    var left = next();
    for (;;) {
      final token = peek;
      if (token?.type != _TokenType.op || !operators.containsKey(token!.value)) return left;
      index += 1;
      left = {
        'kind': 'operation',
        'operator': operators[token.value],
        'args': [left, next()],
      };
    }
  }

  FormulaNode parseMultiplicative() => binaryLevel(parseUnary, const {'*': 'MULTIPLY', '/': 'DIVIDE'});
  FormulaNode parseAdditive() => binaryLevel(parseMultiplicative, const {'+': 'ADD', '-': 'SUBTRACT'});

  FormulaNode parseCoalesce() {
    final args = [parseAdditive()];
    while (eatOp('??')) {
      args.add(parseAdditive());
    }
    return args.length == 1 ? args[0] : _coalesceNode(args);
  }

  FormulaNode parseComparison() {
    final left = parseCoalesce();
    final token = peek;
    if (token?.type != _TokenType.op || !_comparisons.containsKey(token!.value)) return left;
    index += 1;
    return {'kind': 'comparison', 'operator': _comparisons[token.value], 'left': left, 'right': parseCoalesce()};
  }

  FormulaNode logicalLevel(FormulaNode Function() next, List<String> words, String operator) {
    final args = [next()];
    while (isWord(words)) {
      index += 1;
      args.add(next());
    }
    return args.length == 1 ? args[0] : {'kind': 'logical', 'operator': operator, 'args': args};
  }

  FormulaNode parseAnd() => logicalLevel(parseComparison, _andWords, 'AND');
  FormulaNode parseOr() => logicalLevel(parseAnd, _orWords, 'OR');
}

/// Turns the text of a formula into the expression stored by the API.
/// Types and units are left to the API.
FormulaNode parseFormula(String text, FormulaContext context) {
  final tokens = _tokenize(text, context);
  final parser = _Parser(context, tokens);
  if (tokens.isEmpty) parser.fail('Écrivez une formule.', 'Write a formula.');
  final result = parser.parseOr();
  if (parser.peek != null) parser.unexpected();
  return result;
}

String formulaEscapeName(String name) =>
    name.replaceAllMapped(RegExp(r'[\\\]]'), (m) => '\\${m[0]}');
String _escapeText(String text) =>
    text.replaceAllMapped(RegExp(r'[\\"]'), (m) => '\\${m[0]}');

class _Unprintable implements Exception {}

const _levelOr = 1, _levelAnd = 2, _levelComparison = 3, _levelAdditive = 5, _levelMultiplicative = 6;

final _bareUnit = RegExp(r'^[\p{L}°%€$£₦][\p{L}\p{N}°]*$', unicode: true);

class _Printer {
  _Printer(this.context);

  final FormulaContext context;

  String name(String id) => _functionById(id).name(context.french);
  String call(String id, List<String> parts) => '${name(id)}(${parts.join('; ')})';

  BrainyField fieldOf(BrainyFormat? format, Object? id) {
    final field = format?.fields.where((item) => item.id == id).firstOrNull;
    if (field == null) throw _Unprintable();
    return field;
  }

  String ref(BrainyField field) => '[${formulaEscapeName(field.name)}]';
  BrainyFormat? targetOf(BrainyField field) => _formatById(context, field.targetObjectFormatId);

  String relatedPath(FormulaNode node) {
    final reference = fieldOf(context.format, node['referenceFieldId']);
    return node['propertyFieldId'] == null
        ? ref(reference)
        : '${ref(reference)}.${ref(fieldOf(targetOf(reference), node['propertyFieldId']))}';
  }

  String path(FormulaNode node) {
    BrainyFormat? format = context.format;
    final parts = <String>[];
    for (final id in [node['referenceFieldId'], ...(node['through'] as List<dynamic>? ?? const [])]) {
      final field = fieldOf(format, id);
      format = targetOf(field);
      parts.add(ref(field));
    }
    return [...parts, ref(fieldOf(format, node['propertyFieldId']))].join('.');
  }

  String unitText(String unit) {
    final symbol = context.collection.units.where((item) => item.id == unit).firstOrNull?.symbol ?? unit;
    return _bareUnit.hasMatch(symbol) ? symbol : '{$symbol}';
  }

  FormulaNode _node(Object? value) => (value as Map).cast<String, dynamic>();
  String value(Object? node) => write(_node(node), 0);
  List<String> values(Object? nodes) => (nodes as List<dynamic>).map(value).toList();
  String grouped(String text, int level, int context) => level < context ? '($text)' : text;

  String write(FormulaNode node, int level) {
    final french = context.french;
    switch (node['kind']) {
      case 'number':
        return '${node['value']}${node['unit'] != null ? ' ${unitText(node['unit'] as String)}' : ''}';
      case 'boolean':
        return node['value'] == true ? (french ? 'VRAI' : 'TRUE') : (french ? 'FAUX' : 'FALSE');
      case 'textLiteral':
        return '"${_escapeText(node['value'] as String)}"';
      case 'dateLiteral':
        return call('date', ['"${node['value']}"']);
      case 'field' || 'dateField' || 'textField' || 'durationField':
        return ref(fieldOf(context.format, node['fieldId']));
      case 'property' || 'textProperty':
        return path(node);
      case 'formula':
        final formula = context.collection.formulas.where((item) => item['id'] == node['formulaId']).firstOrNull;
        if (formula == null) throw _Unprintable();
        return '[=${formulaEscapeName(formula['name'] as String)}]';
      case 'operation':
        final args = node['args'] as List<dynamic>;
        final operator = node['operator'] as String;
        final own = operator == 'ADD' || operator == 'SUBTRACT' ? _levelAdditive : _levelMultiplicative;
        final symbol = const {'ADD': '+', 'SUBTRACT': '-', 'MULTIPLY': '*', 'DIVIDE': '/'}[operator];
        if (symbol == null) throw _Unprintable();
        return grouped('${write(_node(args[0]), own)} $symbol ${write(_node(args[1]), own + 1)}', own, level);
      case 'comparison':
        return grouped('${write(_node(node['left']), _levelComparison + 1)} ${_comparisonSymbols[node['operator']]} ${write(_node(node['right']), _levelComparison + 1)}', _levelComparison, level);
      case 'logical':
        final args = node['args'] as List<dynamic>;
        final isAnd = node['operator'] == 'AND';
        if (args.length < 2) return call(isAnd ? 'and' : 'or', values(args));
        final own = isAnd ? _levelAnd : _levelOr;
        return grouped(args.map((item) => write(_node(item), own + 1)).join(' ${name(isAnd ? 'and' : 'or')} '), own, level);
      case 'not':
        return call('not', [value(node['arg'])]);
      case 'conditional':
        return call('if', [value(node['condition']), value(node['then']), value(node['else'])]);
      case 'min' || 'max':
        return call(node['kind'] as String, values(node['args']));
      case 'coalesce' || 'coalesceText':
        return call('coalesce', values(node['args']));
      case 'abs' || 'floor' || 'ceil':
        return call(node['kind'] as String, [value(node['value'])]);
      case 'modulo':
        return call('modulo', [value(node['left']), value(node['right'])]);
      case 'round':
        return call('round', [value(node['value']), '${node['digits']}', if (node['mode'] == 'HALF_EVEN') '"HALF_EVEN"']);
      case 'dateDifference':
        return call(node['unit'] == 'h' ? 'diffHours' : 'diffDays', [ref(fieldOf(context.format, node['toFieldId'])), ref(fieldOf(context.format, node['fromFieldId']))]);
      case 'dateDiff':
        final id = const {'DAYS': 'diffDays', 'HOURS': 'diffHours', 'MONTHS': 'diffMonths'}[node['unit']];
        if (id == null) throw _Unprintable();
        return call(id, [value(node['end']), value(node['start'])]);
      case 'datePart':
        final id = const {'YEAR': 'year', 'MONTH': 'month', 'DAY': 'day', 'WEEKDAY': 'weekday'}[node['part']];
        if (id == null) throw _Unprintable();
        return call(id, [value(node['date'])]);
      case 'addDays':
        return call('addDays', [value(node['date']), value(node['days'])]);
      case 'startOfMonth' || 'endOfMonth':
        return call(node['kind'] as String, [value(node['date'])]);
      case 'durationIn':
        return call(node['unit'] == 'HOURS' ? 'inHours' : 'inMinutes', [value(node['duration'])]);
      case 'upper' || 'lower' || 'proper':
        return call(node['kind'] as String, [value(node['text'])]);
      case 'concat':
        return call('concat', values(node['args']));
      case 'textLength':
        return call('length', [value(node['text'])]);
      case 'substring':
        return call('substring', [value(node['text']), value(node['start']), value(node['length'])]);
      case 'formatText':
        return call('format', [value(node['value']), '"${_escapeText(node['pattern'] as String)}"', if (node['locale'] != null) '"${node['locale']}"']);
      case 'unitOf':
        return call('unit', [value(node['value'])]);
      case 'sumRelated' || 'avgRelated' || 'minRelated' || 'maxRelated' || 'countRelated':
        return call(node['kind'] as String, [relatedPath(node)]);
      default:
        throw _Unprintable();
    }
  }
}

/// Rewrites a stored expression as text, or null when it cannot be shown
/// without losing part of it.
String? printFormula(String expression, FormulaContext context) {
  try {
    final decoded = jsonDecode(expression);
    if (decoded is! Map) return null;
    final stored = decoded.cast<String, dynamic>();
    final printer = _Printer(context);
    // Older web formulas kept rounding in a `round` key beside a date difference.
    final round = stored['round'];
    if (stored['kind'] == 'dateDifference' && round is Map) {
      return printer.call('round', [printer.write(stored, 0), '${round['digits']}', if (round['mode'] == 'HALF_EVEN') '"HALF_EVEN"']);
    }
    return printer.write(stored, 0);
  } on _Unprintable {
    return null;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

/// The API answers in English; the editor speaks the interface's language.
const _fixedErrors = {
  'Formula is too complex': 'La formule est trop complexe.',
  'Formula is too deep': 'La formule est trop imbriquée.',
  'Formula is too long': 'La formule est trop longue.',
  'Invalid formula expression': "Cette formule n'est pas valide.",
  'Unknown formula operation': "Cette opération n'est pas reconnue.",
  'Unknown date operation': "Cette opération de date n'est pas reconnue.",
  'Unknown text operation': "Cette opération de texte n'est pas reconnue.",
  'Invalid formula condition': "Cette condition n'est pas valide.",
  'Cannot divide by zero': 'Division par zéro impossible.',
  'Convert currencies with an explicit dated rate first': "Convertissez d'abord les devises avec un taux daté.",
  'Convert temperatures before adding them': 'Convertissez les températures avant de les additionner.',
  'Convert temperatures before comparing them': 'Convertissez les températures avant de les comparer.',
  'This formula gives a date, not a number': 'Cette valeur est une date, un nombre est attendu.',
  'This formula gives text, not a number': 'Cette valeur est un texte, un nombre est attendu.',
  'Choose one numeric property from a single object reference': "Choisissez une propriété numérique d'une référence à un seul objet.",
  'Choose a numeric property from an object reference': "Choisissez une propriété numérique d'une référence d'objet.",
  'This property does not exist on the linked object': "Cette propriété n'existe pas sur l'objet lié.",
  'A snapshot reference cannot be followed further': 'Une référence figée ne peut pas être suivie plus loin.',
  'Follow at most five linked objects': 'Suivez au plus cinq objets liés.',
  'Choose a duration': 'Choisissez une durée.',
  'Give the number of days as a plain number or a duration': 'Indiquez le nombre de jours avec un nombre simple ou une durée.',
  'Use a whole number of days': 'Utilisez un nombre entier de jours.',
  'Use whole numbers for the start (from 1) and the length (from 0)': 'Utilisez des nombres entiers pour le début (à partir de 1) et la longueur (à partir de 0).',
  'Use a valid date': 'Utilisez une date valide.',
  'Use a date format such as DD/MM/YYYY': 'Utilisez un format de date comme DD/MM/YYYY.',
  'Use a number format such as 0.00 or #,##0.00': 'Utilisez un format de nombre comme 0.00 ou #,##0.00.',
  'Choose English or French formatting': 'Choisissez la mise en forme "fr" ou "en".',
  'Choose 0 to 6 decimal places and a rounding rule': "Choisissez de 0 à 6 décimales et une règle d'arrondi.",
  'Conditions cannot be compared': 'Des conditions ne peuvent pas être comparées.',
  'Text can only be tested for equal or different': 'Un texte peut seulement être testé égal ou différent.',
  'Formula names must be unique in a data format': 'Ce nom de formule existe déjà dans ce format de données.',
  'Formula name must be 1 to 80 characters': 'Le nom de la formule doit compter de 1 à 80 caractères.',
  'Formula changed. Refresh and try again': 'Cette formule a changé. Actualisez puis réessayez.',
  'This collection has 100 formulas': 'Cette collection a atteint 100 formules.',
  'Another formula uses this formula': 'Une autre formule utilise celle-ci.',
};

const _nouns = {'a number': 'un nombre', 'text': 'un texte', 'a date': 'une date', 'a condition': 'une condition'};
String _noun(String value) => _nouns[value] ?? value;
String _noUnit(String value) => value == 'no unit' ? 'sans unité' : value;

final List<(RegExp, String Function(Match))> _errorPatterns = [
  (RegExp(r'^Cannot add incompatible units: (.+) and (.+)$'), (m) => "Impossible d'additionner ${_noUnit(m[1]!)} et ${_noUnit(m[2]!)}."),
  (RegExp(r'^Cannot compare incompatible units: (.+) and (.+)$'), (m) => 'Impossible de comparer ${_noUnit(m[1]!)} et ${_noUnit(m[2]!)}.'),
  (RegExp(r'^Cannot compare (.+) with (.+)$'), (m) => 'Impossible de comparer ${_noun(m[1]!)} avec ${_noun(m[2]!)}.'),
  (RegExp(r'^Expected a date but found (.+)$'), (m) => 'Une date est attendue, pas ${_noun(m[1]!)}.'),
  (RegExp(r'^Expected text but found (.+)$'), (m) => 'Un texte est attendu, pas ${_noun(m[1]!)}.'),
  (RegExp(r'^Expected a number but found (.+)$'), (m) => 'Un nombre est attendu, pas ${_noun(m[1]!)}.'),
  (RegExp(r'^Expected a condition but found (.+)$'), (m) => 'Une condition est attendue, pas ${_noun(m[1]!)}.'),
  (RegExp(r'^Dividing by a unit requires compatible quantities, or the unit (.+) in this collection$'), (m) => "Pour diviser par cette unité, ajoutez l'unité ${m[1]} à la collection ou utilisez des grandeurs compatibles."),
  (RegExp(r'^Formula cycle detected: (.+)$'), (m) => 'Boucle entre formules : ${m[1]}'),
  (RegExp(r'^Unknown unit: (.+)$'), (m) => 'Unité inconnue : ${m[1]}'),
];

String formulaErrorMessage(String apiMessage, BrainyCollection collection, bool french) {
  var message = apiMessage;
  // Local units travel as identifiers, which mean nothing to a reader.
  for (final unit in collection.units) {
    message = message.replaceAll(unit.id, unit.symbol);
  }
  if (!french) return message;
  final fixed = _fixedErrors[message];
  if (fixed != null) return fixed;
  for (final (pattern, translate) in _errorPatterns) {
    final match = pattern.firstMatch(message);
    if (match != null) return translate(match);
  }
  return message;
}
