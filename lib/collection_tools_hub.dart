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
      widget.isDark ? const Color(0xFF29292C) : const Color(0xFFF8FAFC);
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
                                    ? 'Outils et options de la collection'
                                    : 'Collection tools & options',
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
                                    ? const Color(0xFF37373B)
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
                              ? 'Calculs, stock, unités, modèles, workflow et gouvernance'
                              : 'Calculations, stock, units, models, workflow, and governance',
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
                        fr ? 'Analyse & Métier' : 'Analysis & Operations',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _toolCard(
                            cardWidth,
                            Icons.auto_graph_rounded,
                            fr ? 'Calculs et graphiques' : 'Calculations and charts',
                            fr ? 'Explorez vos données' : 'Explore your data',
                            widget.onInsights,
                            featured: true,
                          ),
                          _toolCard(
                            cardWidth,
                            Icons.inventory_2_outlined,
                            'Stock',
                            fr
                                ? 'Positions et mouvements'
                                : 'Positions and movements',
                            widget.onStock,
                          ),
                          _toolCard(
                            cardWidth,
                            Icons.map_outlined,
                            fr ? 'Carte' : 'Map',
                            fr ? 'Positions et zones' : 'Positions and zones',
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
                            cardWidth,
                            Icons.straighten_rounded,
                            fr ? 'Unités et mesures' : 'Units and measures',
                            fr ? 'Mesures et conversions' : 'Measures and conversions',
                            widget.onUnits,
                          ),
                          _toolCard(
                            cardWidth,
                            Icons.category_outlined,
                            fr ? 'Objets' : 'Objects',
                            fr ? 'Modèles et références' : 'Models and references',
                            widget.onObjects,
                          ),
                          _toolCard(
                            cardWidth,
                            Icons.account_tree_outlined,
                            fr ? 'Classifications' : 'Classifications',
                            fr ? 'Listes de codes locales' : 'Local code lists',
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
                            cardWidth,
                            Icons.fact_check_outlined,
                            fr ? 'États et validations' : 'States and approvals',
                            fr ? 'Assignations et échéances' : 'Assignments and due dates',
                            widget.onWorkflow,
                          ),
                          if (canSend)
                            _toolCard(
                              cardWidth,
                              Icons.dataset_linked_outlined,
                              fr ? 'Sources de données' : 'Data sources',
                              fr ? 'Fichiers et systèmes externes' : 'Files and external systems',
                              widget.onDataSources!,
                            ),
                          if (isOwner)
                            _toolCard(
                              cardWidth,
                              Icons.publish_outlined,
                              fr ? 'Contributions publiques' : 'Public contributions',
                              fr ? 'Liens et réponses à valider' : 'Links and submissions',
                              widget.onContributions,
                            ),
                          _toolCard(
                            cardWidth,
                            Icons.receipt_long_outlined,
                            fr ? 'Registre' : 'Register',
                            fr ? 'Écritures et intégrité' : 'Writings and integrity',
                            widget.onLedger,
                          ),
                          if (isOwner)
                            _toolCard(
                              cardWidth,
                              Icons.shield_outlined,
                              fr ? 'Confidentialité' : 'Privacy',
                              fr ? 'Champs et seuil d’agrégat' : 'Protected fields & privacy',
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
              ? const Color(0xFF49494F)
              : const Color(0xFFEDF2F7),
        ),
      ),
    ],
  );

  Widget _toolCard(
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
          ? (widget.isDark ? const Color(0xFF302D36) : const Color(0xFFF1F6FD))
          : _cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: featured
              ? (widget.isDark ? const Color(0xFF625B72) : const Color(0xFFBCD5F5))
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: featured
                      ? (widget.isDark ? BrainyColors.darkAccentSoft : const Color(0xFFDFECFB))
                      : (widget.isDark ? const Color(0xFF343438) : const Color(0xFFE9EEF5)),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: featured ? _accentColor : _inkColor,
                  size: 20,
                ),
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
