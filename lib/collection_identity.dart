// A collection's look (same meaning as the web's collection-identity.tsx): an icon for its kind, from the template it
// was created with, on a tile tinted with the color of its first data format. Presentation only.
import 'package:flutter/material.dart';

import 'collections_api.dart';
import 'data_format_colors.dart';

const _icons = <String, IconData>{
  'tasks': Icons.checklist_rounded,
  'cards': Icons.layers_outlined,
  'expenses': Icons.account_balance_wallet_outlined,
  'links': Icons.link_rounded,
  'book': Icons.menu_book_outlined,
  'notes': Icons.edit_note_rounded,
  'agenda': Icons.calendar_month_outlined,
  'fitness': Icons.fitness_center_rounded,
  'shop': Icons.storefront_outlined,
  'capture': Icons.inbox_outlined,
  // T58: everyday-life templates.
  'pantry': Icons.shopping_basket_outlined,
  'recipes': Icons.restaurant_menu_rounded,
  'home': Icons.home_outlined,
  'papers': Icons.badge_outlined,
  'family_health': Icons.monitor_heart_outlined,
  'kids': Icons.child_care_rounded,
  'birthdays': Icons.cake_outlined,
  'pets': Icons.pets_rounded,
  'lending': Icons.handshake_outlined,
  'budget': Icons.savings_outlined,
  'debts': Icons.payments_outlined,
  'valuables': Icons.inventory_2_outlined,
  'journal': Icons.auto_stories_outlined,
  'habits': Icons.repeat_rounded,
  'watchlist': Icons.movie_outlined,
  'travel': Icons.flight_takeoff_rounded,
  'garden': Icons.local_florist_outlined,
  'car': Icons.directions_car_outlined,
};

IconData collectionIconFor(String? templateId, {bool shared = false}) =>
    _icons[templateId] ?? (shared ? Icons.drive_file_move_outline : Icons.folder_special_outlined);

/// The collection's icon on its tinted tile (sidebar, drawer, header).
class CollectionGlyph extends StatelessWidget {
  const CollectionGlyph({super.key, required this.templateId, required this.color, this.shared = false, this.size = 30, this.iconSize = 17});

  CollectionGlyph.of(BrainyCollection collection, {Key? key, double size = 30, double iconSize = 17})
      : this(key: key, templateId: collection.templateId, color: collection.formats.firstOrNull?.color ?? '#EEF5FF', shared: collection.sharedBy != null, size: size, iconSize: iconSize);

  final String? templateId;
  final String color;
  final bool shared;
  final double size, iconSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = DataFormatColors.surface(color, dark);
    final ink = dark ? DataFormatColors.marker(color, true) : DataFormatColors.marker(color, false);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(color: ink.withValues(alpha: dark ? .22 : .16)),
      ),
      child: Icon(collectionIconFor(templateId, shared: shared), size: iconSize, color: ink),
    );
  }
}
