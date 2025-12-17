import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../navigation.dart';

final _notifications = FlutterLocalNotificationsPlugin();

Future<void> initIncomingCallNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  await _notifications.initialize(
    const InitializationSettings(android: androidInit),
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;

      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        navigatorKey.currentState?.pushNamed('/call', arguments: data);
      } catch (_) {
        // fallback: если вдруг пришло не JSON
        navigatorKey.currentState?.pushNamed('/call', arguments: {"callId": payload});
      }
    },
  );

  const channel = AndroidNotificationChannel(
    'incoming_call',
    'Incoming Calls',
    importance: Importance.max,
    playSound: true,
  );

  await _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> showIncomingCall(Map<String, dynamic> data) async {
  final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  await _notifications.show(
    id,
    'Входящий видеозвонок',
    (data['fromName'] ?? 'IntelVT').toString(),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'incoming_call',
        'Incoming Calls',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        ongoing: true,
        autoCancel: false,
      ),
    ),
    payload: jsonEncode(data), // ✅ ВЕСЬ DATA-ПАКЕТ
  );
}
