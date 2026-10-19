import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_api.dart';
import 'firebase_config.dart';

class GoogleAuthCancelled implements Exception {}

class GoogleAuthService extends ChangeNotifier {
  bool _ready = false;
  String? _setupError;

  bool get isAvailable => _ready;
  String? get setupError => _setupError;

  Future<void> initialize() async {
    if (!FirebaseConfig.isConfigured) {
      _setupError = 'Firebase app configuration is missing.';
      notifyListeners();
      return;
    }
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options)
          .timeout(const Duration(seconds: 12));
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        await GoogleSignIn.instance.initialize(
          serverClientId: FirebaseConfig.webClientId,
          clientId: defaultTargetPlatform == TargetPlatform.android
              ? null
              : FirebaseConfig.iosClientId,
        );
      }
      _ready = true;
    } catch (error) {
      _setupError = error.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<String> getFirebaseIdToken() async {
    if (!_ready) {
      throw AuthApiException(
        _setupError ?? 'Google sign-in is not configured.',
      );
    }
    try {
      UserCredential credential;
      if (kIsWeb) {
        credential = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        credential = await FirebaseAuth.instance.signInWithProvider(
          GoogleAuthProvider(),
        );
      } else {
        final account = await GoogleSignIn.instance.authenticate();
        final googleCredential = GoogleAuthProvider.credential(
          idToken: account.authentication.idToken,
        );
        credential = await FirebaseAuth.instance.signInWithCredential(
          googleCredential,
        );
      }
      final idToken = await credential.user?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw const AuthApiException('Google did not return a valid session.');
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleAuthCancelled();
      }
      throw AuthApiException(error.description ?? 'Google sign-in failed.');
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        throw GoogleAuthCancelled();
      }
      throw AuthApiException(error.message ?? 'Google sign-in failed.');
    }
  }

  Future<void> signOut() async {
    if (!_ready) return;
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await GoogleSignIn.instance.signOut();
    }
  }
}
