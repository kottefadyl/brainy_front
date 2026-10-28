import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'collections_api.dart';
import 'firebase_config.dart';

class PushRegistration {
  PushRegistration(this.api);
  final CollectionsApi api;
  StreamSubscription<String>? _refresh;

  static bool get supported =>
      !kIsWeb &&
      FirebaseConfig.isConfigured &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> refreshIfAuthorized() async {
    if (!supported) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: FirebaseConfig.options);
    }
    final permission = await FirebaseMessaging.instance
        .getNotificationSettings();
    if (permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional) {
      await enable();
    }
  }

  Future<void> enable() async {
    if (!supported) throw StateError('Push is unavailable on this device');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: FirebaseConfig.options);
    }
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('Notification permission was denied');
    }
    final registered = messaging.onRegistered.first.timeout(
      const Duration(seconds: 20),
    );
    await messaging.register();
    await _register(await registered);
    _refresh ??= messaging.onRegistered.listen((value) async {
      try {
        await _register(value);
      } catch (_) {
        /* Retry on next enable. */
      }
    });
  }

  Future<void> _register(String installationId) => api.registerPushDevice(
    installationId,
    defaultTargetPlatform == TargetPlatform.android ? 'ANDROID' : 'IOS',
    defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'iPhone',
    targetKind: 'FID',
  );

  void dispose() {
    _refresh?.cancel();
  }
}
