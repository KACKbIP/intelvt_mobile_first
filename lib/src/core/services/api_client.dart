import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../../../navigation.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

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

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      isRead: (json['isRead'] as bool?) ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
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
  static const String _baseUrl = 'https://api.intelvt.kz';
  static const String _authBase = '$_baseUrl/api/mobile';

  static const _storage = FlutterSecureStorage();

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUserId = 'auth_user_id';
  static const _kFullName = 'auth_full_name';
  static const _kPhone = 'auth_phone';

  static bool _isRefreshing = false;

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await getAccessToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
            onError: (DioException e, handler) async {
              if (e.response?.statusCode != 401) {
                return handler.next(e);
              }

              if (_isRefreshing) {
                return handler.next(e);
              }

              try {
                _isRefreshing = true;

                final newAuth = await _refreshTokenOnServer();

                if (newAuth != null) {
                  await saveAuth(newAuth);

                  // Повторяем исходный запрос с новым токеном
                  final opts = e.requestOptions;
                  opts.headers['Authorization'] =
                      'Bearer ${newAuth.accessToken}';

                  final clonedReq = await _dio.fetch(opts);
                  return handler.resolve(clonedReq);
                } else {
                  await _performLogout();
                  return handler.next(e);
                }
              } catch (refreshErr) {
                await _performLogout();
                return handler.next(e);
              } finally {
                _isRefreshing = false;
              }
            },
          ),
        );

  // --- Внутренний метод рефреша ---
  static Future<AuthResponse?> _refreshTokenOnServer() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final dioRefresh = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      final resp = await dioRefresh.post(
        '$_authBase/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      if (resp.statusCode == 200 && resp.data != null) {
        return AuthResponse.fromJson(resp.data);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _performLogout() async {
    await logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ---------- STORAGE HELPERS ----------

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

  // ---------- AUTH ----------

  static Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '$_authBase/login',
        data: {'phone': phone, 'password': password},
      );

      final data = resp.data ?? {};
      final auth = AuthResponse.fromJson(data);

      await saveAuth(auth);
      await savePhone(phone);

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
        data: {'phone': phone, 'password': password},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw AuthException('Пользователь с таким номером уже существует');
      }
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- REGISTRATION BY CODE ----------

  static Future<void> registerStart({required String phone}) async {
    try {
      await _dio.post('$_authBase/send-code', data: {'phone': phone});
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
      await _dio.post(
        '$_authBase/verify-code',
        data: {'phone': phone, 'code': code},
      );

      await register(phone: phone, password: password);
      return await login(phone: phone, password: password);
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- PASSWORD RESET ----------

  static Future<void> sendPasswordResetCode({required String phone}) async {
    try {
      await _dio.post('$_authBase/send-code', data: {'phone': phone});
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
      final response = await _dio.post(
        '$_authBase/update-name',
        data: {'userId': userId, 'fullName': newName},
      );
      if (response.statusCode == 200) {
        await _storage.write(key: _kFullName, value: newName);
      }
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
      await _performLogout();
      throw AuthException('Нет токена. Войдите заново.');
    }

    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '$_authBase/parent-dashboard',
      );

      final data = resp.data ?? {};
      if (resp.statusCode == 401) {
        _refreshTokenOnServer().then((value) {
          return ParentDashboardData.fromJson(data);
        });
      } 
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
      await _performLogout();
      throw AuthException('Нет токена. Войдите заново.');
    }

    try {
      await _dio.post(
        '$_authBase/update-soldier-name',
        data: {'soldierId': soldierId, 'soldierName': name},
      );
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- DEVICE REGISTER (ДЛЯ PUSH) ----------

  static Future<void> registerDevice({
    String? deviceId,
    String? deviceName,
  }) async {
    final token = await FirebaseMessaging.instance.getToken();
    String? voipToken;

    if (Platform.isIOS) {
      try {
        voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        print('--- МОЙ НОВЫЙ VOIP ТОКЕН ДЛЯ CURL ---');
        print(voipToken); // Скопируйте его отсюда
        print('-------------------------------------');
      } catch (e) {
        print("❌ Ошибка при получении токена: $e");
      }
    }
    final accessToken = await getAccessToken();
    if (accessToken == null) return;

    // Interceptor добавит заголовок Authorization сам
    try {
      await _dio.post(
        '/api/mobile/devices/register',
        data: {
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'pushToken': token,
          'voipToken': voipToken, // Отправляем VoIP токен на сервер
          'deviceName':
              deviceName ??
              (Platform.isAndroid ? 'Android Device' : 'iOS Device'),
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      print('Device registered successfully. VoIP: ${voipToken != null}');
    } catch (e) {
      print('Error registering device: $e');
    }
  }

  static void listenTokenRefresh({String? deviceName}) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      registerDevice(deviceName: deviceName);
    });
  }
  // ---------- AGORA TOKEN ----------

  static Future<String> getRtcToken({
    required String channel,
    required int uid,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/agora/rtc-token',
        queryParameters: {'channel': channel.trim(), 'uid': uid},
      );

      final data = resp.data ?? {};
      final token = (data['token'] ?? '').toString();
      if (token.isEmpty) throw AuthException('Пустой token от сервера');
      return token;
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  static Future<void> endCall(int callId) async {
    final token = await getAccessToken();
    if (token == null) return;

    try {
      await _dio.post('$_authBase/end-call', data: {'callId': callId});
    } catch (_) {}
  }

  // ---------- NOTIFICATIONS ----------

  static Future<List<NotificationItem>> getNotifications() async {
    final token = await getAccessToken();
    if (token == null) throw AuthException('Нет токена');

    try {
      final resp = await _dio.get<List<dynamic>>('$_authBase/notifications');

      final list = resp.data ?? [];
      return list.map((e) => NotificationItem.fromJson(e)).toList();
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  // ---------- ERROR PARSE ----------

  static String _extractMessage(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (status == 401) return 'Сессия истекла';
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

  static Future<void> deleteAccount() async {
    final token = await getAccessToken();
    if (token == null) throw AuthException('Вы не авторизованы');

    try {
      await _dio.delete(
        // Используем метод DELETE
        '$_authBase/delete-account',
      );

      // После успешного удаления на сервере, чистим локальные данные
      await logout();
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }

  static Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '$_authBase/reset-password',
        data: {'phone': phone, 'code': code, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw AuthException(_extractMessage(e));
    }
  }
}
