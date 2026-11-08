// T32 — data sources of a collection: files feed one data format, with explained rejections.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'collections_api.dart';
import 'data_format_colors.dart';
import 'data_source_api.dart';
import 'data_source_form_page.dart';
import 'data_source_labels.dart';
import 'data_source_runs_view.dart';

Future<bool> showDataSourcesScreen(
  BuildContext context,
  CollectionsApi api,
  BrainyCollection collection,
  String userId, {
  required bool french,
}) async =>
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataSourcesScreen(
          api: api,
          collection: collection,
          userId: userId,
          french: french,
        ),
      ),
    ) ??
    false;

class DataSourcesScreen extends StatefulWidget {
  const DataSourcesScreen({
    super.key,
    required this.api,
    required this.collection,
    required this.userId,
    required this.french,
  });
  final CollectionsApi api;
  final BrainyCollection collection;
  final String userId;
  final bool french;
  @override
  State<DataSourcesScreen> createState() => _DataSourcesScreenState();
}

class _DataSourcesScreenState extends State<DataSourcesScreen> {
  late final DataSourceApi _api = DataSourceApi(widget.api);
  List<DataSource>? _sources;
  String? _error;
  String? _notice;
  String? _openId;
  int _refresh = 0;
  bool _busy = false;
  bool _changed = false;

  bool get fr => widget.french;
  BrainyCollectionRole get _role {
    if (widget.collection.ownerId == widget.userId) {
      return BrainyCollectionRole.owner;
    }
    for (final member in widget.collection.members) {
      if (member.userId == widget.userId) return member.role;
    }
    return BrainyCollectionRole.reader;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await _api.list(widget.collection.id);
      if (mounted) {
        setState(() {
          _sources = sources;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _sources ??= [];
          _error = dataSourceErrorText(error, fr);
        });
      }
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = dataSourceErrorText(error, fr));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([DataSource? source]) async {
    final input = await Navigator.push<DataSourceInput>(
      context,
      MaterialPageRoute(
        builder: (_) => DataSourceFormPage(
          collection: widget.collection,
          source: source,
          french: fr,
        ),
      ),
    );
    if (input == null) return;
    await _act(() async {
      final saved = await _api.save(
        widget.collection.id,
        input,
        sourceId: source?.id,
      );
      _openId = saved.id;
    });
  }

