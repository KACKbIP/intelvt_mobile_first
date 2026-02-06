import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';
import '../../../main.dart'; // Для доступа к navigatorKey
import '../api/client/api_client.dart';

class CallKitService {
  static final Uuid _uuid = const Uuid();
  static bool isCallAcceptedMode = false;
  static bool ignoreActiveCalls = false;

  /// Инициализация слушателя событий
  static void init() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      
      switch (event.event) {
        case Event.actionCallAccept:
          print('📞 [CallKitService] ACTION_CALL_ACCEPT received');
          isCallAcceptedMode = true;
          _handleCallAccepted(event.body);
          break;
          
        case Event.actionCallDecline:
          print('📞 [CallKitService] ACTION_CALL_DECLINE received');
          _handleCallEnded(event.body);
          break;
          
        case Event.actionCallEnded:
          print('📞 [CallKitService] ACTION_CALL_ENDED received');
          _handleCallEnded(event.body);
          break;
          
        default:
          break;
      }
    });
  }

  /// Показ входящего звонка
  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    print('📞 [CallKitService] showIncomingCall RAW DATA: $data');

    // ГЕНЕРАЦИЯ UUID (или берем из данных, если есть)
    final callId = data['uuid'] ?? _uuid.v4();

    // 🔥 ПАРСИНГ ДАННЫХ (ФИКС ЧЕРНОГО ЭКРАНА)
    // Твой лог показал, что данные лежат внутри ключа 'extra'.
    // Нам нужно "вытащить" их, чтобы CallPage получил channelName и token.
    Map<String, dynamic> callExtras = {};

    if (data.containsKey('extra')) {
      // Если данные пришли как JSON объект или Map
      final nestedExtra = data['extra'];
      if (nestedExtra is Map) {
        callExtras.addAll(Map<String, dynamic>.from(nestedExtra));
      } else if (nestedExtra is String) {
        // Если вдруг пришло строкой (бывает на Android)
        // callExtras.addAll(jsonDecode(nestedExtra));
      }
    } else {
      // Если структура плоская
      callExtras.addAll(data);
    }

    // Добавляем callId в extra, чтобы потом использовать при отбое
    callExtras['callId'] = callId;

    print('📞 [CallKitService] PREPARED EXTRA: $callExtras');

    final params = CallKitParams(
      id: callId,
      nameCaller: callExtras['nameCaller'] ?? data['nameCaller'] ?? 'Входящий звонок',
      appName: 'IntelVT',
      avatar: callExtras['avatarUrl'], // Если есть URL аватарки
      handle: callExtras['handle'] ?? 'Video Call',
      type: 1, // 0 - Audio, 1 - Video
      duration: 30000, // Длительность звонка (таймаут)
      textAccept: 'Принять',
      textDecline: 'Отклонить',
      extra: callExtras, // 🔥 Передаем "плоский" Map
      headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
      
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'videoChat', // Важно для Agora
        audioSessionActive: true,      // Активировать сессию при ответе
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsHolding: true,
        supportsDTMF: true,
        ringtonePath: 'system_ringtone_default',
      ),
      
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: "Incoming Call",
        missedCallNotificationChannelName: "Missed Call",
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Логика принятия звонка
  static void _handleCallAccepted(Map<dynamic, dynamic> body) {
    print('✅ [CallKitService] Handling Accepted Call. Body: $body');
    
    final extra = body['extra'] as Map<dynamic, dynamic>?;
    
    if (extra != null) {
      final args = Map<String, dynamic>.from(extra);
      
      print('🚀 [CallKitService] Navigating to /call with args: $args');
      
      // Проверка на null и навигация
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/call', arguments: args);
      } else {
        print('❌ [CallKitService] NavigatorState is NULL. Cannot navigate.');
      }
    } else {
      print('❌ [CallKitService] Extra data is NULL. Cannot start call.');
    }
  }

  /// Логика завершения звонка
  static Future<void> _handleCallEnded(Map<dynamic, dynamic> body) async {
    print('🛑 [CallKitService] Call Ended.');
    // Тут можно добавить логику отправки на бэкенд, что звонок сброшен
    /*
    final extra = body['extra'] as Map<dynamic, dynamic>?;
    if (extra != null && extra['callId'] != null) {
       // ApiClient.endCall(...)
    }
    */
  }
}