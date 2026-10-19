import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'google_auth.dart';

const ink = Color(0xFF202A43);
const mutedInk = Color(0xFF788198);
const fedoraBlue = Color(0xFF3989DD);

class BrandScaffold extends StatelessWidget {
  const BrandScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101629),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              color: const Color(0xFF151A2B),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 7, color: Color(0xFF89BBF2)),
                  const SizedBox(width: 7),
                  const Text(
                    'brainy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'A space for every thought',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: Color(0xFFB9C6E7),
                    size: 15,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _SkyPainter()),
                  ),
                  Positioned.fill(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    this.googleAuth,
  });

  final AuthApi api;
  final GoogleAuthService? googleAuth;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GoogleAuthService _fallbackGoogleAuth = GoogleAuthService();
  GoogleAuthService get _googleAuth => widget.googleAuth ?? _fallbackGoogleAuth;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _googleAuth.addListener(_onGoogleAuthChanged);
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.googleAuth != widget.googleAuth) {
      (oldWidget.googleAuth ?? _fallbackGoogleAuth).removeListener(
        _onGoogleAuthChanged,
      );
      _googleAuth.addListener(_onGoogleAuthChanged);
    }
  }

  void _onGoogleAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _googleAuth.removeListener(_onGoogleAuthChanged);
    _fallbackGoogleAuth.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _registering = !_registering;
      _error = null;
      _form.currentState?.reset();
      _password.clear();
      _confirm.clear();
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _registering
          ? await widget.api.register(
              _name.text.trim(),
              _email.text.trim(),
              _password.text,
            )
          : await widget.api.login(_email.text.trim(), _password.text);
      if (mounted) widget.onAuthenticated(user);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final firebaseIdToken = await _googleAuth.getFirebaseIdToken();
      final user = await widget.api.loginWithGoogle(firebaseIdToken);
      if (mounted) widget.onAuthenticated(user);
    } on GoogleAuthCancelled {
      // Closing the account picker leaves the form as it was.
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrandScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 36 : 18,
              vertical: wide ? 48 : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight - (wide ? 96 : 48),
                ),
              ),
              child: Center(
                child: Container(
                  width: wide ? 980 : 450,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFCFE),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66091A35),
                        blurRadius: 42,
                        offset: Offset(0, 22),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: wide
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              flex: 10,
                              child: _StoryPanel(
                                height: _registering ? 850 : 740,
                              ),
                            ),
                            Expanded(flex: 11, child: _formPanel(wide: true)),
                          ],
                        )
                      : _formPanel(wide: false),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _formPanel({required bool wide}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 56 : 28,
        wide ? 47 : 31,
        wide ? 56 : 28,
        wide ? 42 : 30,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _BrandMark(),
                const SizedBox(width: 10),
                const Text(
                  'brainy',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ink,
                    letterSpacing: -0.7,
                  ),
                ),
                const Spacer(),
                if (wide)
                  const Text(
                    'YOUR CREATIVE SPACE',
                    style: TextStyle(
                      fontSize: 9,
                      color: mutedInk,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
              ],
            ),
            SizedBox(height: wide ? 43 : 30),
            Text(
              _registering ? 'Make room for ideas.' : 'Welcome back.',
              style: const TextStyle(
                fontSize: 31,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: ink,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _registering
                  ? 'Create your account and start collecting every spark.'
                  : 'Your notes, sketches, and big ideas are waiting.',
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: mutedInk,
              ),
            ),
            const SizedBox(height: 29),
            if (_registering) ...[
              _label('Your name'),
              const SizedBox(height: 7),
              _field(
                _name,
                hint: 'What should we call you?',
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.name],
                validator: (value) =>
                    (value?.trim().length ?? 0) < 2 ? 'Enter your name' : null,
              ),
              const SizedBox(height: 17),
            ],
            _label('Email address'),
            const SizedBox(height: 7),
            _field(
              _email,
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address',
            ),
            const SizedBox(height: 17),
            _label('Password'),
            const SizedBox(height: 7),
            _field(
              _password,
              hint: _registering
                  ? 'At least 8 characters'
                  : 'Enter your password',
              icon: Icons.lock_outline_rounded,
              obscure: !_showPassword,
              autofillHints: [
                _registering
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              suffix: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                  color: mutedInk,
                ),
              ),
              validator: (value) => _registering && (value?.length ?? 0) < 8
                  ? 'Use at least 8 characters'
                  : (value?.isEmpty ?? true)
                  ? 'Enter your password'
                  : null,
            ),
            if (_registering) ...[
              const SizedBox(height: 17),
              _label('Confirm password'),
              const SizedBox(height: 7),
              _field(
                _confirm,
                hint: 'Repeat your password',
                icon: Icons.verified_user_outlined,
                obscure: !_showPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match' : null,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB4433E),
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 49,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: fedoraBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _registering ? 'Create account' : 'Sign in',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFE9EBF1))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 13),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: mutedInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFE9EBF1))),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 49,
              child: OutlinedButton(
                onPressed: _busy || !_googleAuth.isAvailable
                    ? null
                    : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E7EF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFF4285F4),
                          Color(0xFFEA4335),
                          Color(0xFFFBBC05),
                          Color(0xFF34A853),
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_googleAuth.isAvailable) ...[
              const SizedBox(height: 7),
              Text(
                _googleAuth.setupError == null
                    ? 'Preparing Google sign-in…'
                    : 'Google sign-in is unavailable. Try reloading.',
                style: const TextStyle(color: mutedInk, fontSize: 10.5),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _registering
                        ? 'Already have an account? '
                        : 'New to Brainy? ',
                    style: const TextStyle(color: mutedInk, fontSize: 12.5),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _switchMode,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _registering ? 'Sign in' : 'Create an account',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: fedoraBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 21),
            const Divider(height: 1, color: Color(0xFFE9EBF1)),
            const SizedBox(height: 17),
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: mutedInk),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Your ideas stay with your account, wherever you sign in.',
                    style: TextStyle(color: mutedInk, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
  );

  Widget _field(
    TextEditingController controller, {
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      obscureText: obscure,
      validator: validator,
      onFieldSubmitted: (_) => _submit(),
      style: const TextStyle(fontSize: 13, color: ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA3A9B8), fontSize: 12.5),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF9AA5B9)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF7F8FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE6EAF1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE6EAF1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: fedoraBlue, width: 1.5),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF5BB9F2), Color(0xFF2779D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
  );
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B3F79), Color(0xFF294D91), Color(0xFF536CB1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF80C8F6).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -85,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFAC8EE7).withValues(alpha: 0.18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 48, 42, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFBAE2FF),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'YOUR IDEAS, EVERYWHERE',
                      style: TextStyle(
                        color: Color(0xFFCBE7FF),
                        letterSpacing: 1.5,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 67),
                const Text(
                  'A little space for\nbig thoughts.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.16,
                    fontSize: 37,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Capture a passing thought. Draw out a new idea. Pick up where you left off, on any device.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.55,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 42),
                Transform.rotate(
                  angle: -0.045,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(23, 21, 23, 19),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFDFD),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x44203B67),
                          blurRadius: 28,
                          offset: Offset(0, 17),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 29,
                              height: 29,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F3FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 18,
                                color: fedoraBlue,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.more_horiz_rounded,
                              color: Color(0xFFADB5C3),
                              size: 19,
                            ),
                          ],
                        ),
                        const SizedBox(height: 17),
                        const Text(
                          'The next big idea',
                          style: TextStyle(
                            fontSize: 17,
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'It starts with one small thought...',
                          style: TextStyle(fontSize: 12, color: mutedInk),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _pill(
                              const Color(0xFFE8F2FF),
                              const Color(0xFF4B8DD1),
                              'IDEAS',
                            ),
                            const SizedBox(width: 7),
                            _pill(
                              const Color(0xFFFFF0DC),
                              const Color(0xFFC58D43),
                              'TODAY',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: Color(0xFFB8DCFF),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'One account. Every device.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pill(Color background, Color foreground, String text) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
        ),
      );
}

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return BrandScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 660,
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66091A35),
                  blurRadius: 35,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const _BrandMark(),
                    const SizedBox(width: 10),
                    const Text(
                      'brainy',
                      style: TextStyle(
                        color: ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
                const SizedBox(height: 42),
                Text(
                  'Welcome, ${user.name.split(' ').first}.',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your account is ready. Your thoughts will have a home here.',
                  style: TextStyle(color: mutedInk, fontSize: 14),
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F7FF),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: fedoraBlue,
                        size: 26,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your workspace is coming next',
                              style: TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Notes, sketches, and brainstorming tools will live here.',
                              style: TextStyle(color: mutedInk, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SIGNED IN AS  ${user.email.toUpperCase()}',
                  style: const TextStyle(
                    color: mutedInk,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF12224B),
            Color(0xFF3C5795),
            Color(0xFFCCA7A2),
            Color(0xFFF1C994),
          ],
          stops: [0, 0.52, 0.81, 1],
        ).createShader(rect),
    );
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(
      Offset(size.width * 0.2, size.height * 0.85),
      size.width * 0.45,
      const Color(0x88FFD4A7),
    );
    glow(
      Offset(size.width * 0.88, size.height * 0.32),
      size.width * 0.28,
      const Color(0x889AC9EA),
    );
    final random = math.Random(27);
    for (var i = 0; i < 70; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.68;
      canvas.drawCircle(
        Offset(x, y),
        i % 8 == 0 ? 1.35 : 0.7,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.25 + random.nextDouble() * 0.55,
          ),
      );
    }
    final moon = Offset(size.width * 0.83, size.height * 0.18);
    glow(moon, 125, const Color(0x55FFF3DA));
    canvas.drawCircle(moon, 35, Paint()..color = const Color(0xFFF9ECD5));
    final lower = Path()
      ..moveTo(0, size.height * 0.94)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.83,
        size.width * 0.34,
        size.height * 1.02,
        size.width * 0.54,
        size.height * 0.94,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.86,
        size.width * 0.87,
        size.height * 0.95,
        size.width,
        size.height * 0.84,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(lower, Paint()..color = const Color(0x99EFF3FA));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
