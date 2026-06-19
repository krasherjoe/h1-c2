import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'error_reporter.dart';
import '../constants/secure_storage_keys.dart';
import '../constants/env_config.dart';
import 'secure_storage_service.dart';

class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  GoogleAuthService._();

  GoogleSignIn? _googleSignIn;
  String? _cachedEmail;
  bool _initialized = false;
  String? _lastClientId;
  List<String>? _lastScopes;

  void init() {
    if (_initialized) return;
    _lastClientId = EnvConfig.googleClientIdOrDefault;
    _lastScopes = [
      'email',
      'https://www.googleapis.com/auth/gmail.modify',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/spreadsheets',
    ];
    try {
      _googleSignIn = GoogleSignIn(
        clientId: (_lastClientId?.isNotEmpty ?? false) ? _lastClientId : null,
        scopes: _lastScopes!,
      );
      _initialized = true;
      _log('GoogleSignIn initialized');
    } catch (e, st) {
      _log('GoogleSignIn init FAILED: $e\n$st');
    }
  }

  Future<bool> isSignedIn() async {
    final email = await SecureStorageService.instance.read(SecureStorageKeys.googleEmail);
    return email != null && email.isNotEmpty;
  }

  Future<String?> getEmail() async {
    return await SecureStorageService.instance.read(SecureStorageKeys.googleEmail);
  }

  Future<bool> signIn() async {
    _log('signIn() called');
    init();
    if (_googleSignIn == null) {
      _log('_googleSignIn is null after init');
      return false;
    }
    try {
      final user = await _googleSignIn!.signIn();
      if (user == null) {
        _log('signIn returned null (user cancelled or no account)');
        return false;
      }

      final auth = await user.authentication;
      if (auth.accessToken == null) {
        _log('auth.accessToken is null');
        return false;
      }

      final secure = SecureStorageService.instance;
      await secure.write(SecureStorageKeys.googleEmail, user.email);
      await secure.write(SecureStorageKeys.googleAccessToken, auth.accessToken!);
      // google_sign_in 6.x では refreshToken は公開APIではないため保存しない
      // トークンリフレッシュは signInSilently() の内部処理に任せる
      final expiry = DateTime.now().add(const Duration(hours: 1));
      await secure.write(SecureStorageKeys.googleTokenExpiry, expiry.toIso8601String());
      _cachedEmail = user.email;
      _log('signIn success');
      return true;
    } catch (e, st) {
      _log('signIn EXCEPTION: $e');
      ErrorReporter.sendError(message: 'Google Sign-In失敗: $e', stackTrace: st);
      return false;
    }
  }

  Future<bool> signOut() async {
    init();
    try {
      await _googleSignIn!.signOut();
      final secure = SecureStorageService.instance;
      await secure.delete(SecureStorageKeys.googleEmail);
      await secure.delete(SecureStorageKeys.googleAccessToken);
      await secure.delete(SecureStorageKeys.googleRefreshToken);
      await secure.delete(SecureStorageKeys.googleTokenExpiry);
      _cachedEmail = null;
      _log('signOut success');
      return true;
    } catch (e) {
      _log('signOut error: $e');
      return false;
    }
  }

  void _log(String msg) {
    debugPrint('[GoogleAuth] $msg');
  }

  Future<String?> getAccessToken() async {
    init();
    try {
      // 保存済みトークンの期限をチェック
      final expiryStr = await SecureStorageService.instance.read(SecureStorageKeys.googleTokenExpiry);
      if (expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          // 期限切れ → signInSilentlyでリフレッシュ試行
          final user = await _googleSignIn!.signInSilently();
          if (user != null) {
            final auth = await user.authentication;
            if (auth.accessToken != null) {
              final secure = SecureStorageService.instance;
              await secure.write(SecureStorageKeys.googleAccessToken, auth.accessToken!);
              // google_sign_in 6.x では refreshToken は利用不可（signInSilentlyが内部処理）
              final newExpiry = DateTime.now().add(const Duration(hours: 1));
              await secure.write(SecureStorageKeys.googleTokenExpiry, newExpiry.toIso8601String());
              return auth.accessToken;
            }
          }
          return null; // リフレッシュ失敗
        }
      }

      // 期限内 or 期限未設定 → signInSilentlyで取得
      final user = await _googleSignIn!.signInSilently();
      if (user != null) {
        final auth = await user.authentication;
        if (auth.accessToken != null) {
          return auth.accessToken;
        }
      }
      return await SecureStorageService.instance.read(SecureStorageKeys.googleAccessToken);
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
