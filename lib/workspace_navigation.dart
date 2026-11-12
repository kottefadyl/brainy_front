import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collection_scope_tabs.dart';
import 'collections_api.dart';
import 'design_tokens.dart';
import 'workspace_accents.dart';
import 'profile_photo.dart';

class WorkspaceNavigation extends StatefulWidget {
  const WorkspaceNavigation({
    super.key,
    required this.collections,
    required this.selectedId,
    required this.userName,
    required this.userEmail,
    required this.onSelect,
    required this.onCreate,
    required this.onManual,
    required this.onTransfer,
    required this.onTools,
    required this.onSignOut,
    this.onEditProfile,
    this.onGuide,
    this.onGuideCenter,
    this.onCollaborators,
  });
  final List<BrainyCollection> collections;
  final String? selectedId;
  final String userName, userEmail;
  final ValueChanged<BrainyCollection> onSelect;
  final VoidCallback onCreate, onManual, onTransfer, onTools, onSignOut;
  final VoidCallback? onEditProfile, onGuide, onGuideCenter, onCollaborators;
  @override
  State<WorkspaceNavigation> createState() => _WorkspaceNavigationState();
}

class _WorkspaceNavigationState extends State<WorkspaceNavigation> {
  String _query = '';
  CollectionScope? _scopeChoice;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = BrainyNavigationColors.ink(dark);
    final muted = BrainyNavigationColors.muted(dark);
    final line = dark ? BrainyColors.darkLine : const Color(0x2EFFFFFF);
    final visible = widget.collections
        .where(
          (item) =>
              item.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    // T52: my collections and those shared with me are two tabs, each with the full height.
    final mine = visible.where((item) => item.sharedBy == null).toList();
    final shared = visible.where((item) => item.sharedBy != null).toList();
    final sharedTotal = widget.collections.where((item) => item.sharedBy != null).length;
    final scope = collectionScopeFor(_scopeChoice, selectedIsShared: widget.collections.any((item) => item.id == widget.selectedId && item.sharedBy != null), sharedCount: sharedTotal);
    final listed = scope == CollectionScope.shared ? shared : mine;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? BrainyColors.darkSidebar : null,
        gradient: dark ? null : BrainyAccents.sidebarLight,
        border: dark ? Border(right: BorderSide(color: line)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 20, 8),
            child: Row(
              children: [
                ShellLogo(dark: dark, size: 36),
                const SizedBox(width: 10),
                Text(
                  'brainy',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                Text(
                  '.',
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFFF5A5F)
                        : const Color(0xFFFF9AA0),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          // Short windows: the tagline steps aside so the collection list keeps room (as on the web).
          if (MediaQuery.sizeOf(context).height >= 820) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 20, 12),
            child: Text(
              fr
                  ? 'Un petit espace pour de grandes idées.'
                  : 'A little space for big thoughts.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 20, 26),
            child: BrainyAccentBar(dark: dark),
          ),
          ] else
            const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    copy.text('COLLECTIONS'),
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _TotalBadge(count: widget.collections.length, dark: dark),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(color: ink, fontSize: 14),
              cursorColor: ink,
              decoration: InputDecoration(
                isDense: true,
                hintText: fr ? 'Rechercher…' : 'Search…',
                hintStyle: TextStyle(color: muted, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: ink, size: 18),
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
                    color: dark ? BrainyColors.darkAccent : ink,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          if (sharedTotal > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: CollectionScopeTabs(
                value: scope,
                mineCount: mine.length,
                sharedCount: shared.length,
                french: fr,
                dark: dark,
                onChanged: (value) => setState(() => _scopeChoice = value),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (index, collection) in listed.where((item) => item.sharedBy == null).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _CollectionRow(
                      index: index,
                      collection: collection,
                      selected: collection.id == widget.selectedId,
                      dark: dark,
                      onTap: () => widget.onSelect(collection),
                    ),
                  ),
                for (final (index, collection) in listed.where((item) => item.sharedBy != null).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: fr ? 'Partagée par ${collection.sharedBy!.name}' : 'Shared by ${collection.sharedBy!.name}',
                      child: _CollectionRow(
                        index: index,
                        collection: collection,
                        selected: collection.id == widget.selectedId,
                        dark: dark,
                        onTap: () => widget.onSelect(collection),
                      ),
                    ),
                  ),
                if (_query.isNotEmpty && listed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      fr
                          ? 'Aucune collection trouvée'
                          : 'No matching collections',
                      style: TextStyle(color: muted),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(copy.text('New collection')),
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: dark ? BrainyColors.darkPrimary : Colors.white,
                foregroundColor: dark ? Colors.white : BrainyColors.navigationBlue,
                minimumSize: const Size(double.infinity, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(fontFamily: 'Inter', 
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _MoreActions(
              dark: dark,
              onManual: widget.onManual,
              onTransfer: widget.onTransfer,
              onTools: widget.onTools,
              onGuide: widget.onGuide,
              onGuideCenter: widget.onGuideCenter,
              onCollaborators: widget.onCollaborators,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: line),
          ),
          _AccountFooter(
            dark: dark,
            name: widget.userName,
            email: widget.userEmail,
            onEditProfile: widget.onEditProfile,
            onSignOut: widget.onSignOut,
          ),
        ],
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({required this.count, required this.dark});

  final int count;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 30),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: dark ? BrainyAccents.darkBlueTint : BrainyAccents.amberFill,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$count',
      style: TextStyle(
        color: dark ? BrainyAccents.darkBlueInk : BrainyAccents.amberInk,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.index,
    required this.collection,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final int index;
  final BrainyCollection collection;
  final bool selected, dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected && !dark
        ? BrainyColors.navigationBlue
        : BrainyNavigationColors.ink(dark);
    final radius = BorderRadius.circular(10);
    return Semantics(
      selected: selected,
      button: true,
      label: collection.name,
      excludeSemantics: true,
      child: Tooltip(
        message: collection.name,
        waitDuration: const Duration(milliseconds: 600),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: selected && !dark
                ? const [
                    BoxShadow(
                      color: Color(0x800A195A),
                      blurRadius: 12,
                      spreadRadius: -4,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: selected
                ? BrainyNavigationColors.selected(dark)
                : Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              hoverColor: BrainyNavigationColors.hover(dark),
              child: Stack(
                children: [
                  if (selected && dark)
                    const Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: ColoredBox(color: BrainyColors.darkPrimary),
                    ),
                  Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        CollectionColorTile(index: index, dark: dark),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            collection.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Count(
                          count: collection.formats.length,
                          selected: selected,
                          dark: dark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.count,
    required this.selected,
    required this.dark,
  });

  final int count;
  final bool selected, dark;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      '$count',
      style: TextStyle(
        color: selected ? Colors.white : BrainyNavigationColors.muted(dark),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (!selected) return text;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? BrainyColors.darkPrimary : BrainyColors.navigationBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: text,
    );
  }
}

class _MoreActions extends StatelessWidget {
  const _MoreActions({
    required this.dark,
    required this.onManual,
    required this.onTransfer,
    required this.onTools,
    this.onGuide,
    this.onGuideCenter,
    this.onCollaborators,
  });

  final bool dark;
  final VoidCallback onManual, onTransfer, onTools;
  final VoidCallback? onGuide, onGuideCenter, onCollaborators;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    final label = fr ? 'Autres actions' : 'More actions';
    final ink = BrainyNavigationColors.ink(dark);
    return PopupMenuButton<String>(
      tooltip: label,
      position: PopupMenuPosition.over,
      onSelected: (value) => switch (value) {
        'manual' => onManual(),
        'transfer' => onTransfer(),
        'guide' => onGuide?.call(),
        'guideCenter' => onGuideCenter?.call(),
        'collaborators' => onCollaborators?.call(),
        _ => onTools(),
      },
      itemBuilder: (_) => [
        _item('manual', Icons.add_rounded, fr ? 'Créer manuellement' : 'Create manually'),
        _item('transfer', Icons.upload_outlined, copy.text('Import and export')),
        _item('tools', Icons.tune_rounded, fr ? 'Outils de l’espace' : 'Workspace tools'),
        if (onGuide != null) _item('guide', Icons.explore_outlined, fr ? 'Guide de démarrage' : 'Getting started guide'),
        if (onCollaborators != null) _item('collaborators', Icons.group_outlined, fr ? 'Collaborateurs' : 'Collaborators'),
        if (onGuideCenter != null) _item('guideCenter', Icons.school_outlined, fr ? 'Guide et formation' : 'Guide and training'),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BrainyNavigationColors.border(dark)),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 17, color: ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 22, color: ink),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 12),
            Flexible(child: Text(label)),
          ],
        ),
      );
}

class _AccountFooter extends StatelessWidget {
  const _AccountFooter({
    required this.dark,
    required this.name,
    required this.email,
    required this.onSignOut,
    this.onEditProfile,
  });

  final bool dark;
  final String name, email;
  final VoidCallback onSignOut;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final ink = BrainyNavigationColors.ink(dark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
      child: Row(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: profilePhotoNotifier,
            builder: (context, photo, _) => ProfileAvatar(
              name: name,
              photo: photo,
              gradient: dark
                  ? const [BrainyColors.darkPrimary, Color(0xFF22A55A)]
                  : const [Color(0xFFFFD166), Color(0xFFFF9AA0)],
              initialColor: dark ? Colors.white : const Color(0xFF0A2A6B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onEditProfile,
              borderRadius: BorderRadius.circular(8),
              child: Tooltip(
                message: copy.text('Edit profile'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: BrainyNavigationColors.muted(dark),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: copy.text('Sign out'),
            onPressed: onSignOut,
            color: BrainyNavigationColors.muted(dark),
            icon: const Icon(Icons.logout_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}
