import 'package:flutter/material.dart';

import 'collections_api.dart';
import 'design_tokens.dart';

class CollectionToolsHub extends StatefulWidget {
  const CollectionToolsHub({
    super.key,
    required this.collection,
    required this.userId,
    required this.isFrench,
    required this.isDark,
    required this.onStock,
    required this.onLedger,
    required this.onInsights,
    required this.onUnits,
    required this.onObjects,
    required this.onClassifications,
    required this.onSensitivity,
    required this.onWorkflow,
    required this.onContributions,
    required this.onMap,
    this.onDataSources,
  });

  final BrainyCollection collection;
  final String userId;
  final bool isFrench;
  final bool isDark;

  final VoidCallback onStock;
  final VoidCallback onLedger;
  final VoidCallback onInsights;
  final VoidCallback onUnits;
  final VoidCallback onObjects;
  final VoidCallback onClassifications;
  final VoidCallback onSensitivity;
  final VoidCallback onWorkflow;
  final VoidCallback onContributions;
  final VoidCallback onMap;
  final VoidCallback? onDataSources;

  @override
  State<CollectionToolsHub> createState() => _CollectionToolsHubState();
}

class _CollectionToolsHubState extends State<CollectionToolsHub> {
  bool _expanded = false;

  Color get _surfaceColor =>
      widget.isDark ? BrainyColors.darkSurface : Colors.white;
  Color get _borderColor =>
      widget.isDark ? BrainyColors.darkLine : const Color(0xFFE2E7F0);
  Color get _inkColor =>
      widget.isDark ? BrainyColors.darkInk : const Color(0xFF1E242B);
  Color get _mutedColor =>
      widget.isDark ? BrainyColors.darkMuted : const Color(0xFF64748B);
  Color get _accentColor =>
      widget.isDark ? BrainyColors.darkAccent : const Color(0xFF2E6FD8);
  Color get _cardBgColor =>
      widget.isDark ? BrainyColors.darkElevated : Colors.white;
  static const _lightTints = [Color(0xFFEEF3FE), Color(0xFFE9F7EF), Color(0xFFFDEEEE)];
  static const _lightInks = [Color(0xFF1F4FD8), Color(0xFF157F3B), Color(0xFFB42318)];
  static const _darkTints = [Color(0x245B8CFF), Color(0x2134D27B), Color(0x21FF5A5F)];
  static const _darkInks = [Color(0xFF8CB0FF), Color(0xFF5EDC8C), Color(0xFFFF8A8F)];
  Color _toolTint(int group) => (widget.isDark ? _darkTints : _lightTints)[group];
  Color _toolInk(int group) => (widget.isDark ? _darkInks : _lightInks)[group];
  Color get _cardBorderColor =>
      widget.isDark ? BrainyColors.darkLine : const Color(0xFFE5E9F0);

