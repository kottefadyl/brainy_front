import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'brand_assets.dart';
import 'collections_api.dart';
import 'design_tokens.dart';

class WorkspaceNavigation extends StatefulWidget {
  const WorkspaceNavigation({
    super.key,
    required this.collections,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
  });
  final List<BrainyCollection> collections;
  final String? selectedId;
  final ValueChanged<BrainyCollection> onSelect;
  final VoidCallback onCreate;
  @override
  State<WorkspaceNavigation> createState() => _WorkspaceNavigationState();
}

class _WorkspaceNavigationState extends State<WorkspaceNavigation> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final visible = widget.collections
        .where(
          (item) =>
              item.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    return ColoredBox(
      color: dark ? BrainyColors.darkSidebar : BrainyColors.lightSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 20, 10),
            child: Row(
              children: [
                BrainyMark(size: 32),
                SizedBox(width: 10),
                Text(
                  'brainy',
                  style: TextStyle(
                    color: BrainyNavigationColors.ink(dark),
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: BrainyColors.brandRed,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 7, height: 7),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 20, 28),
            child: Text(
              copy.text('One account. Every device.'),
              style: TextStyle(
                color: BrainyNavigationColors.muted(dark),
                fontSize: 13,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              copy.text('COLLECTIONS'),
              style: TextStyle(
                color: BrainyNavigationColors.muted(dark),
                fontSize: 13,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(color: BrainyNavigationColors.ink(dark)),
              decoration: InputDecoration(
                hintText: copy.isFrench ? 'Rechercher…' : 'Search…',
                hintStyle: TextStyle(color: BrainyNavigationColors.muted(dark)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: BrainyNavigationColors.muted(dark),
                ),
                filled: true,
                fillColor: BrainyNavigationColors.field(dark),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: BrainyNavigationColors.border(dark),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: BrainyNavigationColors.ink(dark),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final collection in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: collection.id == widget.selectedId
                          ? BrainyNavigationColors.selected(dark)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        selected: collection.id == widget.selectedId,
                        selectedColor: BrainyNavigationColors.ink(dark),
                        textColor: BrainyNavigationColors.ink(dark),
                        iconColor: BrainyNavigationColors.muted(dark),
                        hoverColor: BrainyNavigationColors.ink(dark)
                            .withValues(alpha: .09),
                        focusColor: BrainyNavigationColors.ink(dark)
                            .withValues(alpha: .20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(
                          collection.id == widget.selectedId
                              ? Icons.folder_rounded
                              : Icons.folder_outlined,
                          size: 20,
                        ),
                        title: Text(
                          collection.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: collection.id == widget.selectedId
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        onTap: () => widget.onSelect(collection),
                      ),
                    ),
                  ),
                if (_query.isNotEmpty && visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      copy.isFrench
                          ? 'Aucune collection trouvée'
                          : 'No matching collections',
                      style: TextStyle(
                        color: BrainyNavigationColors.muted(dark),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(copy.text('New collection')),
              style: OutlinedButton.styleFrom(
                backgroundColor: BrainyNavigationColors.ink(dark),
                foregroundColor: dark
                    ? BrainyColors.darkSidebar
                    : BrainyColors.lightSidebar,
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceMobileCollections extends StatelessWidget {
  const WorkspaceMobileCollections({
    super.key,
    required this.collections,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.onManual,
    required this.onTransfer,
  });
  final List<BrainyCollection> collections;
  final String? selectedId;
  final ValueChanged<BrainyCollection> onSelect;
  final VoidCallback onCreate, onManual, onTransfer;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? BrainyColors.darkSidebar : BrainyColors.lightSidebar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(selectedId),
                initialValue: selectedId,
                isExpanded: true,
                dropdownColor: BrainyNavigationColors.field(dark),
                style: TextStyle(
                  color: BrainyNavigationColors.ink(dark),
                  fontSize: 14,
                ),
                iconEnabledColor: BrainyNavigationColors.ink(dark),
                decoration: InputDecoration(
                  labelText: copy.text('Collection'),
                  labelStyle: TextStyle(
                    color: BrainyNavigationColors.muted(dark),
                  ),
                  floatingLabelStyle: TextStyle(
                    color: BrainyNavigationColors.muted(dark),
                  ),
                  filled: true,
                  fillColor: BrainyNavigationColors.field(dark),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: BrainyNavigationColors.border(dark),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: BrainyNavigationColors.ink(dark),
                      width: 2,
                    ),
                  ),
                ),
                items: [
                  for (final item in collections)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) {
                  for (final item in collections) {
                    if (item.id == id) onSelect(item);
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: copy.text('New collection'),
              onPressed: onCreate,
              color: BrainyNavigationColors.ink(dark),
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: copy.isFrench ? 'Autres actions' : 'More actions',
              icon: Icon(
                Icons.more_horiz_rounded,
                color: BrainyNavigationColors.ink(dark),
              ),
              onSelected: (value) =>
                  value == 'manual' ? onManual() : onTransfer(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'manual',
                  child: Text(
                    copy.isFrench ? 'Créer manuellement' : 'Create manually',
                  ),
                ),
                PopupMenuItem(
                  value: 'transfer',
                  child: Text(copy.text('Import and export')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
