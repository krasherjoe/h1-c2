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
  String? _lastClientId;
  List<String>? _lastScopes;

  static const _keyEmail = 'google_email';
  static const _keyAccessToken = 'google_access_token';
  static const _keyRefreshToken = 'google_refresh_token';
  static const _keyTokenExpiry = 'google_token_expiry';

  void init() {
    if (_initialized) return;
    _lastClientId = '468424259506-09fl38dtcem537g01dqb45cjk3tjjhqp.apps.googleusercontent.com';
    _lastScopes = [
      'email',
      'https://www.googleapis.com/auth/gmail.modify',
      'https://www.googleapis.com/auth/drive.file',
    ];
    try {
      _googleSignIn = GoogleSignIn(
        clientId: _lastClientId,
        scopes: _lastScopes!,
      );
      _initialized = true;
      _log('✅ GoogleSignIn initialized: clientId=$_lastClientId scopes=${_lastScopes?.join(",")}');
    } catch (e, st) {
      _log('❌ GoogleSignIn init FAILED: $e\n$st');
    }
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
    _log('▶️ signIn() called');
    init();
    if (_googleSignIn == null) {
      _log('❌ _googleSignIn is null after init');
      return false;
    }
    try {
      _log('⏳ Calling _googleSignIn.signIn()...');
      final user = await _googleSignIn!.signIn();
      if (user == null) {
        _log('⚠️ signIn returned null (user cancelled or no account)');
        return false;
      }
      _log('✅ signIn got user: email=${user.email} displayName=${user.displayName} id=${user.id}');

      _log('⏳ Calling user.authentication...');
      final auth = await user.authentication;
      if (auth.accessToken == null) {
        _log('❌ auth.accessToken is null');
        _log('   idToken=${auth.idToken?.substring(0, 20)}...');
        return false;
      }
      _log('✅ Got accessToken: ${auth.accessToken!.substring(0, 20)}...');
      _log('   idToken=${auth.idToken?.substring(0, 20)}...');
      _log('   serverAuthCode=${auth.serverAuthCode}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, user.email);
      await prefs.setString(_keyAccessToken, auth.accessToken!);
      await prefs.setString(_keyRefreshToken, auth.idToken ?? '');
      final expiry = DateTime.now().add(const Duration(hours: 1));
      await prefs.setString(_keyTokenExpiry, expiry.toIso8601String());
      _cachedEmail = user.email;
      _log('✅ signIn success, saved to SP: email=${user.email}');
      return true;
    } catch (e, st) {
      _log('❌ signIn EXCEPTION: $e');
      _log('STACK: $st');
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
      _log('✅ signOut success');
      return true;
    } catch (e) {
      _log('❌ signOut error: $e');
      return false;
    }
  }

  void _log(String msg) {
    debugPrint('[GoogleAuth] $msg');
    ErrorReporter.sendLog(message: '[GoogleAuth] $msg');
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
