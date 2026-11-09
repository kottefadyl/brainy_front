import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'app_strings.dart';
import 'background_jobs_panel.dart';
import 'collections_api.dart';
import 'design_tokens.dart';
import 'workspace_backup_panel.dart';

Future<void> showWorkspaceToolsDialog(
  BuildContext context, {
  required CollectionsApi api,
  required List<BrainyCollection> collections,
  required VoidCallback onRestored,
}) => showDialog(
  context: context,
  builder: (context) => WorkspaceToolsDialog(
    api: api,
    collections: collections,
    onRestored: onRestored,
  ),
);

class WorkspaceToolsDialog extends StatelessWidget {
  const WorkspaceToolsDialog({
    super.key,
    required this.api,
    required this.collections,
    required this.onRestored,
  });

  final CollectionsApi api;
  final List<BrainyCollection> collections;
  final VoidCallback onRestored;

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdaptiveFormShell(
      backgroundColor: isDark ? BrainyColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? BrainyColors.darkLine : const Color(0xFFE2E7F0),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: isPhoneForm(context) ? const BoxConstraints() : const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: isPhoneForm(context) ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? BrainyColors.darkAccentSoft
                          : const Color(0xFFEBF2FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: isDark
                          ? BrainyColors.darkAccent
                          : const Color(0xFF2E6FD8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fr
                              ? 'Outils de l’espace de travail'
                              : 'Workspace tools',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? BrainyColors.darkInk : const Color(0xFF1E242B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fr
                              ? 'Sauvegardes complètes, restaurations et traitements asynchrones'
                              : 'Full workspace backups, restores, and background processing',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? BrainyColors.darkMuted
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: fr ? 'Fermer' : 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    WorkspaceBackupPanel(
                      api: api,
                      onRestored: () {
                        Navigator.of(context).pop();
                        onRestored();
                      },
                    ),
                    const SizedBox(height: 16),
                    BackgroundJobsPanel(
                      api: api,
                      collections: collections,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
