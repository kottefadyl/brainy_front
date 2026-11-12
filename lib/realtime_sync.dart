// Real-time data synchronisation: listens to the change signals of the collections I can open
// (Cloud Firestore, written by the API after every change; see api/src/realtime) and reports, at most
// once every 600 ms, which collections other people changed. Vercel's free plan keeps no socket open:
// the live connection is Firebase's own.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'collections_api.dart';
import 'firebase_config.dart';

/// One change signal: the collection, who changed it, and whether my access to it ended.
typedef ChangeSignal = ({String collectionId, String? by, bool removed});

/// Groups quick signals (a pasted range…) into one reload; my own changes are already on screen.
class ChangeBatcher {
  ChangeBatcher(this.userId, this.onChange, {this.delay = const Duration(milliseconds: 600)});
  final String userId;
  final void Function(Set<String> collectionIds) onChange;
  final Duration delay;
  final _pending = <String>{};
  Timer? _timer;

  void add(ChangeSignal signal) {
    if (signal.by == userId && !signal.removed) return;
    _pending.add(signal.collectionId);
    _timer?.cancel();
    _timer = Timer(delay, () {
      final ids = Set<String>.of(_pending);
      _pending.clear();
      onChange(ids);
    });
  }

  void dispose() => _timer?.cancel();
}

class RealtimeSync {
  RealtimeSync(this.api, String userId, void Function(Set<String> collectionIds) onChange) : _batcher = ChangeBatcher(userId, onChange), _userId = userId;
  final CollectionsApi api;
  final String _userId;
  final ChangeBatcher _batcher;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _stopped = false;

  /// Starts listening; does nothing when Firebase is not set up here or the API has real-time sync off.
  Future<void> start() async {
    if (!FirebaseConfig.isConfigured) return;
    try {
      final data = await api.auth.authenticatedRequest('query { realtimeToken }', const {});
      final token = data['realtimeToken'] as String?;
      if (token == null || _stopped) return;
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: FirebaseConfig.options);
      await FirebaseAuth.instance.signInWithCustomToken(token);
      if (_stopped) return;
      var first = true;
      _subscription = FirebaseFirestore.instance
          .collection('brainy_signals')
          .where('readers', arrayContains: _userId)
          .snapshots()
          .listen((snapshot) {
        // The first answer lists the current state: only later changes matter.
        if (first) { first = false; return; }
        for (final change in snapshot.docChanges) {
          _batcher.add((collectionId: change.doc.id, by: change.doc.data()?['by'] as String?, removed: change.type == DocumentChangeType.removed));
        }
      }, onError: (Object _) {});
    } catch (_) {
      // Without the live channel, the next load still shows other people's changes.
    }
  }

  void dispose() {
    _stopped = true;
    _subscription?.cancel();
    _batcher.dispose();
  }
}
