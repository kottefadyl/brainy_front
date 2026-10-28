This package is based on `flutter_secure_storage_windows` 4.2.2 (BSD-3-Clause).
Brainy removes the native `pluginClass` registration and uses the upstream Dart
DPAPI implementation, which is the default for new values. The native bridge
only handles backward compatibility with older Windows credential storage.
New Brainy sessions use the Dart backend. Sessions stored by older native
Windows plugin versions cannot be migrated by this fork; those users must sign
in again. This keeps the Windows build independent of the optional Visual
Studio ATL component.
