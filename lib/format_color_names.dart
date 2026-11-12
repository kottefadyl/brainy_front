// Names of the 24 data format colors (same table as the web, lib/format-color-names.ts).
import 'collections_api.dart';

const _names = [
  ['Ice blue', 'Bleu glacier'], ['Mint', 'Menthe'], ['Peach', 'Pêche'], ['Lavender', 'Lavande'],
  ['Rose', 'Rose'], ['Aqua', 'Aqua'], ['Sand', 'Sable'], ['Sage', 'Sauge'],
  ['Orchid', 'Orchidée'], ['Slate blue', 'Bleu ardoise'], ['Apricot', 'Abricot'], ['Sky', 'Ciel'],
  ['Blush', 'Rose pâle'], ['Powder blue', 'Bleu poudré'], ['Lime', 'Citron vert'], ['Coral', 'Corail'],
  ['Periwinkle', 'Pervenche'], ['Seafoam', 'Écume'], ['Almond', 'Amande'], ['Mist', 'Brume'],
  ['Salmon', 'Saumon'], ['Olive', 'Olive'], ['Lilac', 'Lilas'], ['Celadon', 'Céladon'],
];

String formatColorName(String color, {required bool french}) {
  final index = brainyFormatColors.indexWhere((item) => item.toUpperCase() == color.toUpperCase());
  if (index < 0 || index >= _names.length) return french ? 'Couleur personnalisée' : 'Custom color';
  return _names[index][french ? 1 : 0];
}
