import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// ====== АВТОРИЗАЦИЯ ======

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
      userId: (json['userId'] as num).toInt(),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      fullName: json['fullName'] as String?,
    );
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// ====== DASHBOARD МОДЕЛИ ======

enum CallType { answered, missed }

class CallItem {
  final CallType type;
  final DateTime dateTime;
  final int durationSeconds;

  CallItem({
    required this.type,
    required this.dateTime,
    required this.durationSeconds,
  });

  factory CallItem.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?) ?? 'answered';
    final type = typeStr == 'missed' ? CallType.missed : CallType.answered;

    return CallItem(
      type: type,
      dateTime: DateTime.parse(json['dateTime'] as String),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class SoldierDashboardData {
  final int soldierId;
  final String soldierName;
  final String unit;
  final String uniqueNumber;
  final int balanceTenge;
  final int tariffPerMinute;
  final int minutesUsedToday;
  final CallItem? lastCall;
  final List<CallItem> calls;

  SoldierDashboardData({
    required this.soldierId,
    required this.soldierName,
    required this.unit,
    required this.uniqueNumber,
    required this.balanceTenge,
    required this.tariffPerMinute,
    required this.minutesUsedToday,
    required this.lastCall,
    required this.calls,
  });

  factory SoldierDashboardData.fromJson(Map<String, dynamic> json) {
    final callsJson = (json['calls'] as List<dynamic>?) ?? [];

    return SoldierDashboardData(
      soldierId: (json['soldierId'] as num).toInt(),
      soldierName: (json['soldierName'] ?? '') as String,
      unit: (json['unit'] ?? '') as String,
      uniqueNumber: (json['uniqueNumber'] ?? '') as String,
      balanceTenge: (json['balanceTenge'] as num?)?.toInt() ?? 0,
      tariffPerMinute: (json['tariffPerMinute'] as num?)?.toInt() ?? 0,
      minutesUsedToday: (json['minutesUsedToday'] as num?)?.toInt() ?? 0,
      lastCall: json['lastCall'] == null
          ? null
          : CallItem.fromJson(json['lastCall'] as Map<String, dynamic>),
      calls: callsJson
          .map((e) => CallItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get name => soldierName;
}

class ParentDashboardData {
  final String parentName;
  final List<SoldierDashboardData> soldiers;
  final List<String> notifications;

  ParentDashboardData({
    required this.parentName,
    required this.soldiers,
    required this.notifications,
  });

  factory ParentDashboardData.fromJson(Map<String, dynamic> json) {
    final soldiersJson = (json['soldiers'] as List<dynamic>?) ?? [];
    final notifsJson = (json['notifications'] as List<dynamic>?) ?? [];

    return ParentDashboardData(
      parentName: json['parentName'] as String? ?? '',
      soldiers: soldiersJson
          .map((e) => SoldierDashboardData.fromJson(e as Map<String, dynamic>))
          .toList(),
      notifications: notifsJson.map((e) => e.toString()).toList(),
    );
  }
}

/// ====== API CLIENT (DIO) ======

class ApiClient {
  /// твой ngrok / prod url
  static const String _baseUrl = 'https://551643173e20.ngrok-free.app';
  static const String _authBase = '$_baseUrl/api/mobile';

  static const _storage = FlutterSecureStorage();

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUserId = 'auth_user_id';
  static const _kFullName = 'auth_full_name';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // сейчас делаем просто человеческую ошибку без refresh
          handler.next(e);
        },
      ),
    );

  // ---------- STORAGE HELPERS ----------

  static Future<String?> getAccessToken() => _storage.read(key: _kAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);

  static Future<int?> getUserId() async {
    final v = await _storage.read(key: _kUserId);
    if (v == null) return null;
    return int.tryParse(v);
  }

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
  }

  // ---------- AUTH ----------

  static Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '$_authBase/login',
        data: {
          'phone': phone,
          'password': password,
        },
      );

      final data = resp.data ?? {};
      final auth = AuthResponse.fromJson(data);
      await saveAuth(auth);
      return auth;
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  static Future<void> register({
    required String phone,
    required String password,
  }) async {
    try {
      await _dio.post(
        '$_authBase/register',
        data: {
          'phone': phone,
          'password': password,
        },
      );
    } on DioException catch (e) {
      // у тебя было: 409 -> "уже существует"
      if (e.response?.statusCode == 409) {
        throw AuthException('Пользователь с таким номером уже существует');
      }
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- REGISTRATION BY CODE ----------

  static Future<void> registerStart({
    required String phone,
  }) async {
    try {
      await _dio.post(
        '$_authBase/send-code',
        data: {'phone': phone},
      );
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  static Future<AuthResponse> confirmRegistration({
    required String phone,
    required String password,
    required String code,
  }) async {
    try {
      // verify-code
      await _dio.post(
        '$_authBase/verify-code',
        data: {
          'phone': phone,
          'code': code,
        },
      );

      await register(phone: phone, password: password);
      return await login(phone: phone, password: password);
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- PASSWORD RESET (same send-code) ----------

  static Future<void> sendPasswordResetCode({
    required String phone,
  }) async {
    try {
      await _dio.post(
        '$_authBase/send-code',
        data: {'phone': phone},
      );
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- PROFILE ----------

  static Future<void> updateProfileName({
    required int userId,
    required String newName,
  }) async {
    try {
      await _dio.post(
        '$_authBase/update-name',
        data: {
          'userId': userId,
          'fullName': newName,
        },
      );
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  static Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '$_authBase/change-password',
        data: {
          'userId': userId,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- DASHBOARD ----------

  static Future<ParentDashboardData> getParentDashboard() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw AuthException('Нет токена. Войдите заново.');
    }

    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '$_authBase/parent-dashboard',
      );

      final data = resp.data ?? {};
      return ParentDashboardData.fromJson(data);
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  static Future<void> updateSoldierName({
    required int soldierId,
    required String name,
  }) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      throw AuthException('Нет токена. Войдите заново.');
    }

    try {
      await _dio.post(
        '$_authBase/update-soldier-name',
        data: {
          'soldierId': soldierId,
          'soldierName': name,
        },
      );
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- DEVICE REGISTER (ДЛЯ PUSH) ----------

  /// Вызови ЭТО после успешного login/confirmRegistration
  /// и также подпишись на onTokenRefresh (я покажу дальше).
  static Future<void> registerDevice({
    String? deviceId,
    String? deviceName,
  }) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      // пользователь не залогинен — нечего регистрировать
      return;
    }

    final fcm = await FirebaseMessaging.instance.getToken();
    if (fcm == null || fcm.isEmpty) return;

    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'unknown';

    final name = deviceName ??
        (Platform.isAndroid
            ? 'Android'
            : Platform.isIOS
                ? 'iOS'
                : 'Unknown');

    try {
      await _dio.post(
        '$_baseUrl/api/mobile/devices/register',
        data: {
          'platform': platform,
          'pushToken': fcm,
          'deviceId': deviceId,
          'deviceName': name,
        },
      );
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  /// Один раз вызвать после логина: будет обновлять токен автоматически
  static void listenTokenRefresh({
    String? deviceId,
    String? deviceName,
  }) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final access = await getAccessToken();
      if (access == null || access.isEmpty) return;

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'unknown';

      final name = deviceName ??
          (Platform.isAndroid
              ? 'Android'
              : Platform.isIOS
                  ? 'iOS'
                  : 'Unknown');

      try {
        await _dio.post(
          '$_baseUrl/api/mobile/devices/register',
          data: {
            'platform': platform,
            'pushToken': newToken,
            'deviceId': deviceId,
            'deviceName': name,
          },
        );
      } catch (_) {
        // не критично: позже обновится
      }
    });
  }

  // ---------- ERROR PARSE ----------

  static String _extractMessage(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    // если бэк вернул { message: "..." }
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }

    // если бэк вернул строку
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (status == 401) return 'Сессия истекла, войдите заново';
    if (status == 403) return 'Доступ запрещён';
    if (status == 404) return 'Не найдено';
    if ((status ?? 0) >= 500) return 'Ошибка сервера';

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Таймаут сети';
    }

    return 'Ошибка сети';
  }
}
