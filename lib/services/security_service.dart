import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();

  static const _kPinCode = 'user_pin_code';
  static const _kBiometricsEnabled = 'biometrics_enabled';

  /// Есть ли сохраненный ПИН?
  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _kPinCode);
    return pin != null && pin.isNotEmpty;
  }

  /// Сохранить ПИН
  static Future<void> setPin(String pin) async {
    await _storage.write(key: _kPinCode, value: pin);
  }

  /// Проверить ПИН
  static Future<bool> checkPin(String inputPin) async {
    final storedPin = await _storage.read(key: _kPinCode);
    return storedPin == inputPin;
  }

  /// Очистить всё (при выходе)
  static Future<void> clear() async {
    await _storage.delete(key: _kPinCode);
    await _storage.delete(key: _kBiometricsEnabled);
  }

  /// Включить биометрию
  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _kBiometricsEnabled, value: enabled.toString());
  }

  static Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: _kBiometricsEnabled);
    return val == 'true';
  }

  /// Попробовать войти по лицу/пальцу
  static Future<bool> authenticateBio() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      if (!isAvailable) return false;

      // Используем простой метод без options для совместимости
      return await _auth.authenticate(
        localizedReason: 'Вход в приложение',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}