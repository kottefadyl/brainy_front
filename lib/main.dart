import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_screen.dart';
import 'google_auth.dart';

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
  final AuthApi _api = AuthApi();
  AppUser? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
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
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brainy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF367FD7)),
      ),
      home: _loading
          ? const BrandScaffold(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF4388DB)),
              ),
            )
          : _user == null
          ? AuthScreen(
              api: _api,
              googleAuth: widget.googleAuth,
              onAuthenticated: (user) => setState(() => _user = user),
            )
          : WorkspaceScreen(user: _user!, onSignOut: _signOut),
    );
  }
}
