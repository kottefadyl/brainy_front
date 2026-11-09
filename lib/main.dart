import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_theme_button.dart';
import 'brainy_theme.dart';
import 'auth_api.dart';
import 'auth_screen.dart';
import 'google_auth.dart';
import 'profile_screen.dart';
import 'workspace_screen.dart' as workspace;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final googleAuth = GoogleAuthService();
  runApp(BrainyApp(googleAuth: googleAuth));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(googleAuth.initialize());
  });
}

class BrainyApp extends StatefulWidget {
  const BrainyApp({super.key, required this.googleAuth});

  final GoogleAuthService googleAuth;

  @override
  State<BrainyApp> createState() => _BrainyAppState();
}

class _BrainyAppState extends State<BrainyApp> {
  static const _languageKey = 'brainy_language';
  static const _themeKey = 'brainy_theme';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthApi _api = AuthApi();
  AppUser? _user;
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  bool _editingProfile = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadTheme();
    _restoreSession();
  }

  Future<void> _loadLanguage() async {
    try {
      final code = await _storage.read(key: _languageKey);
      if (mounted && (code == 'en' || code == 'fr')) {
        setState(() => _locale = Locale(code!));
      }
    } catch (_) {
      // System locale remains active when local storage is unavailable.
    }
  }

  Future<void> _changeLanguage(String code) async {
    setState(() => _locale = Locale(code));
    try {
      await _storage.write(key: _languageKey, value: code);
    } catch (_) {
      // Language still applies for the active session.
    }
  }

  Future<void> _loadTheme() async {
    try {
      final mode = await _storage.read(key: _themeKey);
      if (!mounted) return;
      if (mode == 'dark') setState(() => _themeMode = ThemeMode.dark);
      if (mode == 'light') setState(() => _themeMode = ThemeMode.light);
    } catch (_) {
      // System theme remains active when local storage is unavailable.
    }
  }

  Future<void> _toggleTheme() async {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final currentlyDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && brightness == Brightness.dark);
    final next = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    setState(() => _themeMode = next);
    try {
      await _storage.write(
        key: _themeKey,
        value: next == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // Theme still applies for the active session.
    }
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _api.restoreSession();
      if (mounted) setState(() => _user = user);
    } catch (_) {
      // A stored session can expire or the API can be offline.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _api.signOut();
    try {
      await widget.googleAuth.signOut();
    } catch (_) {
      // The local Brainy session has already been removed.
    }
    if (mounted) {
      setState(() {
        _user = null;
        _editingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: BrainyTheme.light,
      darkTheme: BrainyTheme.dark,
      home: _loading
          ? const BrandScaffold(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2463CE)),
              ),
            )
          : _user == null
          ? AuthScreen(
              api: _api,
              googleAuth: widget.googleAuth,
              onLanguageChanged: _changeLanguage,
              themeButton: AppThemeButton(
                onPressed: _toggleTheme,
                onDarkBackground: true,
              ),
              onAuthenticated: (user) => setState(() => _user = user),
            )
          : !_user!.profileCompleted || _editingProfile
          ? ProfileScreen(
              user: _user!,
              api: _api,
              onSaved: (user) => setState(() {
                _user = user;
                _editingProfile = false;
              }),
              onSignOut: _signOut,
              onCancel: _user!.profileCompleted
                  ? () => setState(() => _editingProfile = false)
                  : null,
              onLanguageChanged: _changeLanguage,
              themeButton: AppThemeButton(onPressed: _toggleTheme),
            )
          : workspace.WorkspaceScreen(
              user: _user!,
              api: _api,
              onSignOut: _signOut,
              onEditProfile: () => setState(() => _editingProfile = true),
              onLanguageChanged: _changeLanguage,
              themeButton: AppThemeButton(onPressed: _toggleTheme, labelOnWide: true),
            ),
    );
  }
}
