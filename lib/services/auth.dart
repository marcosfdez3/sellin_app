import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';

/// Estado de la sesión. Es un ChangeNotifier para que GoRouter pueda
/// escucharlo y redirigir a /login al cerrar o caducar la sesión.
class AuthController extends ChangeNotifier {
  static const _tokenKey = 'auth_token';

  /// ID de cliente OAuth "Aplicación web" de Google Cloud (el mismo que
  /// GOOGLE_CLIENT_ID del backend). No es secreto. Se puede cambiar con:
  ///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '183487656266-5mkosjvfkrt96p4qbpsfn2qlkp1ac5q3.apps.googleusercontent.com',
  );

  static bool get googleSignInEnabled => _googleServerClientId.isNotEmpty;

  Future<void>? _googleInit;

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  AuthController(this._api, [this._storage = const FlutterSecureStorage()]) {
    _api.onUnauthorized = logout;
  }

  bool get isLoggedIn => _api.token != null;

  /// Recupera la sesión guardada. Llamar antes de arrancar la app.
  Future<void> load() async {
    _api.token = await _storage.read(key: _tokenKey);
  }

  Future<void> login(String email, String password) async {
    await _setToken(await _api.login(email.trim(), password));
  }

  Future<void> register(String email, String password) async {
    await _setToken(await _api.register(email.trim(), password));
  }

  /// Abre el selector de cuentas de Google. Si el usuario lo cancela,
  /// termina sin error y sin iniciar sesión.
  Future<void> loginWithGoogle() async {
    final google = GoogleSignIn.instance;
    _googleInit ??= google.initialize(serverClientId: _googleServerClientId);
    await _googleInit;

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      throw AuthException('No se pudo iniciar sesión con Google (${e.code.name})');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) throw AuthException('Google no devolvió un token de acceso');
    await _setToken(await _api.loginWithGoogle(idToken));
  }

  Future<void> logout() async {
    await _setToken(null);
    // Para que la próxima vez se pueda elegir otra cuenta de Google
    if (_googleInit != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }

  Future<void> _setToken(String? token) async {
    if (token == _api.token) return;
    _api.token = token;
    if (token == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
    notifyListeners();
  }
}

/// Se sobreescribe en main() con el controlador ya cargado.
final authProvider = ChangeNotifierProvider<AuthController>(
  (ref) => throw UnimplementedError('authProvider debe sobreescribirse en main()'),
);