  Future<void> _send(DataSource source) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
    );
    if (file == null) return;
    await _act(() async {
      final bytes = await file.readAsBytes();
      if (bytes.length > maxDeliveryBytes) {
        throw Exception(
          dsTr(
            fr,
            'A delivery cannot exceed 4 MB. Split the file and send each part.',
            'Une livraison ne peut pas dépasser 4 Mo. Découpez le fichier et envoyez chaque partie.',
          ),
        );
      }
      final content = utf8.decode(bytes, allowMalformed: false);
      final json = file.name.toLowerCase().endsWith('.json');
      final run = await _api.upload(
        source.id,
        content,
        json ? 'application/json' : 'text/csv',
      );
      _openId = source.id;
      _refresh += 1;
      _changed = true;
      _notice = run.state == 'COMPLETED'
          ? dsTr(
              fr,
              'This file was already received; its delivery is shown below.',
              'Ce fichier a déjà été reçu ; sa livraison est affichée ci-dessous.',
            )
          : dsTr(
              fr,
              'File received. Brainy checks it row by row.',
              'Fichier reçu. Brainy le vérifie ligne par ligne.',
            );
    });
  }

  Future<void> _rotate(DataSource source) async {
    if (source.keyHint != null &&
        !await _confirm(
          dsTr(
            fr,
            'Create a new key? Systems using the current key will stop working.',
            'Créer une nouvelle clé ? Les systèmes qui utilisent la clé actuelle ne fonctionneront plus.',
          ),
        )) {
      return;
    }
    String? key;
    await _act(() async {
      key = await _api.rotateKey(source.id);
    });
    if (key != null && mounted) await _showKey(key!);
  }

  Future<void> _delete(DataSource source) async {
    if (!await _confirm(
      dsTr(
        fr,
        'Delete “${source.name}”? Its delivery history is removed; entries already written stay in the collection.',
        'Supprimer « ${source.name} » ? L’historique des livraisons est retiré ; les entrées déjà écrites restent dans la collection.',
      ),
    )) {
      return;
    }
    await _act(() => _api.remove(source.id));
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(dsTr(fr, 'Cancel', 'Annuler')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(dsTr(fr, 'Continue', 'Continuer')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showKey(String key) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(dsTr(fr, 'Sending key', 'Clé d’envoi')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dsTr(
              fr,
              'Copy this key now. It is shown only once. It can only send deliveries to this source; it cannot read any data.',
              'Copiez cette clé maintenant. Elle n’est affichée qu’une fois. Elle permet seulement d’envoyer des livraisons à cette source ; elle ne lit aucune donnée.',
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(key, style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Text(
            dsTr(
              fr,
              'Systems send with the pushDataSourceDelivery mutation; reuse a delivery ID to resend safely (120 deliveries per hour at most).',
              'Les systèmes envoient avec la mutation pushDataSourceDelivery ; réutilisez un identifiant de livraison pour renvoyer sans risque (120 livraisons par heure au plus).',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: key)),
          child: Text(dsTr(fr, 'Copy', 'Copier')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(dsTr(fr, 'Done', 'Terminé')),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = _role == BrainyCollectionRole.owner;
    final canSend = _role != BrainyCollectionRole.reader;
    final sources = _sources;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(dsTr(fr, 'Data sources', 'Sources de données')),
        ),
        floatingActionButton: isOwner && (sources?.isNotEmpty ?? false)
            ? FloatingActionButton.extended(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: Text(dsTr(fr, 'New data source', 'Nouvelle source')),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  dsTr(
                    fr,
                    'Feed a data format from CSV or JSON files, or from another system with a key. Brainy keeps the fact date, never adds a record twice and explains every rejected row.',
                    'Alimentez un format de données avec des fichiers CSV ou JSON, ou depuis un autre système avec une clé. Brainy garde la date du fait, n’ajoute jamais deux fois un enregistrement et explique chaque ligne rejetée.',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dsTr(
                    fr,
                    'Up to 10,000 rows and 4 MB per delivery. This is not a real-time or certified industrial pipeline.',
                    'Jusqu’à 10 000 lignes et 4 Mo par livraison. Ce n’est pas une chaîne industrielle temps réel ni certifiée.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(liveRegion: true, child: Text(_notice!)),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (sources == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (sources.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.dataset_linked_outlined,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            dsTr(
                              fr,
                              'No data source yet',
                              'Aucune source de données',
                            ),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isOwner
                                ? dsTr(
                                    fr,
                                    'Describe which file columns fill which fields, then send a first file.',
                                    'Indiquez quelles colonnes du fichier remplissent quels champs, puis envoyez un premier fichier.',
                                  )
                                : dsTr(
                                    fr,
                                    'The collection owner can set up a data source. You can then send files to it.',
                                    'Le propriétaire de la collection peut créer une source de données. Vous pourrez ensuite y envoyer des fichiers.',
                                  ),
                            textAlign: TextAlign.center,
                          ),
                          if (isOwner) ...[
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _busy ? null : () => _edit(),
                              child: Text(
                                dsTr(
                                  fr,
                                  'Create a data source',
                                  'Créer une source de données',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  for (final source in sources)
                    _sourceCard(context, source, isOwner, canSend),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceCard(
    BuildContext context,
    DataSource source,
    bool isOwner,
    bool canSend,
  ) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final format = widget.collection.formats
        .where((item) => item.id == source.formatId)
        .firstOrNull;
    final open = _openId == source.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (format != null) ...[
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: DataFormatColors.marker(
                                  format.color,
                                  dark,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Text(
                              format.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text('·'),
                          ],
                          Text(
                            dsTr(
                              fr,
                              '${source.mappings.length} columns · ID column “${source.recordIdColumn}”',
                              '${source.mappings.length} colonnes · identifiant « ${source.recordIdColumn} »',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        source.keyHint != null
                            ? dsTr(
                                fr,
                                'Sending key active (…${source.keyHint})',
                                'Clé d’envoi active (…${source.keyHint})',
                              )
                            : dsTr(fr, 'No sending key', 'Aucune clé d’envoi'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    tooltip: dsTr(
                      fr,
                      'Manage data source',
                      'Gérer la source de données',
                    ),
                    enabled: !_busy,
                    onSelected: (value) => switch (value) {
                      'edit' => _edit(source),
                      'key' => _rotate(source),
                      'revoke' => _act(() => _api.revokeKey(source.id)),
                      _ => _delete(source),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          dsTr(
                            fr,
                            'Edit mapping',
                            'Modifier la correspondance',
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'key',
                        child: Text(
                          source.keyHint != null
                              ? dsTr(
                                  fr,
                                  'Replace sending key',
                                  'Remplacer la clé d’envoi',
                                )
                              : dsTr(
                                  fr,
                                  'Create sending key',
                                  'Créer une clé d’envoi',
                                ),
                        ),
                      ),
                      if (source.keyHint != null)
                        PopupMenuItem(
                          value: 'revoke',
                          child: Text(
                            dsTr(fr, 'Revoke key', 'Révoquer la clé'),
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          dsTr(fr, 'Delete source', 'Supprimer la source'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canSend)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _send(source),
                    icon: const Icon(Icons.upload_file),
                    label: Text(dsTr(fr, 'Send a file', 'Envoyer un fichier')),
                  ),
                OutlinedButton(
                  onPressed: () =>
                      setState(() => _openId = open ? null : source.id),
                  child: Text(
                    open
                        ? dsTr(fr, 'Hide deliveries', 'Masquer les livraisons')
                        : dsTr(fr, 'Deliveries', 'Livraisons'),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: open
                  ? DataSourceRunsView(
                      key: ValueKey('${source.id}-$_refresh'),
                      api: _api,
                      sourceId: source.id,
                      french: fr,
                      onFinished: () => _changed = true,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
