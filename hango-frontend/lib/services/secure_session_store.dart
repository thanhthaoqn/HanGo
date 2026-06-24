import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hango/domain/model/auth_session.dart';

class SecureSessionStore {
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'hango.token';
  static const _userIdKey = 'hango.userId';
  static const _fullNameKey = 'hango.fullName';
  static const _emailKey = 'hango.email';
  static const _roleKey = 'hango.role';
  static const _baseUrlKey = 'hango.baseUrl';

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(key: _userIdKey, value: '${session.userId}');
    await _storage.write(key: _fullNameKey, value: session.fullName);
    await _storage.write(key: _emailKey, value: session.email);
    await _storage.write(key: _roleKey, value: session.role);
  }

  Future<AuthSession?> readSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return null;

    return AuthSession(
      token: token,
      userId: int.tryParse(await _storage.read(key: _userIdKey) ?? '') ?? 0,
      fullName: await _storage.read(key: _fullNameKey) ?? 'Learner',
      email: await _storage.read(key: _emailKey) ?? '',
      role: await _storage.read(key: _roleKey) ?? 'LEARNER',
    );
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _fullNameKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _roleKey);
  }

  Future<String?> readBaseUrl() => _storage.read(key: _baseUrlKey);

  Future<void> saveBaseUrl(String value) =>
      _storage.write(key: _baseUrlKey, value: value);
}
