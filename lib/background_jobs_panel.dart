import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'collections_api.dart';

class BackgroundJobsPanel extends StatefulWidget {
  const BackgroundJobsPanel({
    super.key,
    required this.api,
    required this.collections,
  });
  final CollectionsApi api;
  final List<BrainyCollection> collections;
  @override
  State<BackgroundJobsPanel> createState() => _BackgroundJobsPanelState();
}

class _BackgroundJobsPanelState extends State<BackgroundJobsPanel> {
  String? collectionId, formatId, error, notice;
  List<Map<String, dynamic>> jobs = [];
  Map<String, dynamic>? importPayload;
  final limit = TextEditingController(text: '5000');
  Timer? timer;
  bool busy = false;
  bool includeSensitive = false;

  BrainyCollection? get collection {
    if (widget.collections.isEmpty) return null;
    for (final item in widget.collections) {
      if (item.id == collectionId) return item;
    }
    return widget.collections.first;
  }

  String? get chosenFormatId {
    final formats = collection?.formats ?? [];
    if (formats.isEmpty) return null;
    for (final item in formats) {
      if (item.id == formatId) return item.id;
    }
    return formats.first.id;
  }

  @override
  void dispose() {
    timer?.cancel();
    limit.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final id = collection?.id;
    if (id == null) return;
    try {
      final result = await widget.api.backgroundJobs(id);
      if (mounted && collection?.id == id) {
        setState(() {
          jobs = result;
          error = null;
        });
      }
      _poll();
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    }
  }

  bool open = false;
  bool get working => jobs.any((job) => job['state'] == 'QUEUED' || job['state'] == 'RUNNING');

  /// Polls every 3 s only while the panel is open and a job is queued or running: an idle panel uses no data.
  void _poll() {
    if (!mounted || !open || !working) {
      timer?.cancel();
      timer = null;
    } else {
      timer ??= Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    }
  }

  void expanded(bool value) {
    open = value;
    timer?.cancel();
    timer = null;
    if (value) refresh();
  }

