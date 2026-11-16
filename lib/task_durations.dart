// Durations in the task views: planned time ("Estimated duration") and time actually spent ("Time spent"),
// per task and per day, so a day's load is visible before starting it. Same meaning as the web's task-durations.tsx.
import 'package:flutter/material.dart';

import 'collections_api.dart';
import 'duration.dart';

extension TaskDurationsApi on CollectionsApi {
  /// Adds "Estimated duration" and "Time spent" to a task list made before they existed.
  Future<void> addTaskDurationFields(String collectionId, bool french) => auth.authenticatedRequest(
        'mutation(\$id:String!,\$language:String){addTaskDurationFields(collectionId:\$id,language:\$language){id}}',
        {'id': collectionId, 'language': french ? 'fr' : 'en'},
      );
}

/// Estimate and time spent of a task, in seconds (null when empty or not set up).
class TaskDurations {
  TaskDurations(BrainyCollection collection) : _collection = collection;
  final BrainyCollection _collection;

  int? _read(BrainyEntry? entry, String key) {
    final planner = _collection.taskPlanner;
    final fieldId = planner?[key] as String?;
    if (planner == null || fieldId == null || entry == null) return null;
    final field = _collection.formats.where((item) => item.id == planner['formatId']).firstOrNull?.fields.where((item) => item.id == fieldId).firstOrNull;
    final value = entry.values[fieldId];
    return field == null || value == null || value.isEmpty ? null : parseDuration(value, field.unit);
  }

  int? estimate(BrainyEntry? entry) => _read(entry, 'estimateFieldId');
  int? spent(BrainyEntry? entry) => _read(entry, 'spentFieldId');
}

/// "45 min" and, once work started, "30 min spent of 45 min" with a bar (amber when over the estimate).
class TaskTimeChip extends StatelessWidget {
  const TaskTimeChip({super.key, required this.estimate, required this.spent, required this.french});
  final int? estimate, spent;
  final bool french;

  @override
  Widget build(BuildContext context) {
    if (estimate == null && spent == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final over = estimate != null && spent != null && spent! > estimate!;
    final amber = dark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    String short(int seconds) => formatDuration(seconds, french, short: true);
    final label = spent != null
        ? estimate != null
            ? (french ? '${short(spent!)} passées sur ${short(estimate!)}' : '${short(spent!)} spent of ${short(estimate!)}')
            : (french ? '${short(spent!)} passées' : '${short(spent!)} spent')
        : short(estimate!);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: (over ? const Color(0xFFF59E0B) : scheme.primary).withValues(alpha: over ? .2 : .12), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(spent != null ? Icons.hourglass_bottom : Icons.timer_outlined, size: 14, color: over ? amber : scheme.primary),
        const SizedBox(width: 4),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface))),
        if (spent != null && (estimate ?? 0) > 0) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 42,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: (spent! / estimate!).clamp(0, 1).toDouble(), minHeight: 5, color: over ? const Color(0xFFF59E0B) : const Color(0xFF16A34A), backgroundColor: scheme.onSurface.withValues(alpha: .14)),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Day summary: planned, still to do and spent, from the tasks of that day.
class DayTimeSummary extends StatelessWidget {
  const DayTimeSummary({super.key, required this.planned, required this.remaining, required this.spent, required this.french});
  final int planned, remaining, spent;
  final bool french;

  @override
  Widget build(BuildContext context) {
    if (planned == 0 && spent == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    TextSpan part(int seconds, String word) => TextSpan(children: [
          TextSpan(text: formatDuration(seconds, french, short: true), style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
          TextSpan(text: ' $word'),
        ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        liveRegion: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.timer_outlined, size: 16, color: scheme.primary)),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(TextSpan(style: TextStyle(color: scheme.onSurfaceVariant), children: [
              if (planned > 0) part(planned, french ? 'prévues' : 'planned'),
              if (planned > 0) const TextSpan(text: '   '),
              if (planned > 0) part(remaining, french ? 'restantes' : 'left'),
              if (spent > 0 && planned > 0) const TextSpan(text: '   '),
              if (spent > 0) part(spent, french ? 'passées' : 'spent'),
            ])),
          ),
        ]),
      ),
    );
  }
}

/// Task lists made before durations existed: the owner adds the two fields in one tap.
class AddTaskDurationsBanner extends StatefulWidget {
  const AddTaskDurationsBanner({super.key, required this.api, required this.collection, required this.french, required this.onAdded});
  final CollectionsApi api;
  final BrainyCollection collection;
  final bool french;
  final Future<void> Function() onAdded;

  @override
  State<AddTaskDurationsBanner> createState() => _AddTaskDurationsBannerState();
}

class _AddTaskDurationsBannerState extends State<AddTaskDurationsBanner> {
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.addTaskDurationFields(widget.collection.id, widget.french);
      await widget.onAdded();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = widget.collection.taskPlanner;
    if (planner == null || planner['estimateFieldId'] != null || widget.collection.sharedBy != null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final fr = widget.french;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.timer_outlined, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fr ? 'Ajoutez « Durée estimée » et « Temps passé » à vos tâches pour voir le temps prévu de chaque jour.' : 'Add “Estimated duration” and “Time spent” to your tasks to see how much time each day needs.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : _add, child: Text(fr ? 'Ajouter les durées' : 'Add durations')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: TextStyle(color: scheme.error))),
      ]),
    );
  }
}
