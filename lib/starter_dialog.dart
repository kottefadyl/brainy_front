import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';

Future<BrainyCollection?> showStarterDialog(
  BuildContext context,
  CollectionsApi api, {
  VoidCallback? onPackages,
}) {
  return showDialog<BrainyCollection>(
    context: context,
    builder: (context) => _StarterDialog(api: api, onPackages: onPackages),
  );
}

class _StarterDialog extends StatefulWidget {
  const _StarterDialog({required this.api, this.onPackages});
  final CollectionsApi api;
  final VoidCallback? onPackages;
  @override
  State<_StarterDialog> createState() => _StarterDialogState();
}

class _StarterDialogState extends State<_StarterDialog> {
  final name = TextEditingController();
  List<Map<String, dynamic>> templates = [];
  String? selected;
  String? error;
  bool busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (templates.isEmpty) {
      widget.api
          .starterTemplates(AppStrings.of(context).languageCode)
          .then((items) {
            if (!mounted) return;
            setState(() {
              templates = items;
              selected = items.firstOrNull?['id'] as String?;
              name.text = items.firstOrNull?['name'] as String? ?? '';
            });
          })
          .catchError((Object cause) {
            if (mounted) setState(() => error = cause.toString());
          });
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (selected == null || name.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final language = AppStrings.of(context).languageCode;
      final result = await widget.api.createFromTemplate(
        selected!,
        name.text.trim(),
        language,
        DateTime.now().timeZoneName == 'WAT' ? 'Africa/Lagos' : 'UTC',
      );
      if (mounted) Navigator.pop(context, result);
    } catch (cause) {
      if (mounted) setState(() => error = cause.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Text(fr ? 'Créer une collection' : 'Create a collection'),
      content: SizedBox(
        width: 740,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fr
                    ? 'Choisissez un point de départ. Les formats de données restent modifiables et la collection n’a pas de type permanent.'
                    : 'Choose a starting point. Data formats stay editable and the collection has no permanent type.',
              ),
              if (widget.onPackages != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onPackages!();
                    },
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(fr ? 'Installer un paquet de domaine (fichier, lien ou paquet Brainy)…' : 'Install a domain package (file, link or Brainy package)…'),
                  ),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                maxLength: 80,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: fr ? 'Nom de la collection' : 'Collection name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                fr ? 'Point de départ' : 'Starting point',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: dark
                      ? const Color(0xFFEEF0F2)
                      : const Color(0xFF252B36),
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 540 ? 2 : 1;
                  final cardWidth =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final template in templates)
                        SizedBox(
                          width: cardWidth,
                          child: Semantics(
                            selected: selected == template['id'],
                            button: true,
                            child: Material(
                              color: dark
                                  ? selected == template['id']
                                        ? const Color(0xFF303747)
                                        : const Color(0xFF24282D)
                                  : selected == template['id']
                                  ? const Color(0xFFEAEDF7)
                                  : const Color(0xFFF8F9FA),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: dark
                                      ? selected == template['id']
                                            ? const Color(0xFFAEBBE4)
                                            : const Color(0xFF3D444D)
                                      : selected == template['id']
                                      ? const Color(0xFF6677A9)
                                      : const Color(0xFFE0E5EA),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => setState(() {
                                  final previous = templates
                                      .where((item) => item['id'] == selected)
                                      .firstOrNull;
                                  if (name.text == previous?['name']) {
                                    name.text = template['name'] as String;
                                  }
                                  selected = template['id'] as String;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              template['name'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              template['description'] as String,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (selected == template['id'])
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF3978D5),
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(fr ? 'Annuler' : 'Cancel'),
        ),
        FilledButton(
          onPressed: busy || selected == null || name.text.trim().isEmpty
              ? null
              : create,
          child: Text(fr ? 'Créer la collection' : 'Create collection'),
        ),
      ],
    );
  }
}
