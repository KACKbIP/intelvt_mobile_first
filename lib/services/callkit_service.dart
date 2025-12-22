import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';
import '../navigation.dart'; // Убедитесь, что здесь лежит navigatorKey
import 'api_client.dart';

class CallKitService {
  static final Uuid _uuid = const Uuid();

  // ✅ Теперь этот метод вызываем из MyApp, чтобы UI был готов
  static void init() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      
      debugPrint("📞 CallKit Event: ${event.event}");

      switch (event.event) {
        // 1. Нажали кнопку "Принять"
        case Event.actionCallAccept:
          _handleCallAccepted(event.body);
          break;

        // 2. Нажали на САМО УВЕДОМЛЕНИЕ (открыли приложение)
        // Часто Android шлет это событие вместо Accept, если приложение было свернуто
        case Event.actionCallStart:
          _handleCallAccepted(event.body);
          break;

        // 3. Другие способы открытия
        case Event.actionCallCallback:
          _handleCallAccepted(event.body);
          break;

        // Сброс звонка
        case Event.actionCallDecline:
        case Event.actionCallEnded:
          _handleCallEnded(event.body);
          break;

        default:
          break;
      }
    });
  }

  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    debugPrint("========== INCOMING PUSH DATA ==========");
    debugPrint(jsonEncode(data));

    final uuid = _uuid.v4();

    // Парсим данные
    final String appId = data['appId'] ?? data['appid'] ?? data['agoraAppId'] ?? '';
    final String channelName = data['channelName'] ?? '';
    final String token = data['agoraToken'] ?? data['token'] ?? '';
    final String uid = data['uid']?.toString() ?? '0';
    final String callId = data['callId']?.toString() ?? '0';
    final String callerName = data['fromName'] ?? 'Видеозвонок IntelVT';

    final params = CallKitParams(
      id: uuid,
      nameCaller: callerName,
      appName: 'IntelVT',
      avatar: null,
      handle: 'Входящий видеозвонок',
      type: 1, 
      duration: 45000,
      textAccept: 'Ответить',
      textDecline: 'Сбросить',
      
      // Данные для экрана звонка
      extra: <String, dynamic>{
        'appId': appId,
        'channelName': channelName,
        'agoraToken': token,
        'uid': uid,
        'callId': callId,
      },
      
      headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
      
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#202124',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: "Входящие звонки",
        isShowCallID: false,
        isShowFullLockedScreen: true,
      ),
      
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'videoChat',
        audioSessionActive: true,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  // --- ЛОГИКА ПЕРЕХОДА ---
  static Future<void> _handleCallAccepted(Map<dynamic, dynamic> body) async {
    debugPrint("✅ Call Accepted. Готовим переход...");

    final extra = body['extra'] as Map<dynamic, dynamic>?;
    
    if (extra != null) {
      final args = Map<String, dynamic>.from(extra);
      
      // 1. Пробуем перейти сразу (если мы в приложении)
      if (navigatorKey.currentState != null) {
        debugPrint("🚀 (Instant) Navigating to CallPage...");
        navigatorKey.currentState!.pushNamed('/call', arguments: args);
        return;
      }

      // 2. Если навигатор не готов (холодный старт), ждем
      debugPrint("⏳ Навигатор не готов, ждем 800мс...");
      await Future.delayed(const Duration(milliseconds: 800));

      if (navigatorKey.currentState != null) {
        debugPrint("🚀 (Delayed) Navigating to CallPage...");
        navigatorKey.currentState!.pushNamed('/call', arguments: args);
      } else {
        debugPrint("⛔ FATAL: Navigator is NULL even after delay.");
      }
    } else {
      debugPrint("⛔ ERROR: Extra data is null.");
    }
  }

  static Future<void> _handleCallEnded(Map<dynamic, dynamic> body) async {
    final extra = body['extra'] as Map<dynamic, dynamic>?;
    if (extra != null && extra['callId'] != null) {
      final callId = int.tryParse(extra['callId'].toString());
      if (callId != null) {
        try {
          await ApiClient.endCall(callId);
        } catch (_) {}
      }
    }
  }
}