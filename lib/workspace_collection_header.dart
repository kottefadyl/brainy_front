import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'workspace_accents.dart';

/// Banner at the top of a collection: identity, counts and main actions.
class WorkspaceCollectionHeader extends StatelessWidget {
  const WorkspaceCollectionHeader({
    super.key,
    required this.name,
    required this.entryCount,
    required this.partialEntryCount,
    required this.formatCount,
    required this.onNewEntry,
    required this.onInsights,
    required this.onRename,
    required this.onDelete,
    this.onPackages,
    this.onShare,
    this.owner = true,
    this.canWrite = true,
  });

  final String name;
  final int entryCount, formatCount;
  final bool partialEntryCount;
  final VoidCallback onNewEntry, onInsights, onRename, onDelete;
  final VoidCallback? onPackages;

  /// T52: only the owner shares, renames and deletes; a read-only collaborator cannot add entries.
  final VoidCallback? onShare;
  final bool owner, canWrite;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0xA6084BC4),
                  blurRadius: 30,
                  spreadRadius: -16,
                  offset: Offset(0, 14),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(child: _Backdrop(dark: dark)),
            // On a phone the pattern would run behind the title and chips.
            if (!narrow)
              Positioned(
                right: 90,
                top: 12,
                width: 240,
                height: 166,
                child: IgnorePointer(
                  child: CircuitPattern(
                    color: dark
                        ? const Color(0x338CB0FF)
                        : const Color(0x1FFFFFFF),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 20 : 32,
                narrow ? 28 : 40,
                narrow ? 20 : 32,
                narrow ? 22 : 36,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  final identity = _Identity(
                    name: name,
                    entryCount: entryCount,
                    partialEntryCount: partialEntryCount,
                    formatCount: formatCount,
                    dark: dark,
                  );
                  final actions = _Actions(
                    dark: dark,
                    stretched: compact,
                    onNewEntry: onNewEntry,
                    onInsights: onInsights,
                    onRename: onRename,
                    onDelete: onDelete,
                    onPackages: onPackages,
                    onShare: onShare,
                    owner: owner,
                    canWrite: canWrite,
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 22),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 20),
                      actions,
                    ],
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: dark
                        ? BrainyAccents.stripDark
                        : BrainyAccents.stripLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final layers = dark
        ? const [
            RadialGradient(
              center: Alignment.topLeft,
              radius: 1.1,
              colors: [Color(0x2E4C7DF5), Color(0x004C7DF5)],
            ),
            RadialGradient(
              center: Alignment.bottomRight,
              radius: 1,
              colors: [Color(0x1734D27B), Color(0x0034D27B)],
            ),
            RadialGradient(
              center: Alignment(.7, -1),
              radius: .5,
              colors: [Color(0x0FFF5A5F), Color(0x00FF5A5F)],
            ),
          ]
        : const [
            RadialGradient(
              center: Alignment.topRight,
              radius: 1.1,
              colors: [Color(0x47A78BFA), Color(0x00A78BFA)],
            ),
            RadialGradient(
              center: Alignment.bottomRight,
              radius: 1,
              colors: [Color(0x2934D399), Color(0x0034D399)],
            ),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? BrainyColors.darkSurface : null,
        gradient: dark
            ? null
            : const LinearGradient(
                begin: Alignment(-1, -.6),
                end: Alignment(1, .6),
                colors: BrainyAccents.lightBlueStops,
                stops: [0, .52, 1],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? BrainyColors.darkLine : BrainyColors.navigationBlue,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final layer in layers)
            DecoratedBox(decoration: BoxDecoration(gradient: layer)),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.entryCount,
    required this.partialEntryCount,
    required this.formatCount,
    required this.dark,
  });

  final String name;
  final int entryCount, formatCount;
  final bool partialEntryCount, dark;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF3B82F6), Color(0xFF2454E6), Color(0xFF1A3FB0)]
                  : const [Color(0xFFFFF3D1), Color(0xFFFFD98A)],
            ),
          ),
          child: FolderHeartIcon(
            size: 27,
            color: dark ? Colors.white : const Color(0xFF8A4B00),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.text('Collection').toUpperCase(),
                style: TextStyle(
                  color: dark ? BrainyColors.darkAccent : const Color(0xFFDCE6FF),
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: BrainyNavigationColors.ink(dark),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: Icons.description_outlined,
                    label:
                        '$entryCount${partialEntryCount ? '+' : ''} ${copy.text(entryCount == 1 ? 'entry' : 'entries').toLowerCase()}',
                    fill: dark ? BrainyAccents.darkBlueTint : BrainyAccents.skyFill,
                    ink: dark ? BrainyAccents.darkBlueInk : BrainyAccents.skyInk,
                  ),
                  _Chip(
                    label:
                        '$formatCount ${copy.text(formatCount == 1 ? 'data format' : 'data formats').toLowerCase()}',
                    fill: dark ? BrainyAccents.darkGreenTint : BrainyAccents.mintFill,
                    ink: dark ? BrainyAccents.darkGreenInk : BrainyAccents.mintInk,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.fill,
    required this.ink,
    this.icon,
  });

  final IconData? icon;
  final String label;
  final Color fill, ink;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: ink),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.dark,
    required this.stretched,
    required this.onNewEntry,
    required this.onInsights,
    required this.onRename,
    required this.onDelete,
    this.onPackages,
    this.onShare,
    this.owner = true,
    this.canWrite = true,
  });

  final bool dark, stretched, owner, canWrite;
  final VoidCallback onNewEntry, onInsights, onRename, onDelete;
  final VoidCallback? onPackages, onShare;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    final ink = BrainyNavigationColors.ink(dark);
    final outline = dark ? BrainyColors.darkLineStrong : const Color(0x73FFFFFF);
    final fill = dark ? Colors.transparent : const Color(0x1FFFFFFF);
    const labelStyle = TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700);
    final newEntry = FilledButton.icon(
      onPressed: onNewEntry,
      icon: const Icon(Icons.add_rounded, size: 19),
      label: Text(copy.text('New entry')),
      style: FilledButton.styleFrom(
        backgroundColor: dark ? BrainyColors.darkPrimary : Colors.white,
        foregroundColor: dark ? Colors.white : BrainyColors.navigationBlue,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: labelStyle,
      ),
    );
    final insights = OutlinedButton.icon(
      onPressed: onInsights,
      icon: Icon(
        Icons.auto_graph_rounded,
        size: 17,
        color: dark ? BrainyAccents.darkGreenInk : const Color(0xFF8CF0B8),
      ),
      label: Text(fr ? 'Calculs' : 'Insights'),
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: fill,
        side: BorderSide(color: outline),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: labelStyle,
      ),
    );
    final manageLabel = fr ? 'Gérer' : 'Manage';
    final manage = PopupMenuButton<String>(
      tooltip: manageLabel,
      position: PopupMenuPosition.under,
      onSelected: (action) => switch (action) {
        'rename' => onRename(),
        'share' => onShare?.call(),
        'packages' => onPackages?.call(),
        _ => onDelete(),
      },
      itemBuilder: (context) {
        final danger = Theme.of(context).colorScheme.error;
        return [
          if (onShare != null) _menuItem('share', Icons.person_add_alt_1_outlined, fr ? 'Partager' : 'Share'),
          _menuItem('rename', Icons.edit_outlined, copy.text('Rename')),
          if (onPackages != null)
            _menuItem(
              'packages',
              Icons.inventory_2_outlined,
              fr ? 'Paquets de domaine' : 'Domain packages',
            ),
          _menuItem(
            'delete',
            Icons.delete_outline_rounded,
            copy.text('Delete collection'),
            color: danger,
          ),
        ];
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 16, right: 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                manageLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle.copyWith(color: ink),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, size: 20, color: ink),
          ],
        ),
      ),
    );
    if (stretched) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canWrite) ...[newEntry, const SizedBox(height: 8)],
          Row(
            children: [
              Expanded(child: insights),
              if (owner) ...[const SizedBox(width: 8), Expanded(child: manage)],
            ],
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canWrite) ...[newEntry, const SizedBox(width: 8)],
        insights,
        if (owner) ...[const SizedBox(width: 8), manage],
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Flexible(child: Text(label, style: TextStyle(color: color))),
      ],
    ),
  );
}
