import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Which collections the navigation lists (T52): mine, or those shared with me.
enum CollectionScope { mine, shared }

/// The tab to show: the reader's choice, or the side of the collection that is open.
CollectionScope collectionScopeFor(CollectionScope? choice, {required bool selectedIsShared, required int sharedCount}) {
  if (sharedCount == 0) return CollectionScope.mine;
  return choice ?? (selectedIsShared ? CollectionScope.shared : CollectionScope.mine);
}

/// "Mine | Shared" switch at the top of the navigation. Each list then gets the whole height
/// instead of sharing it. Same labels and behaviour as the web sidebar.
class CollectionScopeTabs extends StatelessWidget {
  const CollectionScopeTabs({
    super.key,
    required this.value,
    required this.mineCount,
    required this.sharedCount,
    required this.french,
    required this.dark,
    required this.onChanged,
  });

  final CollectionScope value;
  final int mineCount, sharedCount;
  final bool french, dark;
  final ValueChanged<CollectionScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = BrainyNavigationColors.ink(dark);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BrainyNavigationColors.field(dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrainyNavigationColors.border(dark)),
      ),
      child: Row(
        children: [
          for (final (scope, label, full, count, icon) in [
            (CollectionScope.mine, french ? 'À moi' : 'Mine', french ? 'Mes collections' : 'My collections', mineCount, Icons.folder_special_outlined),
            (CollectionScope.shared, french ? 'Partagées' : 'Shared', french ? 'Partagées avec moi' : 'Shared with me', sharedCount, Icons.group_outlined),
          ])
            Expanded(
              child: Semantics(
                key: ValueKey('scope-${scope.name}'),
                selected: scope == value,
                button: true,
                label: '$full, $count',
                excludeSemantics: true,
                child: Tooltip(
                  message: full,
                  child: _ScopeTab(
                    label: label,
                    count: count,
                    icon: icon,
                    selected: scope == value,
                    dark: dark,
                    ink: ink,
                    onTap: () => onChanged(scope),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({required this.label, required this.count, required this.icon, required this.selected, required this.dark, required this.ink, required this.onTap});

  final String label;
  final int count;
  final IconData icon;
  final bool selected, dark;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBackground = dark ? BrainyColors.darkAccentSoft : Colors.white;
    final selectedInk = dark ? BrainyColors.darkInk : const Color(0xFF084BC4);
    final color = selected ? selectedInk : ink;
    return Material(
      color: selected ? selectedBackground : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: .14) : BrainyNavigationColors.field(dark),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
