import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collection_identity.dart';
import 'data_format_colors.dart';
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
    this.onInsights,
    required this.onRename,
    required this.onDelete,
    this.onPackages,
    this.onShare,
    this.owner = true,
    this.canWrite = true,
    this.memberCount = 0,
    this.calculations = true,
    this.onCalculations,
    this.templateId,
    this.color = '#EEF5FF',
  });

  /// Kind of collection (icon) and color of its first data format (tint), for its look only.
  final String? templateId;
  final String color;

  /// Calculations and statistics: when off, "Insights" is not shown; the owner switches it in "Manage".
  final bool calculations;
  final ValueChanged<bool>? onCalculations;

  final String name;

  /// Number of people the owner shared the collection with; the chip opens the share sheet.
  final int memberCount;
  final int entryCount, formatCount;
  final bool partialEntryCount;
  final VoidCallback onNewEntry, onRename, onDelete;
  final VoidCallback? onPackages, onInsights;

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
                BoxShadow(color: Color(0x0D101828), blurRadius: 2, offset: Offset(0, 1)),
                BoxShadow(color: Color(0x59101828), blurRadius: 28, spreadRadius: -22, offset: Offset(0, 12)),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(child: _Backdrop(dark: dark, color: color)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 16 : 22,
                narrow ? 18 : 20,
                narrow ? 16 : 22,
                narrow ? 16 : 18,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  final identity = _Identity(
                    name: name,
                    entryCount: entryCount,
                    partialEntryCount: partialEntryCount,
                    formatCount: formatCount,
                    memberCount: owner ? memberCount : 0,
                    onMembers: onShare,
                    dark: dark,
                    templateId: templateId,
                    color: color,
                    narrow: narrow,
                  );
                  final actions = _Actions(
                    dark: dark,
                    stretched: compact,
                    onNewEntry: onNewEntry,
                    onInsights: calculations ? onInsights : null,
                    calculations: calculations,
                    onCalculations: owner ? onCalculations : null,
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
                        const SizedBox(height: 14),
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
  const _Backdrop({required this.dark, required this.color});

  final bool dark;
  final String color;

  @override
  Widget build(BuildContext context) {
    final tint = DataFormatColors.surface(color, dark);
    final edge = DataFormatColors.marker(color, dark).withValues(alpha: dark ? .18 : .14);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? BrainyColors.darkSurface : BrainyColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color.alphaBlend(edge, dark ? BrainyColors.darkLine : BrainyColors.lightLine)),
      ),
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(-1, -1), radius: 1.6, colors: [tint.withValues(alpha: dark ? .9 : .95), tint.withValues(alpha: 0)], stops: const [0, .62]))),
        DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(1, 1), radius: 1.2, colors: [(dark ? const Color(0xFF4C7DF5) : BrainyColors.blue).withValues(alpha: dark ? .10 : .07), Colors.transparent]))),
      ]),
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
    this.memberCount = 0,
    this.onMembers,
    this.templateId,
    this.color = '#EEF5FF',
    this.narrow = false,
  });

  final String? templateId;
  final String color;
  final bool narrow;

  final String name;
  final int entryCount, formatCount, memberCount;
  final bool partialEntryCount, dark;
  final VoidCallback? onMembers;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Row(
      children: [
        CollectionGlyph(templateId: templateId, color: color, size: narrow ? 42 : 48, iconSize: narrow ? 22 : 25),
        SizedBox(width: narrow ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: BrainyNavigationColors.ink(dark),
                  fontSize: narrow ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: Icons.description_outlined,
                    label:
                        '$entryCount${partialEntryCount ? '+' : ''} ${copy.text(entryCount == 1 ? 'entry' : 'entries').toLowerCase()}',
                    fill: dark ? const Color(0x14FFFFFF) : const Color(0xB3FFFFFF),
                    ink: dark ? BrainyColors.darkMuted : BrainyColors.lightMuted,
                  ),
                  _Chip(
                    label:
                        '$formatCount ${copy.text(formatCount == 1 ? 'data format' : 'data formats').toLowerCase()}',
                    icon: Icons.category_outlined,
                    fill: dark ? const Color(0x14FFFFFF) : const Color(0xB3FFFFFF),
                    ink: dark ? BrainyColors.darkMuted : BrainyColors.lightMuted,
                  ),
                  if (memberCount > 0)
                    Semantics(
                      button: onMembers != null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onMembers,
                        child: _Chip(
                          icon: Icons.group_outlined,
                          label: copy.isFrench
                              ? 'Partagée avec $memberCount personne${memberCount > 1 ? 's' : ''}'
                              : 'Shared with $memberCount ${memberCount > 1 ? 'people' : 'person'}',
                          fill: dark ? const Color(0x24F59E0B) : BrainyAccents.amberFill,
                          ink: dark ? const Color(0xFFFCD34D) : BrainyAccents.amberInk,
                        ),
                      ),
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
      border: Border.all(color: ink.withValues(alpha: .18)),
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
    this.onInsights,
    required this.onRename,
    required this.onDelete,
    this.onPackages,
    this.onShare,
    this.owner = true,
    this.canWrite = true,
    this.calculations = true,
    this.onCalculations,
  });

  final bool dark, stretched, owner, canWrite, calculations;
  final VoidCallback onNewEntry, onRename, onDelete;
  final VoidCallback? onPackages, onShare, onInsights;
  final ValueChanged<bool>? onCalculations;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    final ink = BrainyNavigationColors.ink(dark);
    final outline = dark ? BrainyColors.darkLineStrong : const Color(0xFFD5DBE6);
    final fill = dark ? Colors.transparent : BrainyColors.lightSurface;
    const labelStyle = TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700);
    final newEntry = FilledButton.icon(
      onPressed: onNewEntry,
      icon: const Icon(Icons.add_rounded, size: 19),
      label: Text(copy.text('New entry')),
      style: FilledButton.styleFrom(
        backgroundColor: dark ? BrainyColors.darkPrimary : BrainyColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: labelStyle,
      ),
    );
    final Widget? insights = onInsights == null ? null : OutlinedButton.icon(
      onPressed: onInsights,
      icon: Icon(
        Icons.auto_graph_rounded,
        size: 17,
        color: dark ? BrainyAccents.darkGreenInk : const Color(0xFF15803D),
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
        'calculations' => onCalculations?.call(!calculations),
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
          if (onCalculations != null)
            PopupMenuItem(
              value: 'calculations',
              child: Row(children: [
                const Icon(Icons.calculate_outlined, size: 18),
                const SizedBox(width: 12),
                Flexible(child: Text(fr ? 'Calculs' : 'Calculations')),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(color: (calculations ? const Color(0xFF16A34A) : Theme.of(context).colorScheme.outline).withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                  child: Text(calculations ? (fr ? 'Oui' : 'On') : (fr ? 'Non' : 'Off'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: calculations ? const Color(0xFF15803D) : Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ]),
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
            Icon(Icons.tune_rounded, size: 17, color: dark ? BrainyColors.darkAccent : BrainyColors.blue),
            const SizedBox(width: 8),
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
              if (insights != null) Expanded(child: insights),
              if (owner) ...[if (insights != null) const SizedBox(width: 8), Expanded(child: manage)],
            ],
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canWrite) ...[newEntry, const SizedBox(width: 8)],
        ?insights,
        if (owner) ...[if (insights != null) const SizedBox(width: 8), manage],
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
