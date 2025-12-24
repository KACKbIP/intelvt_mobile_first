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
  static bool isCallAcceptedMode = false;
  static bool ignoreActiveCalls = false;

  static void init() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallAccept:
          isCallAcceptedMode = true;
          _handleCallAccepted(event.body);
          break;
        case Event.actionCallDecline:
          // Логика отклонения
          break;
        default:
          break;
      }
    });
  }

  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    final callId = _uuid.v4();
    
    final params = CallKitParams(
      id: callId,
      nameCaller: data['fromName'] ?? 'IntelVT',
      appName: 'IntelVT',
      avatar: 'https://i.pravatar.cc/100',
      handle: 'Video Call',
      type: 1, // 0 - Audio, 1 - Video
      extra: data,
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'videoChat',
        audioSessionActive: true,
        ringtonePath: 'system_ringtone_default', // Системный звук
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static void _handleCallAccepted(Map<dynamic, dynamic> body) {
    final extra = body['extra'] as Map<dynamic, dynamic>?;
    if (extra != null) {
      final args = Map<String, dynamic>.from(extra);
      if (navigatorKey.currentState != null) {
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