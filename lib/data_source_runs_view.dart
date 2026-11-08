// T32 — deliveries of one data source: progress, measured results, explained rejections and repair.
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_source_api.dart';
import 'data_source_labels.dart';

class DataSourceRunsView extends StatefulWidget {
  const DataSourceRunsView({
    super.key,
    required this.api,
    required this.sourceId,
    required this.french,
    required this.onFinished,
  });
  final DataSourceApi api;
  final String sourceId;
  final bool french;
  final VoidCallback onFinished;
  @override
  State<DataSourceRunsView> createState() => _DataSourceRunsViewState();
}

class _DataSourceRunsViewState extends State<DataSourceRunsView> {
  List<DataSourceRun>? _runs;
  final _details = <String, DataSourceRun>{};
  String? _error;
  bool _busy = false;
  Timer? _timer;
  bool get fr => widget.french;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final runs = await widget.api.runs(widget.sourceId);
      if (!mounted) return;
      final wasActive = _runs?.any((run) => run.active) ?? false;
      final active = runs.any((run) => run.active);
      if (wasActive && !active) widget.onFinished();
      setState(() {
        _runs = runs;
        _error = null;
      });
      _timer?.cancel();
      if (active) _timer = Timer(const Duration(seconds: 2), _load);
    } catch (error) {
      if (mounted) setState(() => _error = dataSourceErrorText(error, fr));
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
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

  Future<void> _download(DataSourceRun run) => _act(() async {
    final csv = await widget.api.rejectionsCsv(run.id);
    await FilePicker.saveFile(
      fileName: 'brainy-rejected-rows-${run.id}.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
  });

  String _lag(int seconds) {
    if (seconds < 120) return '$seconds s';
    if (seconds < 7200) return '${(seconds / 60).toStringAsFixed(1)} min';
    if (seconds < 172800) return '${(seconds / 3600).toStringAsFixed(1)} h';
    return '${(seconds / 86400).toStringAsFixed(1)} ${dsTr(fr, 'days', 'jours')}';
  }

  String _number(num value) {
    final text = value is double
        ? value.toStringAsFixed(value >= 100 ? 0 : 1)
        : value.toString();
    final parts = text.split('.');
    final grouped = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => fr ? ' ' : ',',
    );
    return parts.length > 1 ? '$grouped${fr ? ',' : '.'}${parts[1]}' : grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runs = _runs;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final localizations = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          if (_error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  child: Text(dsTr(fr, 'Retry', 'Réessayer')),
                ),
              ],
            ),
          if (runs == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (runs != null && runs.isEmpty)
            Text(
              dsTr(
                fr,
                'No delivery yet. Send a file to start.',
                'Aucune livraison pour le moment. Envoyez un fichier pour commencer.',
              ),
              style: muted,
            ),
          for (final run in runs ?? const <DataSourceRun>[])
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        runStateLabel(run.state, fr),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: run.state == 'FAILED'
                              ? theme.colorScheme.error
                              : run.active
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                      Text(switch (run.origin) {
                        'PUSH' => dsTr(
                          fr,
                          'Sent with the key',
                          'Envoyé avec la clé',
                        ),
                        'RETRY' => dsTr(
                          fr,
                          'Rejected rows retried',
                          'Lignes rejetées relancées',
                        ),
                        _ => dsTr(fr, 'File sent', 'Fichier envoyé'),
                      }),
                      Text(
                        '${dsTr(fr, 'Received', 'Reçue')} ${localizations.formatMediumDate(run.receivedAt)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(run.receivedAt))}',
                        style: muted,
                      ),
                    ],
                  ),
                  if (run.active)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        value: run.total == 0
                            ? null
                            : run.processed / run.total,
                        semanticsLabel: dsTr(
                          fr,
                          'Delivery progress',
                          'Progression de la livraison',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _count(
                        dsTr(fr, 'Rows', 'Lignes'),
                        '${_number(run.processed)} / ${_number(run.total)}',
                        muted,
                      ),
                      _count(
                        dsTr(fr, 'Created', 'Créées'),
                        _number(run.createdCount),
                        muted,
                      ),
                      _count(
                        dsTr(fr, 'Updated', 'Mises à jour'),
                        _number(run.updatedCount),
                        muted,
                      ),
                      _count(
                        dsTr(fr, 'Unchanged', 'Inchangées'),
                        _number(run.unchangedCount),
                        muted,
                      ),
                      if (run.olderCount > 0)
                        _count(
                          dsTr(
                            fr,
                            'Older, ignored',
                            'Plus anciennes, ignorées',
                          ),
                          _number(run.olderCount),
                          muted,
                        ),
                      _count(
                        dsTr(fr, 'Rejected', 'Rejetées'),
                        _number(run.rejectedCount),
                        muted,
                        color: run.rejectedCount > 0
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ],
                  ),
                  if ((run.rowsPerSecond ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        [
                          '${_number(run.rowsPerSecond!)} ${dsTr(fr, 'rows/s', 'lignes/s')}',
                          '${_number(run.durationMs / 1000)} s',
                          if ((run.maxLagSeconds ?? 0) > 0)
                            '${dsTr(fr, 'longest delay between fact and reception', 'écart maximal entre fait et réception')} ${_lag(run.maxLagSeconds!)}',
                        ].join(' · '),
                        style: muted,
                      ),
                    ),
                  if (run.ignoredColumns.isNotEmpty)
                    Text(
                      '${dsTr(fr, 'Columns not read:', 'Colonnes non lues :')} ${run.ignoredColumns.join(', ')}',
                      style: muted,
                    ),
                  if (run.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        run.failure!.startsWith('MAPPING_STALE')
                            ? '${dsTr(fr, 'A mapped field was removed or changed type. Update the mapping, then resume.', 'Un champ associé a été supprimé ou a changé de type. Mettez à jour la correspondance, puis reprenez.')} (${run.failure!.replaceFirst(RegExp(r'^MAPPING_STALE:\s*'), '')})'
                            : run.failure!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (run.active)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _act(() => widget.api.cancel(run.id)),
                          child: Text(dsTr(fr, 'Cancel', 'Annuler')),
                        ),
                      if (run.state == 'FAILED' || run.state == 'CANCELLED')
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _act(() => widget.api.resume(run.id)),
                          child: Text(dsTr(fr, 'Resume', 'Reprendre')),
                        ),
                      if (run.rejectedCount > 0 && !run.active) ...[
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _details.containsKey(run.id)
                                    ? setState(() => _details.remove(run.id))
                                    : _act(() async {
                                        _details[run.id] = await widget.api.run(
                                          run.id,
                                        );
                                      }),
                          child: Text(
                            _details.containsKey(run.id)
                                ? dsTr(
                                    fr,
                                    'Hide rejected rows',
                                    'Masquer les lignes rejetées',
                                  )
                                : dsTr(
                                    fr,
                                    'Why rows were rejected',
                                    'Pourquoi des lignes sont rejetées',
                                  ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _act(() => widget.api.retry(run.id)),
                          child: Text(
                            dsTr(
                              fr,
                              'Retry rejected rows',
                              'Relancer les lignes rejetées',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _download(run),
                          child: Text(
                            dsTr(
                              fr,
                              'Download rejected rows',
                              'Télécharger les lignes rejetées',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_details[run.id]?.rejections case final rejections?) ...[
                    const SizedBox(height: 8),
                    if (run.rejectedCount > rejections.length)
                      Text(
                        dsTr(
                          fr,
                          'First ${rejections.length} of ${run.rejectedCount} rejected rows',
                          '${rejections.length} premières lignes rejetées sur ${run.rejectedCount}',
                        ),
                        style: muted,
                      ),
                    for (final item in rejections)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    '${dsTr(fr, 'Row', 'Ligne')} ${item.row}${item.recordId != null ? ' · ${item.recordId}' : ''} — ',
                                style: muted,
                              ),
                              TextSpan(
                                text: rejectionLabel(item.code, fr),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: ': ${item.message}'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _count(String label, String value, TextStyle? muted, {Color? color}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: muted),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
}
