import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';
import '../navigation.dart';
import 'api_client.dart';

class CallKitService {
  static final Uuid _uuid = const Uuid();

  // Флаг: если true — значит мы в режиме звонка
  static bool isCallAcceptedMode = false;

  // 🔥 ФЛАГ БЛОКИРОВКИ: Если true — игнорируем любые попытки открыть звонок
  // (используется сразу после завершения, чтобы не попасть в петлю)
  static bool ignoreActiveCalls = false;

  static void init() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallAccept:
        case Event.actionCallStart:
        case Event.actionCallCallback:
          isCallAcceptedMode = true;
          _handleCallAccepted(event.body);
          break;
        case Event.actionCallDecline:
        case Event.actionCallEnded:
          isCallAcceptedMode = false;
          _handleCallEnded(event.body);
          break;
        default:
          break;
      }
    });
  }

  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    final uuid = _uuid.v4();
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

  static void _handleCallAccepted(Map<dynamic, dynamic> body) {
    final extra = body['extra'] as Map<dynamic, dynamic>?;
    if (extra != null) {
      final args = Map<String, dynamic>.from(extra);
      
      // Если навигатор уже готов (приложение активно) — переходим.
      // Если нет — AuthCheckScreen (в main.dart) сам подхватит флаг isCallAcceptedMode
      if (navigatorKey.currentState != null) {
        // Очищаем стек от возможных дублей
        navigatorKey.currentState!.popUntil((route) => route.settings.name != '/call');
        navigatorKey.currentState!.pushNamed('/call', arguments: args);
      }
    }
  }

  static Future<void> _handleCallEnded(Map<dynamic, dynamic> body) async {
    final extra = body['extra'] as Map<dynamic, dynamic>?;
    if (extra != null && extra['callId'] != null) {
      final callId = int.tryParse(extra['callId'].toString());
      if (callId != null) {
        try { await ApiClient.endCall(callId); } catch (_) {}
      }
    }
  }
}