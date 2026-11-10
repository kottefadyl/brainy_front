import 'analysis_operations.dart';
import 'package:flutter/material.dart';

import 'collections_api.dart';

/// The privacy journal (T43/3): the last sensitive reads, refusals and
/// alerts of a collection. Same wording as `lib/audit-log-labels.ts`.
const _labels = <String, List<String>>{
  'READ_SENSITIVE_AGGREGATE': ['Sensitive analysis served', 'Analyse sensible servie'],
  'REFUSED_SENSITIVE_AGGREGATE': ['Sensitive analysis refused', 'Analyse sensible refusée'],
  'SENSITIVE_AGGREGATE_ALERT': ['Alert: repeated sensitive queries', 'Alerte : requêtes sensibles répétées'],
  'READ_PROTECTED_DATA': ['Protected values read', 'Valeurs protégées lues'],
  'SHARE_PROTECTED_FIELDS': ['Protected fields shared', 'Champs protégés partagés'],
  'EXPORT_PROTECTED_DATA': ['Protected values exported', 'Valeurs protégées exportées'],
  'SET_SENSITIVITY': ['Sensitivity level changed', 'Niveau de sensibilité modifié'],
  'SET_AGGREGATE_MINIMUM': ['Minimum group size changed', 'Taille minimale des groupes modifiée'],
  'REVOKE_MEMBER': ['Member removed', 'Membre retiré'],
};
const _reasons = <String, List<String>>{
  'DIFFERENCING': ['the same question returned totals that differ by fewer observations than the threshold', 'la même question a donné des totaux qui diffèrent de moins d’observations que le seuil'],
  'BURST': ['the same question was asked many times within an hour', 'la même question a été posée de nombreuses fois en une heure'],
  'PROBING': ['several sensitive analyses were refused within an hour', 'plusieurs analyses sensibles ont été refusées en une heure'],
};

bool isPrivacyAction(String action) => _labels.containsKey(action);

String auditActionLabel(String action, {required bool french}) {
  final known = _labels[action];
  return known != null ? known[french ? 1 : 0] : action.toLowerCase().replaceAll('_', ' ');
}

/// The alert reason in plain words; other details lose the technical query key.
String auditDetailText(BrainyAuditLog log, {required bool french}) {
  final details = log.details ?? '';
  if (log.action == 'SENSITIVE_AGGREGATE_ALERT') {
    final reason = _reasons[details.split(':').first];
    if (reason != null) return reason[french ? 1 : 0];
  }
  // "operation X; observations N" becomes "Average · 57 observations" in the person's language.
  final rest = details.replaceFirst(RegExp(r';?\s*query [0-9a-f]{16}'), '').replaceFirst(RegExp(r'^Data format [^;]+;\s*'), '').trim();
  return rest.split(RegExp(r';\s*')).where((part) => part.isNotEmpty).map((part) {
    final operation = RegExp(r'^operation (\w+)$').firstMatch(part);
    if (operation != null) return analysisOperationLabel(operation[1]!, french: french);
    final observations = RegExp(r'^observations (\d+)$').firstMatch(part);
    if (observations != null) return '${observations[1]} observation${observations[1] == '1' ? '' : 's'}';
    final refused = RegExp(r'^refused: (.*)$').firstMatch(part);
    if (refused != null) return '${french ? 'refusée : ' : 'refused: '}${refused[1]}';
    return part;
  }).join(' · ');
}

String auditActor(BrainyAuditLog log, BrainyCollection collection, {required bool french}) {
  for (final member in collection.members) {
    if (member.userId == log.userId) return member.name.isEmpty ? member.email : member.name;
  }
  if (collection.ownerId == log.userId) return french ? 'Propriétaire' : 'Owner';
  return french ? 'Membre' : 'Member';
}

Future<void> showAuditLogScreen(BuildContext context, CollectionsApi api, BrainyCollection collection, {required bool french}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuditLogScreen(api: api, collection: collection, french: french)));

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, required this.api, required this.collection, required this.french});
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool french;
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<BrainyAuditLog>? logs;
  bool all = false;
  bool busy = false;
  String? error;
  String t(String fr, String en) => widget.french ? fr : en;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final result = await widget.api.collectionAuditLogs(widget.collection.id);
      if (mounted) setState(() { logs = result; busy = false; });
    } catch (cause) {
      if (mounted) setState(() { error = '$cause'; busy = false; });
    }
  }

  String when(DateTime at) {
    final local = at.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: widget.french);
    return '${MaterialLocalizations.of(context).formatMediumDate(local)} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = (logs ?? const <BrainyAuditLog>[]).where((log) => all || isPrivacyAction(log.action)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Journal des analyses sensibles', 'Sensitive analysis journal')),
        actions: [IconButton(tooltip: t('Actualiser', 'Refresh'), onPressed: busy ? null : load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(t('Les 100 derniers événements. Le journal ne contient aucune valeur : seulement qui a demandé quoi, et les alertes sur des questions répétées. Ces alertes ne bloquent rien.',
            'The last 100 events. The journal holds no value: only who asked what, and alerts on repeated questions. These alerts block nothing.'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          SwitchListTile(
            key: const ValueKey('audit-log-all'),
            contentPadding: EdgeInsets.zero,
            title: Text(t('Tout le journal', 'Whole journal')),
            value: all,
            onChanged: (next) => setState(() => all = next),
          ),
          if (busy && logs == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (error != null) Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          if (logs != null && shown.isEmpty && error == null) Text(t('Aucun événement.', 'No events.'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          for (final log in shown)
            Card(
              key: ValueKey('audit-log-${log.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: log.action == 'SENSITIVE_AGGREGATE_ALERT' ? theme.colorScheme.error : theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.spaceBetween, children: [
                    Text(auditActionLabel(log.action, french: widget.french), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(when(log.occurredAt), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  Builder(builder: (context) {
                    final detail = auditDetailText(log, french: widget.french);
                    return Text('${auditActor(log, widget.collection, french: widget.french)}${detail.isEmpty ? '' : ' · $detail'}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14));
                  }),
                ]),
              ),
            ),
        ]))),
    );
  }
}
