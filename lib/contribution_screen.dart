import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'adaptive_form.dart';
import 'collections_api.dart';
import 'contribution_api.dart';

Future<bool> showContributionScreen(
  BuildContext context,
  CollectionsApi api,
  BrainyCollection collection, {
  required bool french,
}) async =>
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContributionScreen(
          api: api,
          collection: collection,
          french: french,
        ),
      ),
    ) ??
    false;

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({
    super.key,
    required this.api,
    required this.collection,
    required this.french,
  });
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool french;
  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  static const _supported = {
    'TITLE',
    'TEXT',
    'LONG_TEXT',
    'DATE',
    'TIME',
    'NUMBER',
    'BOOLEAN',
    'SELECT',
    'LINK',
    'CHARACTER',
    'DURATION',
  };
  static const _configuredWebBase = String.fromEnvironment('WEB_APP_URL');
  String get _webBase => _configuredWebBase.isNotEmpty
      ? _configuredWebBase
      : defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3001'
      : 'http://localhost:3001';
  final _titleEn = TextEditingController();
  final _titleFr = TextEditingController();
  final _consentEn = TextEditingController();
  final _consentFr = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late String formatId = widget.collection.formats
      .firstWhere(
        (format) => !format.objectModel && format.workflow == null,
        orElse: () => widget.collection.formats.first,
      )
      .id;
  final selected = <String>{};
  DateTime expiry = DateTime.now().add(const Duration(days: 7));
  bool anonymous = true;
  bool busy = false;
  bool changed = false;
  String? error;
  String? createdUrl;
  List<Map<String, dynamic>> links = [];
  List<Map<String, dynamic>> submissions = [];
  String t(String fr, String en) => widget.french ? fr : en;
  String message(Object cause) {
    final raw = '$cause';
    if (!widget.french) return raw;
    const translated = <String, String>{
      'Contribution link unavailable': 'Ce lien de contribution est indisponible ou expiré.',
      'Too many submissions or link unavailable': 'Trop de réponses. Réessayez dans une minute.',
      'Consent is required': 'Le consentement est nécessaire.',
      'Submission is too large or empty': 'La réponse est vide ou trop volumineuse.',
      'Valid contact email required': 'Une adresse e-mail de contact valide est nécessaire.',
      'Invalid public field': 'Un champ public n’est plus disponible.',
      'Choose valid public fields': 'Choisissez des champs publics valides.',
      'Expiry must be within 90 days': 'Choisissez une expiration dans les 90 prochains jours.',
      'Submission already reviewed': 'Cette réponse a déjà été examinée.',
      'Duplicate target not found': 'La réponse indiquée comme doublon est introuvable.',
      'Only the collection owner can manage contributions': 'Seul le propriétaire peut gérer les contributions.',
    };
    for (final item in translated.entries) { if (raw.contains(item.key)) return item.value; }
    return raw;
  }
  String statusLabel(String status) => switch (status) {
    'PENDING' || 'ACCEPTING' => t('En attente', 'Pending'),
    'ACCEPTED' => t('Acceptée', 'Accepted'),
    'REJECTED' => t('Rejetée', 'Rejected'),
    _ => status,
  };
  String eventLabel(String kind) => switch (kind) {
    'RECEIVED' => t('Reçue', 'Received'),
    'CORRECTED' => t('Corrigée', 'Corrected'),
    'ACCEPTED' => t('Acceptée', 'Accepted'),
    'REJECTED' => t('Rejetée', 'Rejected'),
    'DUPLICATE_REJECTED' => t('Rejetée comme doublon', 'Rejected as duplicate'),
    _ => kind,
  };
  BrainyFormat get format =>
      widget.collection.formats.firstWhere((item) => item.id == formatId);
  List<BrainyField> get fields => format.fields
      .where((field) => _supported.contains(field.kind.wireName))
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleEn.dispose();
    _titleFr.dispose();
    _consentEn.dispose();
    _consentFr.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.api.contributionLinks(widget.collection.id),
        widget.api.contributionSubmissions(widget.collection.id),
      ]);
      if (mounted) {
        setState(() {
          links = results[0];
          submissions = results[1];
          error = null;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = message(cause));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await _load();
    } catch (cause) {
      if (mounted) setState(() => error = message(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _date(String? iso) {
    final date = DateTime.tryParse(iso ?? '')?.toLocal();
    return date == null
        ? ''
        : '${MaterialLocalizations.of(context).formatMediumDate(date)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate() || selected.isEmpty) {
      setState(
        () => error = t(
          'Choisissez au moins un champ.',
          'Choose at least one field.',
        ),
      );
      return;
    }
    await _run(() async {
      final result = await widget.api.createContributionLink(
        widget.collection.id,
        {
          'formatId': formatId,
          'fieldIds': selected.toList(),
          'titleEn': _titleEn.text,
          'titleFr': _titleFr.text,
          'consentEn': _consentEn.text,
          'consentFr': _consentFr.text,
          'allowAnonymous': anonymous,
          'expiresAt': DateTime(
            expiry.year,
            expiry.month,
            expiry.day,
            23,
            59,
            59,
          ).toUtc().toIso8601String(),
        },
      );
      if (mounted) {
        setState(() => createdUrl = '$_webBase/contribute/${result['token']}');
      }
    });
  }

  Future<void> _correct(Map<String, dynamic> row) async {
    final rowFormat = widget.collection.formats.firstWhere(
      (item) => item.id == row['formatId'],
    );
    final values = (row['values'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final controllers = {
      for (final value in values)
        value['fieldId'] as String: TextEditingController(
          text: value['value'] as String? ?? '',
        ),
    };
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AdaptiveFormDialog(
        title: Text(t('Corriger la réponse', 'Correct submission')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: item.value,
                        decoration: InputDecoration(
                          labelText:
                              rowFormat.fields
                                  .where((field) => field.id == item.key)
                                  .firstOrNull
                                  ?.name ??
                              item.key,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Enregistrer', 'Save')),
          ),
        ],
      ),
    );
    if (apply == true) {
      await _run(
        () => widget.api.correctContribution(
          row['id'] as String,
          controllers.entries
              .where((item) => item.value.text.trim().isNotEmpty)
              .map(
                (item) => {
                  'fieldId': item.key,
                  'value':
                      rowFormat.fields.any(
                        (field) =>
                            field.id == item.key &&
                            field.kind.wireName == 'NUMBER',
                      )
                      ? item.value.text.trim().replaceFirst(',', '.')
                      : item.value.text.trim(),
                },
              )
              .toList(),
        ),
      );
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final controller = TextEditingController();
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AdaptiveFormDialog(
        title: Text(t('Rejeter la réponse', 'Reject submission')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: t(
              'ID du doublon (facultatif)',
              'Duplicate ID (optional)',
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Rejeter', 'Reject')),
          ),
        ],
      ),
    );
    if (apply == true) {
      await _run(
        () => widget.api.reviewContribution(
          row['id'] as String,
          'REJECT',
          duplicateOf: controller.text.trim().isEmpty
              ? null
              : controller.text.trim(),
        ),
      );
    }
    controller.dispose();
  }

  Future<void> _erase(Map<String, dynamic> row) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t('Effacer les données du répondant ?', 'Erase respondent data?'),
        ),
        content: Text(
          t(
            'La réponse et toute entrée acceptée seront supprimées.',
            'The response and any accepted entry will be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Annuler', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Effacer', 'Erase')),
          ),
        ],
      ),
    );
    if (approved == true) {
      await _run(() => widget.api.eraseContribution(row['id'] as String));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formats = widget.collection.formats
        .where((item) => !item.objectModel && item.workflow == null)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Contributions publiques', 'Public contributions')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t(
                'Les réponses attendent votre validation avant de devenir des entrées.',
                'Responses wait for your review before becoming entries.',
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Créer un lien', 'Create a link'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (formats.isEmpty)
                        Text(
                          t(
                            'Créez un format de données ordinaire.',
                            'Create an ordinary data format first.',
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(isExpanded: true, 
                          initialValue: formatId,
                          decoration: InputDecoration(
                            labelText: t('Format de données', 'Data format'),
                          ),
                          items: formats
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            formatId = value ?? formatId;
                            selected.clear();
                          }),
                        ),
                      const SizedBox(height: 12),
                      Text(t('Champs à collecter', 'Fields to collect')),
                      ...fields.map(
                        (field) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(field.name),
                          value: selected.contains(field.id),
                          onChanged: (value) => setState(
                            () => value == true
                                ? selected.add(field.id)
                                : selected.remove(field.id),
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: _titleEn,
                        maxLength: 2000, buildCounter: quietFormCounter,
                        decoration: const InputDecoration(
                          labelText: 'Information (English)',
                        ),
                        validator: (value) => value?.trim().isNotEmpty == true
                            ? null
                            : t('Requis', 'Required'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleFr,
                        maxLength: 2000, buildCounter: quietFormCounter,
                        decoration: const InputDecoration(
                          labelText: 'Information (français)',
                        ),
                        validator: (value) => value?.trim().isNotEmpty == true
                            ? null
                            : t('Requis', 'Required'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _consentEn,
                        maxLength: 2000, buildCounter: quietFormCounter,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Consent (English)',
                        ),
                        validator: (value) => value?.trim().isNotEmpty == true
                            ? null
                            : t('Requis', 'Required'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _consentFr,
                        maxLength: 2000, buildCounter: quietFormCounter,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Consentement (français)',
                        ),
                        validator: (value) => value?.trim().isNotEmpty == true
                            ? null
                            : t('Requis', 'Required'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t(
                            'Autoriser les réponses anonymes',
                            'Allow anonymous replies',
                          ),
                        ),
                        value: anonymous,
                        onChanged: (value) => setState(() => anonymous = value),
                      ),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: expiry,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 90),
                                  ),
                                );
                                if (date != null) setState(() => expiry = date);
                              },
                        icon: const Icon(Icons.event),
                        label: Text(
                          '${t('Expire le', 'Expires on')} ${MaterialLocalizations.of(context).formatMediumDate(expiry)}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: busy || formats.isEmpty ? null : _create,
                        child: Text(t('Créer le lien', 'Create link')),
                      ),
                      if (createdUrl != null) ...[
                        const SizedBox(height: 12),
                        SelectableText(createdUrl!),
                        Text(
                          t(
                            'Copiez ce lien maintenant. Il n’est affiché qu’une fois.',
                            'Copy this link now. It is shown only once.',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: createdUrl!),
                          ),
                          icon: const Icon(Icons.copy),
                          label: Text(t('Copier', 'Copy')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('Liens', 'Links'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (links.isEmpty)
              Text(t('Aucun lien pour le moment.', 'No links yet.')),
            ...links.map(
              (link) => Card(
                child: ListTile(
                  title: Text(
                    widget.collection.formats
                            .where((item) => item.id == link['formatId'])
                            .firstOrNull
                            ?.name ??
                        '',
                  ),
                  subtitle: Text(
                    '${_date(link['expiresAt'] as String?)} · ${link['revokedAt'] == null ? t('Actif', 'Active') : t('Révoqué', 'Revoked')}',
                  ),
                  trailing: link['revokedAt'] == null
                      ? TextButton(
                          onPressed: busy
                              ? null
                              : () => _run(
                                  () => widget.api.revokeContributionLink(
                                    link['id'] as String,
                                  ),
                                ),
                          child: Text(t('Révoquer', 'Revoke')),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('Réponses', 'Submissions'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: submissions.isEmpty
                      ? null
                      : () => Clipboard.setData(
                          ClipboardData(text: jsonEncode(submissions)),
                        ),
                  icon: const Icon(Icons.copy),
                  label: Text(t('Copier JSON', 'Copy JSON')),
                ),
              ],
            ),
            if (submissions.isEmpty)
              Text(t('Aucune réponse pour le moment.', 'No submissions yet.')),
            ...submissions.map(
              (row) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${statusLabel(row['status'] as String)} · ${_date(row['receivedAt'] as String?)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (row['respondentEmail'] != null)
                        SelectableText(row['respondentEmail'] as String),
                      SelectableText('ID: ${row['id']}'),
                      ...((row['values'] as List<dynamic>)
                              .cast<Map<String, dynamic>>())
                          .map(
                            (value) => Text(
                              '${widget.collection.formats.where((item) => item.id == row['formatId']).firstOrNull?.fields.where((field) => field.id == value['fieldId']).firstOrNull?.name ?? value['fieldId']}: ${value['value']}',
                            ),
                          ),
                      if (row['status'] == 'PENDING' ||
                          row['status'] == 'ACCEPTING')
                        Wrap(runSpacing: 8, 
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => _run(() async {
                                      await widget.api.reviewContribution(
                                        row['id'] as String,
                                        'ACCEPT',
                                      );
                                      changed = true;
                                    }),
                              child: Text(t('Accepter', 'Accept')),
                            ),
                            OutlinedButton(
                              onPressed: busy || row['status'] != 'PENDING'
                                  ? null
                                  : () => _correct(row),
                              child: Text(t('Corriger', 'Correct')),
                            ),
                            OutlinedButton(
                              onPressed: busy || row['status'] != 'PENDING'
                                  ? null
                                  : () => _reject(row),
                              child: Text(t('Rejeter', 'Reject')),
                            ),
                          ],
                        ),
                      TextButton(
                        onPressed: busy ? null : () => _erase(row),
                        child: Text(
                          t('Effacer les données', 'Erase respondent data'),
                        ),
                      ),
                      ExpansionTile(
                        title: Text(t('Journal', 'Journal')),
                        children:
                            ((row['events'] as List<dynamic>)
                                    .cast<Map<String, dynamic>>())
                                .map(
                                  (event) => ListTile(
                                    title: Text(eventLabel(event['kind'] as String)),
                                    subtitle: Text(
                                      _date(event['at'] as String?),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
