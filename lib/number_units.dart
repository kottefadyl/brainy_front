import 'app_strings.dart';

class NumberUnit {
  const NumberUnit(this.code, this.name, this.symbol, this.category);
  final String code;
  final String name;
  final String symbol;
  final String category;
}

const numberUnits = <NumberUnit>[
  NumberUnit('km', 'Kilometres', 'km', 'Distance'),
  NumberUnit('m', 'Metres', 'm', 'Distance'),
  NumberUnit('cm', 'Centimetres', 'cm', 'Distance'),
  NumberUnit('mm', 'Millimetres', 'mm', 'Distance'),
  NumberUnit('mi', 'Miles', 'mi', 'Distance'),
  NumberUnit('ft', 'Feet', 'ft', 'Distance'),
  NumberUnit('in', 'Inches', 'in', 'Distance'),
  NumberUnit('kg', 'Kilograms', 'kg', 'Mass'),
  NumberUnit('g', 'Grams', 'g', 'Mass'),
  NumberUnit('lb', 'Pounds', 'lb', 'Mass'),
  NumberUnit('L', 'Litres', 'L', 'Volume'),
  NumberUnit('mL', 'Millilitres', 'mL', 'Volume'),
  NumberUnit('°C', 'Celsius', '°C', 'Temperature'),
  NumberUnit('°F', 'Fahrenheit', '°F', 'Temperature'),
  NumberUnit('EUR', 'Euro', '€', 'Money'),
  NumberUnit('USD', 'US dollar', r'$', 'Money'),
  NumberUnit('GBP', 'British pound', '£', 'Money'),
  NumberUnit('NGN', 'Nigerian naira', '₦', 'Money'),
  NumberUnit('%', 'Percent', '%', 'Other'),
  NumberUnit('h', 'Hours', 'h', 'Other'),
  NumberUnit('min', 'Minutes', 'min', 'Other'),
  NumberUnit('s', 'Seconds', 's', 'Other'),
];

NumberUnit? numberUnit(String? code) {
  for (final unit in numberUnits) {
    if (unit.code == code) return unit;
  }
  return null;
}

String unitChoiceLabel(AppStrings copy, NumberUnit unit) =>
    '${copy.text(unit.category)} · ${copy.text(unit.name)} (${unit.symbol})';

String formatFieldNumber(String value, String? code, AppStrings copy) {
  final number = copy.isFrench ? value.replaceAll('.', ',') : value;
  if (code == null || code.isEmpty) return number;
  final unit = numberUnit(code);
  if (['EUR', 'USD', 'GBP', 'NGN'].contains(code)) {
    return '${unit?.symbol ?? code} $number';
  }
  return '$number ${unit?.symbol ?? code}';
}

String normalizeFieldNumber(String value) => value.trim().replaceAll(',', '.');
