import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import '/services/api_client.dart';

class PushDeviceService {
  Future<void> registerDevice() async {
    // Запрашиваем разрешения на пуши (важно для iOS)
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await FirebaseMessaging.instance.getToken();
      print('FCM TOKEN => $token');

      // Регистрируем устройство (платформа определится внутри ApiClient)
      await ApiClient.registerDevice(
    deviceName: Platform.isAndroid ? 'Parent Android' : 'Parent iOS'
  );
      ApiClient.listenTokenRefresh();
    } else {
      print('User declined push permissions');
    }
  }
}