  Future<void> run(Future<Map<String, dynamic>> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final job = await action();
      if (mounted) {
        setState(() {
          jobs = [job, ...jobs.where((item) => item['id'] != job['id'])];
        });
      }
      _poll();
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String requestKey() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<void> downloadTemplate(bool fr) async {
    final selected = collection;
    final format = selected?.formats
        .where((item) => item.id == chosenFormatId)
        .firstOrNull;
    if (format == null || format.fields.isEmpty) return;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'formatId': format.id,
      'rows': [
        {
          'sourceId': 'row-1',
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'values': [
            {
              'fieldId': format.fields.first.id,
              'value': fr ? 'Exemple' : 'Example',
            },
          ],
        },
      ],
    };
    await FilePicker.saveFile(
      fileName: 'brainy-import-template.json',
      bytes: Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
      ),
    );
  }

  Future<void> chooseImport(bool fr) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2000000) {
        throw FormatException(
          fr
              ? 'Fichier trop volumineux (2 Mo maximum)'
              : 'File is too large (2 MB maximum)',
        );
      }
      final parsed = jsonDecode(utf8.decode(bytes));
      if (parsed is! Map<String, dynamic> ||
          parsed['formatId'] is! String ||
          parsed['rows'] is! List) {
        throw FormatException(
          fr
              ? 'Le fichier doit contenir formatId et rows'
              : 'The file must contain formatId and rows',
        );
      }
      if (mounted) {
        setState(() {
          importPayload = parsed;
          error = null;
          notice = file.name;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    }
  }

  Future<void> download(Map<String, dynamic> job, bool fr) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final detail = await widget.api.backgroundJob(job['id'] as String);
      final result = detail['result'] as String?;
      if (result == null) {
        throw FormatException(
          fr ? 'Résultat indisponible' : 'Result is unavailable',
        );
      }
      await FilePicker.saveFile(
        fileName:
            'brainy-${(job['kind'] as String).toLowerCase()}-${job['id']}.json',
        bytes: Uint8List.fromList(utf8.encode(result)),
      );
    } catch (cause) {
      if (mounted) setState(() => error = '$cause');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fr = AppStrings.of(context).isFrench;
    final selected = collection;
    final states = fr
        ? {
            'QUEUED': 'En attente',
            'RUNNING': 'En cours',
            'COMPLETED': 'Terminée',
            'CANCELLED': 'Annulée',
            'FAILED': 'Échec',
          }
        : {
            'QUEUED': 'Queued',
            'RUNNING': 'Running',
            'COMPLETED': 'Completed',
            'CANCELLED': 'Cancelled',
            'FAILED': 'Failed',
          };
    return Card(
      child: ExpansionTile(
        onExpansionChanged: expanded,
        title: Text(fr ? 'Traitements en arrière-plan' : 'Background tasks'),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          Text(
            fr
                ? 'Les imports continuent par lots. Revenez ici pour suivre leur progression.'
                : 'Imports continue in batches. Return here to check progress.',
          ),
          const SizedBox(height: 8),
          if (selected != null) ...[
            DropdownButtonFormField<String>(isExpanded: true, 
              key: ValueKey('jobs-collection-${selected.id}'),
              initialValue: selected.id,
              decoration: InputDecoration(
                labelText: fr ? 'Collection' : 'Collection',
              ),
              items: [
                for (final item in widget.collections)
                  DropdownMenuItem(value: item.id, child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) {
                setState(() {
                  collectionId = value;
                  formatId = null;
                  importPayload = null;
                  jobs = [];
                });
                refresh();
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: chosenFormatId == null
                  ? null
                  : () => downloadTemplate(fr),
              child: Text(
                fr ? 'Télécharger un modèle JSON' : 'Download a JSON template',
              ),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => chooseImport(fr),
              child: Text(
                fr
                    ? 'Choisir un fichier de lots JSON (2 Mo)'
                    : 'Choose JSON batch file (2 MB)',
              ),
            ),
            if (importPayload != null)
              FilledButton(
                onPressed: busy
                    ? null
                    : () => run(
                        () => widget.api.startBackgroundJob(
                          selected.id,
                          'IMPORT',
                          importPayload!,
                          requestKey(),
                        ),
                      ),
                child: Text(fr ? 'Lancer l’import' : 'Start import'),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(isExpanded: true, 
              key: ValueKey('jobs-format-${selected.id}'),
              initialValue: chosenFormatId,
              decoration: InputDecoration(
                labelText: fr
                    ? 'Format de données à exporter'
                    : 'Data format to export',
              ),
              items: [
                for (final item in selected.formats)
                  DropdownMenuItem(value: item.id, child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => formatId = value),
            ),
            TextField(
              controller: limit,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: fr
                    ? 'Entrées maximum (1 à 5 000)'
                    : 'Maximum entries (1 to 5,000)',
              ),
            ),
            CheckboxListTile(value: includeSensitive, contentPadding: EdgeInsets.zero,
              title: Text(fr ? 'Inclure explicitement les données personnelles et sensibles' : 'Explicitly include personal and sensitive data'),
              onChanged: busy ? null : (value) => setState(() => includeSensitive = value ?? false)),
            OutlinedButton(
              onPressed: busy || chosenFormatId == null
                  ? null
                  : () => run(
                      () =>
                          widget.api.startBackgroundJob(selected.id, 'EXPORT', {
                            'formatId': chosenFormatId,
                            'limit': int.tryParse(limit.text) ?? 0,
                            'includeSensitive': includeSensitive,
                          }, requestKey()),
                    ),
              child: Text(fr ? 'Préparer l’export' : 'Prepare export'),
            ),
          ],
          if (jobs.isEmpty)
            Text(
              fr
                  ? 'Aucun traitement récent dans cette collection.'
                  : 'No recent tasks in this collection.',
            ),
          for (final job in jobs)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${job['kind']} · ${states[job['state']] ?? job['state']}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text('${job['processed']} / ${job['total']}'),
                    LinearProgressIndicator(
                      value:
                          ((job['processed'] as num).toDouble() /
                                  ((job['total'] as num).toDouble().clamp(
                                    1,
                                    double.infinity,
                                  )))
                              .clamp(0, 1),
                    ),
                    if (job['kind'] == 'IMPORT')
                      Text(
                        '${job['createdCount']} ${fr ? 'créées' : 'created'} · ${job['skippedCount']} ${fr ? 'déjà présentes' : 'already present'} · ${job['errorCount']} ${fr ? 'erreurs' : 'errors'}',
                      ),
                    if (job['failure'] != null)
                      Text(
                        '${job['failure']}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if ((job['logs'] as List<dynamic>).isNotEmpty)
                      ExpansionTile(
                        title: Text(
                          '${fr ? 'Erreurs par ligne' : 'Row errors'} (${(job['logs'] as List<dynamic>).length})',
                        ),
                        children: [
                          for (final log in job['logs'] as List<dynamic>)
                            ListTile(
                              title: Text(
                                '${fr ? 'Ligne' : 'Row'} ${log['row']}: ${log['message']}',
                              ),
                            ),
                        ],
                      ),
                    Wrap(runSpacing: 8, 
                      spacing: 8,
                      children: [
                        if (job['state'] == 'QUEUED' ||
                            job['state'] == 'RUNNING')
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => run(
                                    () => widget.api.cancelBackgroundJob(
                                      job['id'] as String,
                                    ),
                                  ),
                            child: Text(fr ? 'Annuler' : 'Cancel'),
                          ),
                        if (job['state'] == 'CANCELLED' ||
                            job['state'] == 'FAILED')
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => run(
                                    () => widget.api.resumeBackgroundJob(
                                      job['id'] as String,
                                    ),
                                  ),
                            child: Text(fr ? 'Reprendre' : 'Resume'),
                          ),
                        if (job['state'] == 'COMPLETED')
                          OutlinedButton(
                            onPressed: busy ? null : () => download(job, fr),
                            child: Text(
                              fr
                                  ? 'Télécharger le résultat'
                                  : 'Download result',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (notice != null) Text(notice!),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
