import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'error_reporter.dart';

class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  GoogleAuthService._();

  GoogleSignIn? _googleSignIn;
  String? _cachedEmail;
  bool _initialized = false;

  static const _keyEmail = 'google_email';
  static const _keyAccessToken = 'google_access_token';
  static const _keyRefreshToken = 'google_refresh_token';
  static const _keyTokenExpiry = 'google_token_expiry';

  void init() {
    if (_initialized) return;
    _googleSignIn = GoogleSignIn(
      clientId: '709040059901-ql43o7nmtgb9ngah9eo4a08b7ujfbvnv.apps.googleusercontent.com',
      scopes: [
        'email',
        'https://www.googleapis.com/auth/gmail.modify',
        'https://www.googleapis.com/auth/drive.file',
      ],
    );
    _initialized = true;
  }

  Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail);
    return email != null && email.isNotEmpty;
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  Future<bool> signIn() async {
    init();
    try {
      final user = await _googleSignIn!.signIn();
      if (user == null) return false;
      final auth = await user.authentication;
      if (auth.accessToken == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, user.email);
      await prefs.setString(_keyAccessToken, auth.accessToken!);
      await prefs.setString(_keyRefreshToken, auth.idToken ?? '');
      final expiry = DateTime.now().add(const Duration(hours: 1));
      await prefs.setString(_keyTokenExpiry, expiry.toIso8601String());
      _cachedEmail = user.email;
      return true;
    } catch (e, st) {
      ErrorReporter.sendError(message: 'Google Sign-In失敗: $e', stackTrace: st);
      return false;
    }
  }

  Future<bool> signOut() async {
    init();
    try {
      await _googleSignIn!.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyTokenExpiry);
      _cachedEmail = null;
      return true;
    } catch (e) {
      debugPrint('[GoogleAuth] signOut error: $e');
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    init();
    try {
      final user = await _googleSignIn!.signInSilently();
      if (user != null) {
        final auth = await user.authentication;
        if (auth.accessToken != null) {
          return auth.accessToken;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAccessToken);
    } catch (e) {
      debugPrint('[GoogleAuth] getToken error: $e');
      return null;
    }
  }

  Future<http.Client?> getAuthenticatedClient() async {
    final token = await getAccessToken();
    if (token == null) return null;
    return _AuthClient(token);
  }
}

class _AuthClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();
  _AuthClient(this._token);
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
  
  @override
  void close() => _inner.close();
}
