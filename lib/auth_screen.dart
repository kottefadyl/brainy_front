import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'app_strings.dart';
import 'google_auth.dart';
import 'brand_assets.dart';

const ink = Color(0xFF202A43);
const mutedInk = Color(0xFF788198);
const fedoraBlue = Color(0xFF3989DD);

class BrandScaffold extends StatelessWidget {
  const BrandScaffold({
    super.key,
    required this.child,
    this.onLanguageChanged,
    this.themeButton,
  });

  final Widget child;
  final ValueChanged<String>? onLanguageChanged;
  final Widget? themeButton;

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
                  const BrainyMark(size: 18),
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
                  if (MediaQuery.sizeOf(context).width >= 550)
                    Text(
                      AppStrings.of(context).text('A space for every thought'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11,
                      ),
                    ),
                  if (onLanguageChanged != null) ...[
                    const SizedBox(width: 10),
                    LanguageMenu(onChanged: onLanguageChanged, onDark: true),
                  ],
                  ?themeButton,
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
    this.onLanguageChanged,
    this.themeButton,
  });

  final AuthApi api;
  final GoogleAuthService? googleAuth;
  final ValueChanged<AppUser> onAuthenticated;
  final ValueChanged<String>? onLanguageChanged;
  final Widget? themeButton;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _t(String value) => AppStrings.of(context).text(value);
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
      if (mounted) {
        setState(() => _error = error.message);
      }
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
      if (mounted) {
        setState(() => _error = error.message);
      }
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
      onLanguageChanged: widget.onLanguageChanged,
      themeButton: widget.themeButton,
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
                                height: AppStrings.of(context).isFrench
                                    ? (_registering ? 910 : 790)
                                    : (_registering ? 850 : 740),
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
                const BrainyMark(),
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
                  Text(
                    _t('YOUR CREATIVE SPACE'),
                    style: const TextStyle(
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
              _registering ? _t('Make room for ideas.') : _t('Welcome back.'),
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
                  ? _t('Create your account and start collecting every spark.')
                  : _t('Your notes, sketches, and big ideas are waiting.'),
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: mutedInk,
              ),
            ),
            const SizedBox(height: 29),
            if (_registering) ...[
              _label(_t('Your name')),
              const SizedBox(height: 7),
              _field(
                _name,
                hint: _t('What should we call you?'),
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.name],
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? _t('Enter your name')
                    : null,
              ),
              const SizedBox(height: 17),
            ],
            _label(_t('Email address')),
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
                  : _t('Enter a valid email address'),
            ),
            const SizedBox(height: 17),
            _label(_t('Password')),
            const SizedBox(height: 7),
            _field(
              _password,
              hint: _registering
                  ? _t('At least 8 characters')
                  : _t('Enter your password'),
              icon: Icons.lock_outline_rounded,
              obscure: !_showPassword,
              autofillHints: [
                _registering
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              suffix: IconButton(
                tooltip: _showPassword
                    ? _t('Hide password')
                    : _t('Show password'),
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
                  ? _t('Use at least 8 characters')
                  : (value?.isEmpty ?? true)
                  ? _t('Enter your password')
                  : null,
            ),
            if (_registering) ...[
              const SizedBox(height: 17),
              _label(_t('Confirm password')),
              const SizedBox(height: 7),
              _field(
                _confirm,
                hint: _t('Repeat your password'),
                icon: Icons.verified_user_outlined,
                obscure: !_showPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => value != _password.text
                    ? _t('Passwords do not match')
                    : null,
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
                  AppStrings.of(context).error(_error!),
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
                          Flexible(
                            child: Text(
                              _registering
                                  ? _t('Create account')
                                  : _t('Sign in'),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE9EBF1))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Text(
                    _t('OR'),
                    style: const TextStyle(
                      color: mutedInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE9EBF1))),
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
                    Expanded(
                      child: Text(
                        _t('Continue with Google'),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
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
                    ? _t('Preparing Google sign-in…')
                    : _t('Google sign-in is unavailable. Try reloading.'),
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
                        ? _t('Already have an account? ')
                        : _t('New to Brainy? '),
                    style: const TextStyle(color: mutedInk, fontSize: 12.5),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _switchMode,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _registering ? _t('Sign in') : _t('Create an account'),
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
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: mutedInk,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _t(
                      'Your ideas stay with your account, wherever you sign in.',
                    ),
                    style: const TextStyle(color: mutedInk, fontSize: 11.5),
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

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).text;
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
                    const BrainyMark(size: 29),
                    const SizedBox(width: 10),
                    Text(
                      t('YOUR IDEAS, EVERYWHERE'),
                      style: const TextStyle(
                        color: Color(0xFFCBE7FF),
                        letterSpacing: 1.5,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 67),
                Text(
                  t('A little space for\nbig thoughts.'),
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.16,
                    fontSize: 37,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t(
                    'Capture a passing thought. Draw out a new idea. Pick up where you left off, on any device.',
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.55,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 42),
                ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset(
                      brainyShowcaseAsset,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'Brainy logo',
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
                    Expanded(
                      child: Text(
                        t('One account. Every device.'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
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
