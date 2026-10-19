import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AppUser {
  const AppUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}

class AuthApi {
  AuthApi({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'brainy_session';
  static const _configuredUrl = String.fromEnvironment('API_URL');
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Uri get endpoint {
    if (_configuredUrl.isNotEmpty) return Uri.parse(_configuredUrl);
    if (kIsWeb) {
      return Uri.parse('${Uri.base.scheme}://${Uri.base.host}:3000/graphql');
    }
    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return Uri.parse('http://$host:3000/graphql');
  }

  Future<AppUser> register(String name, String email, String password) async {
    final data = await _request(
      'mutation Register(\$input: RegisterInput!) { register(input: \$input) { token user { id name email } } }',
      {
        'input': {'name': name, 'email': email, 'password': password},
      },
    );
    return _saveSession(data['register'] as Map<String, dynamic>);
  }

  Future<AppUser> login(String email, String password) async {
    final data = await _request(
      'mutation Login(\$input: LoginInput!) { login(input: \$input) { token user { id name email } } }',
      {
        'input': {'email': email, 'password': password},
      },
    );
    return _saveSession(data['login'] as Map<String, dynamic>);
  }

  Future<AppUser> loginWithGoogle(String firebaseIdToken) async {
    final data = await _request(
      'mutation Google(\$firebaseIdToken: String!) { loginWithGoogle(firebaseIdToken: \$firebaseIdToken) { token user { id name email } } }',
      {'firebaseIdToken': firebaseIdToken},
    );
    return _saveSession(data['loginWithGoogle'] as Map<String, dynamic>);
  }

  Future<AppUser?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    try {
      final data = await _request(
        'query Me { me { id name email } }',
        {},
        token: token,
      );
      return AppUser.fromJson(data['me'] as Map<String, dynamic>);
    } on AuthApiException catch (error) {
      if (error.isUnauthorized) await signOut();
      return null;
    }
  }

  Future<void> signOut() => _storage.delete(key: _tokenKey);

  Future<AppUser> _saveSession(Map<String, dynamic> payload) async {
    await _storage.write(key: _tokenKey, value: payload['token'] as String);
    return AppUser.fromJson(payload['user'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _request(
    String query,
    Map<String, dynamic> variables, {
    String? token,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'query': query, 'variables': variables}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const AuthApiException(
        'Could not reach Brainy. Check your connection and try again.',
      );
    }
    if (response.statusCode >= 500) {
      throw const AuthApiException(
        'Brainy is temporarily unavailable. Please try again.',
      );
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final errors = body['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final first = errors.first as Map<String, dynamic>;
        final extension = first['extensions'] as Map<String, dynamic>?;
        throw AuthApiException(
          first['message'] as String? ??
              'Something went wrong. Please try again.',
          isUnauthorized: extension?['code'] == 'UNAUTHENTICATED',
        );
      }
      return body['data'] as Map<String, dynamic>;
    } on AuthApiException {
      rethrow;
    } catch (_) {
      throw const AuthApiException('The server sent an unexpected response.');
    }
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.isUnauthorized = false});

  final String message;
  final bool isUnauthorized;
  @override
  String toString() => message;
}
