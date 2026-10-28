import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

import 'auth_api.dart';
import 'collections_api.dart';

class OfflineEntryQueue {
  OfflineEntryQueue(this.userId);
  final String userId;
  static const _storage = FlutterSecureStorage();
  static final changed = ValueNotifier<int>(0);
  String get _key => 'brainy_offline_entries_$userId';

  static String newId() => 'mobile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  Future<List<Map<String, dynamic>>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final parsed = jsonDecode(raw);
    if (parsed is! List) throw const FormatException('Offline queue is damaged');
    return parsed.cast<Map<String, dynamic>>();
  }

  Future<void> _write(List<Map<String, dynamic>> rows) async {
    final content = jsonEncode(rows);
    if (rows.length > 50 || content.length > 64000) throw const FormatException('Offline storage is full. Sync pending entries first.');
    await _storage.write(key: _key, value: content);
    changed.value++;
  }

  Future<void> enqueue(Map<String, dynamic> row) async {
    final rows = await read();
    final existing = rows.indexWhere((item) => item['entryId'] != null && item['entryId'] == row['entryId'] && item['collectionId'] == row['collectionId'] && item['status'] == 'pending');
    if (existing >= 0) {
      rows[existing] = {...row, 'id': rows[existing]['id'], 'expectedUpdatedAt': rows[existing]['expectedUpdatedAt']};
    } else { rows.add(row); }
    await _write(rows);
  }

  Future<Map<String, dynamic>> revise(String visibleEntryId, Map<String, String> values) async {
    final rows = await read();
    final index = rows.indexWhere((item) => item['entryId'] == visibleEntryId || 'offline:${item['id']}' == visibleEntryId);
    if (index < 0) throw const FormatException('Pending entry not found on this device');
    rows[index] = {...rows[index], 'values': values, 'status': 'pending', 'error': null};
    await _write(rows);
    return rows[index];
  }

  Future<void> discard(String id) async { await _write((await read()).where((item) => item['id'] != id).toList()); }

  Future<({int synced, String? stopped})> sync(CollectionsApi api) async {
    var synced = 0;
    for (final row in await read()) {
      if (row['status'] == 'conflict') return (synced: synced, stopped: row['error'] as String?);
      try {
        final saved = await api.saveEntry(row['collectionId'] as String, (row['values'] as Map<String, dynamic>).cast<String, String>(), entryId: row['entryId'] as String?, formatId: row['formatId'] as String, clientMutationId: row['id'] as String, expectedUpdatedAt: DateTime.tryParse(row['expectedUpdatedAt'] as String? ?? ''));
        final local = (row['values'] as Map<String, dynamic>).cast<String, String>();
        if (local.entries.any((item) => item.value.trim().isNotEmpty && saved.values[item.key] != item.value.trim())) {
          final rows = await read();
          final index = rows.indexWhere((item) => item['id'] == row['id']);
          if (index >= 0) { rows[index] = {...rows[index], 'entryId': saved.id, 'status': 'conflict', 'error': 'The server saved an earlier version of this change. Review the conflict.'}; await _write(rows); }
          return (synced: synced, stopped: 'The server saved an earlier version of this change. Review the conflict.');
        }
        await discard(row['id'] as String);
        synced++;
      } catch (error) {
        final message = error is AuthApiException ? error.message : error.toString();
        if (message.contains('Could not reach') || message.contains('temporarily unavailable')) return (synced: synced, stopped: message);
        final rows = await read();
        final index = rows.indexWhere((item) => item['id'] == row['id']);
        if (index >= 0) { rows[index] = {...rows[index], 'status': 'conflict', 'error': message}; await _write(rows); }
        return (synced: synced, stopped: message);
      }
    }
    return (synced: synced, stopped: null);
  }
}
