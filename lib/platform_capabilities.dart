import 'package:flutter/foundation.dart';

import 'auth_api.dart';

/// What the hosting runs (same meaning as `brainy_web_app/lib/platform.ts`).
/// On Vercel's free plan the API freezes reminders, background processing,
/// data sources and large files, and keeps 3 MiB of attachments per entry.
@immutable
class PlatformCapabilities {
  const PlatformCapabilities({required this.frozenModules, required this.maxEntryAttachmentBytes});

  static const full = PlatformCapabilities(frozenModules: {}, maxEntryAttachmentBytes: 8 * 1024 * 1024);

  final Set<String> frozenModules;
  final int maxEntryAttachmentBytes;

  bool isFrozen(String module) => frozenModules.contains(module);

  /// "3 Mo" / "3 MB", as the file size messages of the interface.
  String attachmentLimit(bool french) {
    final mebibytes = (maxEntryAttachmentBytes / 1024 / 1024 * 10).round() / 10;
    final number = mebibytes == mebibytes.roundToDouble() ? mebibytes.toStringAsFixed(0) : mebibytes.toString().replaceAll('.', french ? ',' : '.');
    return '$number ${french ? 'Mo' : 'MB'}';
  }
}

/// Loaded once after sign-in; until then, and with an older API, nothing is frozen.
class BrainyPlatform {
  BrainyPlatform._();

  static final notifier = ValueNotifier<PlatformCapabilities>(PlatformCapabilities.full);
  static PlatformCapabilities get current => notifier.value;
  static bool isFrozen(String module) => notifier.value.isFrozen(module);
  static Future<void>? _loading;

  static Future<void> load(AuthApi auth) => _loading ??= () async {
    try {
      final data = await auth.authenticatedRequest('query { platformCapabilities { frozenModules maxEntryAttachmentBytes } }', const {});
      final value = data['platformCapabilities'] as Map<String, dynamic>;
      notifier.value = PlatformCapabilities(
        frozenModules: {for (final item in value['frozenModules'] as List<dynamic>) item as String},
        maxEntryAttachmentBytes: (value['maxEntryAttachmentBytes'] as num).toInt(),
      );
    } catch (_) {
      _loading = null;
    }
  }();
}
