import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intelvt_mobile_first/src/core/api/client/api_client.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUserId = 'auth_user_id';
  static const _kFullName = 'auth_full_name';
  static const _kPhone = 'auth_phone';

  static Future<String?> getAccessToken() => _storage.read(key: _kAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);

  static Future<int?> getUserId() async {
    final v = await _storage.read(key: _kUserId);
    if (v == null) return null;
    return int.tryParse(v);
  }

  static Future<String?> getPhone() => _storage.read(key: _kPhone);
  static Future<String?> getName() => _storage.read(key: _kFullName);
  static Future<void> savePhone(String phone) =>
      _storage.write(key: _kPhone, value: phone);

  static Future<void> saveAuth(AuthResponse auth) async {
    await _storage.write(key: _kAccess, value: auth.accessToken);
    await _storage.write(key: _kRefresh, value: auth.refreshToken);
    await _storage.write(key: _kUserId, value: auth.userId.toString());
    if (auth.fullName != null) {
      await _storage.write(key: _kFullName, value: auth.fullName);
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kFullName);
    await _storage.delete(key: _kPhone);
  }
}
