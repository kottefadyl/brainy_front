# Native identity review

`identity_preview.dart` renders the real workspace and shared production themes with synthetic collections and entries. It does not sign in, contact the API or perform mutations. Build this target only for local review; the normal application target remains `lib/main.dart`.

From `brainy/`:

- Windows: `flutter build windows --debug --no-pub --target tool/identity_preview.dart --dart-define=VISUAL_OUTPUT=<absolute-workspace-path>/.visual-checks/windows`. Launch the resulting executable with `Start-Process -WindowStyle Hidden`.
- Android emulator: `flutter build apk --debug --no-pub --target tool/identity_preview.dart`, then install and launch the debug APK on the dedicated emulator. The package is `com.example.brainy`.

The harness automatically captures entry rows and data format cards in both themes at logical widths 320 and 390; Windows also captures 1280. It logs `IDENTITY_REVIEW_COMPLETE` when finished. Without `VISUAL_OUTPUT`, PNG files are stored under `Directory.systemTemp/brainy-identity`; on Android, retrieve them with `adb shell run-as com.example.brainy` / `adb exec-out run-as` from `code_cache/brainy-identity`. Outputs are ignored by Git. Stop the review app after inspection.

The captures verify native rendering with fixed logical viewports, not a real account or every system text setting. `flutter test test/workspace_identity_test.dart test/workspace_test.dart` covers French cards with doubled text, reduced motion, pointer feedback and collection/entry interactions. The visual fixture makes no accessibility certification claim.
