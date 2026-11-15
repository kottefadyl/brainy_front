import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';

/// The person closed or refused Google's page, or never finished signing in.
class GoogleDesktopAuthCancelled implements Exception {}

/// Google sign-in for the desktop app: Firebase's Windows SDK cannot open Google's
/// page itself, so Brainy follows the installed-app flow (RFC 8252). The system
/// browser shows Google's page, Google returns to a one-time address on this PC
/// (127.0.0.1, random port), and PKCE ties the answer to this request. The result
/// is a Google ID token, which Firebase accepts as a credential.
///
/// The OAuth client is a Google Cloud "Desktop app" client of project brainy-6d65c,
/// given at build time with --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... and
/// --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=... (Google does not treat a desktop
/// client's secret as confidential; it is still kept out of the repository).
class GoogleDesktopAuth {
  static const clientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
  static const clientSecret = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

  static bool get isConfigured => clientId.isNotEmpty;

  /// Opens Google's sign-in page in the browser and returns a Google ID token.
  static Future<String> signIn({Duration timeout = const Duration(minutes: 5)}) async {
    if (!isConfigured) {
      throw const AuthApiException('Google sign-in is not configured for this computer app.');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirectUri = 'http://127.0.0.1:${server.port}';
      final verifier = _randomText(64);
      final challenge = base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
      final state = _randomText(32);
      final page = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
        'prompt': 'select_account',
      });
      if (!await launchUrl(page, mode: LaunchMode.externalApplication)) {
        throw const AuthApiException('The browser could not be opened for Google sign-in.');
      }
      final code = await _waitForCode(server, state).timeout(timeout, onTimeout: () => throw GoogleDesktopAuthCancelled());
      return await _exchange(code, verifier, redirectUri);
    } finally {
      await server.close(force: true);
    }
  }

  static Future<String> _waitForCode(HttpServer server, String state) async {
    await for (final request in server) {
      // The browser may also ask for a favicon: only the redirect itself carries an answer.
      final query = request.uri.queryParameters;
      if (request.uri.path != '/' || (!query.containsKey('code') && !query.containsKey('error'))) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final valid = query['state'] == state;
      final code = valid ? query['code'] : null;
      await _answer(request, success: code != null);
      if (!valid) throw const AuthApiException('Google sign-in answered an unknown request.');
      if (code == null) throw GoogleDesktopAuthCancelled();
      return code;
    }
    throw GoogleDesktopAuthCancelled();
  }

  static Future<void> _answer(HttpRequest request, {required bool success}) async {
    const title = 'Brainy';
    final text = success
        ? 'Vous êtes connecté. Vous pouvez fermer cette fenêtre et revenir à Brainy.<br>You are signed in. You can close this window and go back to Brainy.'
        : 'Connexion annulée. Vous pouvez fermer cette fenêtre.<br>Sign-in cancelled. You can close this window.';
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write('<!doctype html><html><head><meta charset="utf-8"><title>$title</title></head>'
          '<body style="font-family:system-ui,sans-serif;background:#111317;color:#F1F3F7;display:grid;place-items:center;height:100vh;margin:0">'
          '<p style="max-width:440px;text-align:center;line-height:1.6;font-size:16px">$text</p></body></html>');
    await request.response.close();
  }

  static Future<String> _exchange(String code, String verifier, String redirectUri) async {
    final response = await http.post(Uri.https('oauth2.googleapis.com', '/token'), body: {
      'code': code,
      'client_id': clientId,
      if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
      'code_verifier': verifier,
      'grant_type': 'authorization_code',
      'redirect_uri': redirectUri,
    }).timeout(const Duration(seconds: 20));
    final Object? body = response.body.isEmpty ? null : jsonDecode(response.body);
    final idToken = body is Map ? body['id_token'] : null;
    if (response.statusCode != 200 || idToken is! String || idToken.isEmpty) {
      final reason = body is Map ? (body['error_description'] ?? body['error']) : null;
      throw AuthApiException('Google sign-in failed${reason == null ? '' : ': $reason'}.');
    }
    return idToken;
  }

  static String _randomText(int length) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }
}
