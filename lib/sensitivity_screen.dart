import 'package:flutter/material.dart';

import 'audit_log_screen.dart';
import 'collections_api.dart';

Future<bool> showSensitivityScreen(BuildContext context, CollectionsApi api,
    BrainyCollection collection, {required bool french}) async {
  return await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => _SensitivityScreen(api: api, collection: collection, french: french),
      )) ?? false;
}

class _SensitivityScreen extends StatefulWidget {
  const _SensitivityScreen({required this.api, required this.collection, required this.french});
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool french;
  @override
  State<_SensitivityScreen> createState() => _SensitivityScreenState();
}

class _SensitivityScreenState extends State<_SensitivityScreen> {
  late BrainyCollection current = widget.collection;
  late final minimum = TextEditingController(text: '${current.minAggregateSize}');
  bool busy = false;
  bool changed = false;
  String? error;
  String t(String fr, String en) => widget.french ? fr : en;
  @override
  void dispose() { minimum.dispose(); super.dispose(); }

  Future<void> save(Future<BrainyCollection> Function() action) async {
    setState(() { busy = true; error = null; });
    try {
      final result = await action();
      if (mounted) setState(() { current = result; busy = false; changed = true; });
    } catch (cause) {
      if (mounted) setState(() { error = '$cause'; busy = false; });
    }
  }

  Widget levelPicker(String label, String value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        key: ValueKey('$label:$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem(value: 'ORDINARY', child: Text(t('Ordinaire', 'Ordinary'), maxLines: 1, overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: 'PERSONAL', child: Text(t('Personnel', 'Personal'), maxLines: 1, overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: 'SENSITIVE', child: Text(t('Sensible', 'Sensitive'), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: busy ? null : (next) { if (next != null && next != value) onChanged(next); },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(t('Confidentialité', 'Privacy')),
      leading: BackButton(onPressed: () => Navigator.pop(context, changed)),
    ),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('Les champs personnels et sensibles sont masqués aux membres et exclus des exports par défaut. Une inclusion explicite est nécessaire.',
          'Personal and sensitive fields are hidden from members and excluded from exports by default. Explicit inclusion is required.')),
        const SizedBox(height: 12),
        Text(t('Un seuil d’agrégat réduit certains risques de déduction. Il ne garantit pas l’anonymat.',
          'An aggregate threshold reduces some inference risks. It does not guarantee anonymity.')),
        const SizedBox(height: 16),
        TextField(controller: minimum, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: t('Taille minimale des groupes (2 à 100)', 'Minimum group size (2 to 100)'), border: const OutlineInputBorder())),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: FilledButton(
          onPressed: busy ? null : () { final value = int.tryParse(minimum.text); if (value == null || value < 2 || value > 100) { setState(() => error = t('Choisissez un nombre de 2 à 100.', 'Choose a number from 2 to 100.')); return; } save(() => widget.api.setMinimumAggregateSize(current.id, value)); },
          child: Text(t('Enregistrer le seuil', 'Save threshold')))),
        const SizedBox(height: 20),
        for (final format in current.formats) ...[
          Text(format.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          levelPicker(t('Format de données', 'Data format'), format.sensitivity,
            (level) => save(() => widget.api.setFormatSensitivity(current.id, format.id, level, format.version))),
          const SizedBox(height: 8),
          for (final field in format.fields) ...[
            levelPicker(field.name, defaultFieldSensitivity(field),
              (level) => save(() => widget.api.setFieldSensitivity(current.id, format.id, field.id, level, format.version))),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
        Text(t('Accès des membres', 'Member access'), style: Theme.of(context).textTheme.titleMedium),
        for (final member in current.members.where((item) => item.role != BrainyCollectionRole.owner))
          ExpansionTile(title: Text(member.name.isEmpty ? member.email : member.name),
            subtitle: Text(member.email), children: [
              for (final format in current.formats)
                for (final field in format.fields)
                  if (effectiveFieldSensitivity(format, field) != 'ORDINARY')
                    CheckboxListTile(
                      title: Text('${format.name} · ${field.name}'),
                      value: member.sensitiveFieldIds.contains(field.id),
                      onChanged: busy ? null : (allow) {
                        final ids = {...member.sensitiveFieldIds};
                        if (allow == true) { ids.add(field.id); } else { ids.remove(field.id); }
                        save(() => widget.api.addCollectionMember(current.id, member.email, member.role,
                          sharedFieldIds: member.sharedFieldIds, sensitiveFieldIds: ids.toList()));
                      },
                    ),
            ]),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 20),
        Text(t('Journal', 'Journal'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(t('Qui a demandé quelle analyse sensible, les refus et les alertes sur des questions répétées. Aucune valeur n’y figure.',
          'Who asked which sensitive analysis, the refusals and the alerts on repeated questions. No value is kept there.')),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
          key: const ValueKey('open-audit-log'),
          onPressed: () => showAuditLogScreen(context, widget.api, current, french: widget.french),
          icon: const Icon(Icons.history_rounded),
          label: Text(t('Ouvrir le journal', 'Open the journal')))),
      ]))),
  );
}