  @override
  Widget build(BuildContext context) {
    final fr = widget.isFrench;
    final isOwner = widget.collection.ownerId == widget.userId;
    final canSend = widget.onDataSources != null && (isOwner || widget.collection.members.any((member) => member.userId == widget.userId && member.role != BrainyCollectionRole.reader));
    final totalCount = (isOwner ? 10 : 9) + (canSend ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: widget.isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? BrainyColors.darkAccentSoft
                          : const Color(0xFFEBF2FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: _accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                fr
                                    ? 'Outils & options avancées'
                                    : 'Advanced collection tools',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _inkColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? BrainyColors.darkAccentSoft
                                    : const Color(0xFFE8EEF8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$totalCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fr
                              ? 'Statistiques, stocks, cartes, nomenclatures, flux et registre'
                              : 'Analytics, stocks, maps, code lists, workflows, and ledger',
                          style: TextStyle(
                            fontSize: 12,
                            color: _mutedColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _mutedColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Drawer Content
          if (_expanded) ...[
            Divider(height: 1, color: _borderColor),
            Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  final cardWidth = wide
                      ? (constraints.maxWidth - 20) / 3
                      : constraints.maxWidth;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Groupe 1 : Analyse & Métier
                      _sectionTitle(
                        fr ? 'Analyse & Métier' : 'Analytics & Operations',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _toolCard(
                            0,
                            cardWidth,
                            Icons.auto_graph_rounded,
                            fr ? 'Calculs et graphiques' : 'Calculations and charts',
                            fr ? 'Explorer et analyser vos données' : 'Explore and visualize your data',
                            widget.onInsights,
                            featured: true,
                          ),
                          _toolCard(
                            0,
                            cardWidth,
                            Icons.inventory_2_outlined,
                            'Stock',
                            fr
                                ? 'Positions et mouvements validés'
                                : 'Positions and confirmed movements',
                            widget.onStock,
                          ),
                          _toolCard(
                            0,
                            cardWidth,
                            Icons.map_outlined,
                            fr ? 'Carte' : 'Map',
                            fr ? 'Positions GPS et zones' : 'GPS positions and zones',
                            widget.onMap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Groupe 2 : Structure & Modèles
                      _sectionTitle(
                        fr ? 'Structure & Modèles' : 'Structure & Models',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _toolCard(
                            1,
                            cardWidth,
                            Icons.straighten_rounded,
                            fr ? 'Unités et mesures' : 'Units and measures',
                            fr ? 'Mesures et conversions' : 'Measures and conversions',
                            widget.onUnits,
                          ),
                          _toolCard(
                            1,
                            cardWidth,
                            Icons.category_outlined,
                            fr ? 'Objets' : 'Objects',
                            fr ? 'Modèles et références' : 'Models and references',
                            widget.onObjects,
                          ),
                          _toolCard(
                            1,
                            cardWidth,
                            Icons.account_tree_outlined,
                            fr ? 'Classifications' : 'Classifications',
                            fr ? 'Nomenclatures et listes de codes' : 'Controlled code lists',
                            widget.onClassifications,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Groupe 3 : Gouvernance & Sécurité
                      _sectionTitle(
                        fr ? 'Gouvernance & Sécurité' : 'Governance & Security',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _toolCard(
                            2,
                            cardWidth,
                            Icons.fact_check_outlined,
                            fr ? 'États et validations' : 'States and approvals',
                            fr ? 'Assignations, échéances et historique' : 'Assignments, due dates and history',
                            widget.onWorkflow,
                          ),
                          if (canSend)
                            _toolCard(
                              2,
                              cardWidth,
                              Icons.dataset_linked_outlined,
                              fr ? 'Sources de données' : 'Data sources',
                              fr ? 'Fichiers et systèmes externes, rejets expliqués' : 'Files and external systems, explained rejections',
                              widget.onDataSources!,
                            ),
                          if (isOwner)
                            _toolCard(
                              2,
                              cardWidth,
                              Icons.publish_outlined,
                              fr ? 'Contributions publiques' : 'Public contributions',
                              fr ? 'Liens et réponses en quarantaine' : 'Links and submissions in quarantine',
                              widget.onContributions,
                            ),
                          _toolCard(
                            2,
                            cardWidth,
                            Icons.receipt_long_outlined,
                            fr ? 'Registre' : 'Register',
                            fr ? 'Écritures, intégrité et corrections' : 'Writings, integrity and corrections',
                            widget.onLedger,
                          ),
                          _toolCard(
                              2,
                              cardWidth,
                              Icons.shield_outlined,
                              fr ? 'Confidentialité' : 'Privacy',
                              fr ? 'Niveaux et seuils d’analyse' : 'Levels and analysis limits',
                              widget.onSensitivity,
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Row(
    children: [
      Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: _accentColor,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 1,
          color: widget.isDark
              ? BrainyColors.darkLine
              : const Color(0xFFEDF2F7),
        ),
      ),
    ],
  );

  Widget _toolCard(
    int group,
    double width,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action, {
    bool featured = false,
  }) => SizedBox(
    width: width,
    child: Material(
      color: featured
          ? (widget.isDark ? BrainyColors.darkElevated : const Color(0xFFF1F6FD))
          : _cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: featured
              ? (widget.isDark ? BrainyColors.darkLineStrong : const Color(0xFFBCD5F5))
              : _cardBorderColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _toolTint(group),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _toolInk(group), size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _inkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: _mutedColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: _mutedColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
