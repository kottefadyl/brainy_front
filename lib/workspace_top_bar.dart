import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'workspace_accents.dart';

/// Compact phone bar: brand, global actions and the collections menu.
class WorkspaceMobileBar extends StatelessWidget {
  const WorkspaceMobileBar({
    super.key,
    required this.languageControl,
    required this.onCapture,
    required this.onOpenCollections,
    this.themeControl,
    this.account,
    this.onRefresh,
  });

  final Widget languageControl;
  final Widget? themeControl;
  final Widget? account;
  final VoidCallback? onCapture;
  final VoidCallback onOpenCollections;

  /// Reloads collections and entries, like the refresh button of the desktop bar and of the web.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = BrainyNavigationColors.ink(dark);
    return Container(
      height: 60,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: dark ? BrainyColors.darkSidebar : BrainyColors.lightSidebar,
        border: dark
            ? const Border(bottom: BorderSide(color: BrainyColors.darkLine))
            : null,
      ),
      child: Row(
        children: [
          ShellLogo(dark: dark, size: 30),
          if (MediaQuery.sizeOf(context).width >= 400) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'brainy',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: fr ? 'Capture rapide' : 'Quick capture',
            onPressed: onCapture,
            color: ink,
            icon: const Icon(Icons.bolt_rounded),
          ),
          languageControl,
          ?themeControl,
          if (onRefresh != null)
            IconButton(
              key: const Key('mobile-refresh'),
              tooltip: fr ? 'Actualiser' : 'Refresh',
              onPressed: onRefresh,
              color: ink,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ?account,
          IconButton(
            tooltip: fr ? 'Ouvrir les collections' : 'Open collections',
            onPressed: onOpenCollections,
            color: ink,
            iconSize: 26,
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),
    );
  }
}

/// Desktop bar above the collection: breadcrumb and global actions.
class WorkspaceTopBar extends StatefulWidget {
  const WorkspaceTopBar({
    super.key,
    required this.selectedName,
    required this.languageControl,
    required this.onCapture,
    required this.onRefresh,
    this.themeControl,
    this.account,
  });

  final String? selectedName;
  final Widget languageControl;
  final Widget? themeControl;
  final Widget? account;
  final VoidCallback? onCapture;
  final Future<void> Function() onRefresh;

  @override
  State<WorkspaceTopBar> createState() => _WorkspaceTopBarState();
}

class _WorkspaceTopBarState extends State<WorkspaceTopBar> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final fr = copy.isFrench;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? BrainyColors.darkInk : BrainyColors.lightInk;
    final muted = dark ? BrainyColors.darkMuted : BrainyColors.lightMuted;
    final refreshLabel = _refreshing
        ? (fr ? 'Actualisation…' : 'Refreshing…')
        : (fr ? 'Actualiser' : 'Refresh');
    final name = widget.selectedName;
    return Container(
      height: 68,
      padding: const EdgeInsets.only(left: 38, right: 22),
      decoration: BoxDecoration(
        color: dark ? BrainyColors.darkCanvas : BrainyColors.lightCanvas,
        border: Border(
          bottom: BorderSide(
            color: dark ? BrainyColors.darkLine : BrainyColors.lightLine,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: fr ? 'Fil d’Ariane' : 'Breadcrumb',
              child: Row(
                children: [
                  Text(
                    copy.text('Your workspace'),
                    style: TextStyle(color: muted, fontSize: 15),
                  ),
                  if (name != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ExcludeSemantics(
                        child: Text('/', style: TextStyle(color: muted)),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: widget.onCapture,
            style: FilledButton.styleFrom(
              backgroundColor: dark
                  ? BrainyColors.darkAccentSoft
                  : BrainyColors.lightAccentSoft,
              foregroundColor: dark
                  ? BrainyColors.darkAccent
                  : BrainyColors.lightAccent,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: const TextStyle(fontFamily: 'Inter', 
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(fr ? 'Capturer' : 'Capture'),
          ),
          const SizedBox(width: 6),
          ?widget.themeControl,
          const SizedBox(width: 2),
          widget.languageControl,
          const SizedBox(width: 2),
          IconButton(
            tooltip: refreshLabel,
            onPressed: _refreshing ? null : _refresh,
            color: ink,
            icon: _refreshing
                ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: muted))
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          if (widget.account != null) ...[
            const SizedBox(width: 8),
            widget.account!,
          ],
        ],
      ),
    );
  }
}
