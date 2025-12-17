import 'package:firebase_messaging/firebase_messaging.dart';
import '/services/api_client.dart';

class PushDeviceService {
  Future<void> registerDevice() async {
    await FirebaseMessaging.instance.requestPermission();

    final token = await FirebaseMessaging.instance.getToken();
    print('FCM TOKEN => $token');

    await ApiClient.registerDevice(deviceName: 'Parent Android');
    ApiClient.listenTokenRefresh(deviceName: 'Parent Android');
  }
}
