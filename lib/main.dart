import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'navigation.dart';
import 'screens/login_page.dart';
import 'services/incoming_call_notifications.dart';
import 'screens/call_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase нужен в background isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ ВАЖНО: плагин локальных уведомлений тоже инициализируем в фоне
  await initIncomingCallNotifications();

  final data = message.data;
  if (data['type'] == 'incoming_call') {
    await showIncomingCall(data);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Инициализация локальных уведомлений (канал incoming_call)
  await initIncomingCallNotifications();

  // Background handler для data-push
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Разрешения на уведомления (Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null && initial.data['type'] == 'incoming_call') {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigatorKey.currentState?.pushNamed('/call', arguments: initial.data);
  });
}
  // Сообщение пришло, когда приложение открыто
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      await showIncomingCall(data);
    }
  });

  // Пользователь тапнул по push (открыл приложение)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
  final data = message.data;
  if (data['type'] == 'incoming_call') {
    navigatorKey.currentState?.pushNamed('/call', arguments: data);
  }
});

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'IntelVT',
  debugShowCheckedModeBanner: false,
  navigatorKey: navigatorKey,
  theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
  home: const LoginPage(),
  onGenerateRoute: (settings) {
    if (settings.name == '/call') {
      final args = (settings.arguments is Map)
          ? Map<String, dynamic>.from(settings.arguments as Map)
          : <String, dynamic>{};
      return MaterialPageRoute(builder: (_) => CallPage(args: args));
    }
    return null;
  },
);
  }
}
