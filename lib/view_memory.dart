import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Page sizes offered for entry lists.
const entryPageSizes = [30, 50, 100];

/// Remembers, per account, the last open collection, the view chosen in each collection and the page
/// size, so Brainy reopens as the person left it on every device: the account keeps the reference copy
/// ([saveToAccount], shortly after each change), this device a local copy read instantly. Storage that
/// fails (tests, locked keychain) falls back to the defaults.
class ViewMemory {
  ViewMemory(this.userId, {this.storage = const FlutterSecureStorage(), this.saveToAccount});

  final String userId;
  final FlutterSecureStorage storage;
  final Future<void> Function(Map<String, dynamic> preferences)? saveToAccount;
  Timer? _accountSave;
  Map<String, dynamic> _state = {};
  bool _loaded = false;

  String get _key => 'brainy_view_memory_$userId';

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      // A locked or missing keychain must never hold the workspace back.
      final raw = await storage.read(key: _key).timeout(const Duration(seconds: 1));
      if (raw != null) _state = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      _state = {};
    }
  }

  /// Takes the account's copy (another device may have changed it), when there is one.
  void adopt(Map<String, dynamic>? preferences) {
    if (preferences == null) return;
    final views = {
      for (final choice in (preferences['views'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
        choice['collectionId'] as String: choice['viewId'] as String,
    };
    _state = {
      'collection': preferences['lastCollectionId'] as String? ?? _state['collection'],
      'views': views,
      'pageSize': (preferences['pageSize'] as num?)?.toInt() ?? _state['pageSize'],
    };
    _saveLocally();
  }

  /// Stops a pending account save (the screen is closing).
  void dispose() => _accountSave?.cancel();

  String? get collectionId => _state['collection'] as String?;

  /// The view last chosen in this collection, if it still exists; null = the default list.
  String? viewIdFor(String collectionId, List<Map<String, dynamic>> savedViews) {
    final id = (_state['views'] as Map?)?[collectionId] as String?;
    return id != null && savedViews.any((view) => view['id'] == id) ? id : null;
  }

  int get pageSize {
    final value = _state['pageSize'];
    return value is int && entryPageSizes.contains(value) ? value : entryPageSizes.first;
  }

  void remember({required String collectionId, String? viewId}) {
    final views = Map<String, dynamic>.from((_state['views'] as Map?) ?? const {});
    if (_state['collection'] == collectionId && views[collectionId] == viewId) return;
    if (viewId == null) {
      views.remove(collectionId);
    } else {
      views[collectionId] = viewId;
    }
    _state = {..._state, 'collection': collectionId, 'views': views};
    _save();
  }

  void rememberPageSize(int size) {
    if (!entryPageSizes.contains(size)) return;
    _state = {..._state, 'pageSize': size};
    _save();
  }

  Future<void> _save() async {
    await _saveLocally();
    final save = saveToAccount;
    if (save == null) return;
    // Several quick changes make one save; a failed one is retried with the next change.
    _accountSave?.cancel();
    _accountSave = Timer(const Duration(milliseconds: 1500), () {
      final views = (_state['views'] as Map?) ?? const {};
      save({
        'lastCollectionId': _state['collection'],
        'pageSize': _state['pageSize'],
        'views': [for (final item in views.entries) {'collectionId': item.key, 'viewId': item.value}],
      }).catchError((_) {});
    });
  }

  Future<void> _saveLocally() async {
    try {
      await storage.write(key: _key, value: jsonEncode(_state));
    } catch (_) {
      // Not remembered this time; nothing else depends on it.
    }
  }
}
