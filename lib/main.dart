import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_theme_button.dart';
import 'auth_api.dart';
import 'auth_screen.dart';
import 'design_tokens.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: BrainyColors.blue,
          primary: BrainyColors.blue,
          onPrimary: const Color(0xFFFFFFFF),
          surface: BrainyColors.lightSurface,
          onSurface: BrainyColors.lightInk,
          error: const Color(0xFFB42332),
        ),
        scaffoldBackgroundColor: BrainyColors.lightCanvas,
        dialogTheme: DialogThemeData(
          backgroundColor: BrainyColors.lightSurface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2463CE),
            foregroundColor: const Color(0xFFFFFFFF),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: Color(0xFF778293)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFFFFF),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          labelStyle: TextStyle(color: Color(0xFF545E6D)),
          floatingLabelStyle: TextStyle(color: Color(0xFF2463CE)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF778293)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF2463CE), width: 2),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: BrainyColors.darkAccent,
          brightness: Brightness.dark,
          primary: BrainyColors.darkAccent,
          onPrimary: BrainyColors.darkOnAccent,
          surface: BrainyColors.darkSurface,
          onSurface: BrainyColors.darkInk,
          error: const Color(0xFFFFADB5),
        ),
        scaffoldBackgroundColor: BrainyColors.darkCanvas,
        dialogTheme: DialogThemeData(
          backgroundColor: BrainyColors.darkElevated,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: BrainyColors.darkAccent,
            foregroundColor: BrainyColors.darkOnAccent,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: BrainyColors.darkControl),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: BrainyColors.darkSurface,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          labelStyle: TextStyle(color: BrainyColors.darkMuted),
          floatingLabelStyle: TextStyle(color: BrainyColors.darkAccent),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: BrainyColors.darkControl),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: BrainyColors.darkAccent, width: 2),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
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
              themeButton: AppThemeButton(onPressed: _toggleTheme),
            ),
    );
  }
}
