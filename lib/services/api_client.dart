import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ответ авторизации (логин)
class AuthResponse {
  final int userId;
  final String accessToken;
  final String refreshToken;
  final String? fullName;

  AuthResponse({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    this.fullName,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['userId'] as int,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      fullName: json['fullName'] as String?,
    );
  }
}

/// Исключение для ошибок авторизации / API
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  /// Базовый URL API
  ///
  /// ⚠️ Если тестируешь с Android эмулятором:
  ///   - замени на 'http://10.0.2.2:5197'
  /// Если с реального устройства:
  ///   - укажи IP твоего ПК, например 'http://192.168.0.10:5197'
  static const String _baseUrl = 'http://localhost:5197';
  static const String _authBase = '$_baseUrl/api/mobile';

  static const _storage = FlutterSecureStorage();

  // =================== ВСПОМОГАТЕЛЬНОЕ ===================

  static Future<String?> getToken() async {
    return _storage.read(key: 'auth_token');
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  // =================== АВТОРИЗАЦИЯ ===================

  /// Логин по телефону и паролю.
  /// Возвращает AuthResponse (userId, accessToken, refreshToken).
  static Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('$_authBase/login');

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final auth = AuthResponse.fromJson(data);

      // сохраняем accessToken
      await _storage.write(key: 'auth_token', value: auth.accessToken);

      return auth;
    } else if (response.statusCode == 400 || response.statusCode == 401) {
      // неверный логин/пароль
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          data['message']?.toString() ?? 'Неверный телефон или пароль',
        );
      } catch (_) {
        throw AuthException('Неверный телефон или пароль');
      }
    } else {
      throw AuthException(
        'Ошибка сервера (${response.statusCode}). Попробуйте позже.',
      );
    }
  }

  /// Прямая регистрация пользователя (без кода).
  /// Сейчас используется внутри confirmRegistration после проверки кода.
  static Future<void> register({
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('$_authBase/register');

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else if (response.statusCode == 409) {
      throw AuthException('Пользователь с таким номером уже существует');
    } else if (response.statusCode == 400) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          data['message']?.toString() ??
              'Некорректные данные. Проверьте номер и пароль.',
        );
      } catch (_) {
        throw AuthException('Некорректные данные. Проверьте номер и пароль.');
      }
    } else {
      throw AuthException(
        'Ошибка сервера (${response.statusCode}). Попробуйте позже.',
      );
    }
  }

  // =================== РЕГИСТРАЦИЯ С КОДОМ ===================

  /// Шаг 1: отправка SMS-кода при регистрации.
  /// Используется в RegisterPage.
  static Future<void> registerStart({
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('$_authBase/send-code');

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
      }),
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 400) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          data['message']?.toString() ?? 'Некорректный номер телефона',
        );
      } catch (_) {
        throw AuthException('Некорректный номер телефона');
      }
    } else {
      throw AuthException(
        'Ошибка при отправке кода (${response.statusCode}). Попробуйте позже.',
      );
    }
  }

  /// Шаг 2: подтверждение кода + регистрация + автологин.
  /// Используется в CodeConfirmPage (при isForPasswordReset == false).
  ///
  /// Возвращает AuthResponse (как login).
  static Future<AuthResponse> confirmRegistration({
    required String phone,
    required String password,
    required String code,
  }) async {
    // 1. Проверяем код
    final verifyUri = Uri.parse('$_authBase/verify-code');

    final verifyResp = await http.post(
      verifyUri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'code': code,
      }),
    );

    if (verifyResp.statusCode != 200) {
      if (verifyResp.statusCode == 400) {
        try {
          final data = jsonDecode(verifyResp.body) as Map<String, dynamic>;
          throw AuthException(
            data['message']?.toString() ?? 'Неверный или просроченный код',
          );
        } catch (_) {
          throw AuthException('Неверный или просроченный код');
        }
      } else {
        throw AuthException(
          'Ошибка при проверке кода (${verifyResp.statusCode}). Попробуйте позже.',
        );
      }
    }

    // 2. Регистрируем пользователя
    await register(phone: phone, password: password);

    // 3. Автоматически логиним
    final auth = await login(phone: phone, password: password);
    return auth;
  }

  // =================== ВОССТАНОВЛЕНИЕ ПАРОЛЯ ===================

  /// Отправка кода для восстановления пароля.
  /// Сейчас использует тот же эндпоинт send-code.
  static Future<void> sendPasswordResetCode({
    required String phone,
  }) async {
    final uri = Uri.parse('$_authBase/send-code');

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 400) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          data['message']?.toString() ?? 'Некорректный номер телефона',
        );
      } catch (_) {
        throw AuthException('Некорректный номер телефона');
      }
    } else {
      throw AuthException(
        'Ошибка при отправке кода (${response.statusCode}). Попробуйте позже.',
      );
    }
  }

  // =================== ПРОФИЛЬ: ИМЯ И ПАРОЛЬ ===================

  /// Обновление имени пользователя.
  /// Бэк ждёт:
  /// POST /api/mobile/update-name
  /// { "userId": 123, "fullName": "Имя" }
  static Future<void> updateProfileName({
    required int userId,
    required String newName,
  }) async {
    final uri = Uri.parse('$_authBase/update-name');

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'fullName': newName,
      }),
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 400) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          data['message']?.toString() ?? 'Некорректное имя',
        );
      } catch (_) {
        throw AuthException('Некорректное имя');
      }
    } else if (response.statusCode == 404) {
      throw AuthException('Пользователь не найден');
    } else {
      throw AuthException(
        'Ошибка при обновлении имени (${response.statusCode})',
      );
    }
  }

  /// Смена пароля.
  /// Бэк ждёт:
  /// POST /api/mobile/change-password
  /// { "userId": 123, "currentPassword": "...", "newPassword": "..." }
  static Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_authBase/change-password');

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 400 || response.statusCode == 401) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          data['message']?.toString() ?? 'Неверный текущий пароль',
        );
      } catch (_) {
        throw AuthException('Неверный текущий пароль');
      }
    } else if (response.statusCode == 404) {
      throw AuthException('Пользователь не найден');
    } else {
      throw AuthException(
        'Ошибка при смене пароля (${response.statusCode})',
      );
    }
  }
}
