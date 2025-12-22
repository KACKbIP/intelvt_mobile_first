import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/call_page.dart';
import 'screens/pin_code_page.dart';
// import 'screens/main_navigation_page.dart';
import 'services/callkit_service.dart';
import 'services/api_client.dart';
import 'services/security_service.dart';

// ✅ Глобальный ключ навигации
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Переменная для холодного старта
Map<String, dynamic>? _initialCallArgs;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = message.data;
  if (data['type'] == 'incoming_call') {
    await CallKitService.showIncomingCall(data);
  } else if (data['type'] == 'call_ended') {
    await FlutterCallkitIncoming.endAllCalls();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Фоновый обработчик
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Проверка "холодного" звонка (когда приложение было полностью убито)
  try {
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List && calls.isNotEmpty) {
      final lastCall = calls.last;
      if (lastCall['extra'] != null) {
        _initialCallArgs = Map<String, dynamic>.from(lastCall['extra']);
      }
    }
  } catch (e) {
    debugPrint("Error checking active calls: $e");
  }

  runApp(MyApp(initialCallArgs: _initialCallArgs));
}

class MyApp extends StatefulWidget {
  final Map<String, dynamic>? initialCallArgs;
  const MyApp({super.key, this.initialCallArgs});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _coldStartHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // ✅ 1. Инициализируем слушатель событий ЗДЕСЬ, когда виджеты уже готовы
    CallKitService.init();
    
    // ✅ 2. Слушаем пуши в открытом приложении
    _setupForegroundPushListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ "Страховка": Проверяем звонки, когда приложение выходит на передний план
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("📱 App Resumed: Проверяем потерянные звонки...");
      _recoverActiveCall();
    }
  }

  Future<void> _recoverActiveCall() async {
    try {
      var calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        final lastCall = calls.last;
        final extra = lastCall['extra'] as Map<dynamic, dynamic>?;

        // Если звонок висит в активных, значит мы его (возможно) приняли, но не перешли
        if (extra != null) {
          final args = Map<String, dynamic>.from(extra);
          
          // Проверяем, не открыт ли уже экран звонка
          bool isAlreadyCalling = false;
          navigatorKey.currentState?.popUntil((route) {
            if (route.settings.name == '/call') isAlreadyCalling = true;
            return true;
          });

          if (!isAlreadyCalling) {
             debugPrint("🔥 Нашли потерянный звонок! Открываем экран...");
             navigatorKey.currentState?.pushNamed('/call', arguments: args);
          }
        }
      }
    } catch (_) {}
  }

  void _setupForegroundPushListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final data = message.data;
      if (data['type'] == 'incoming_call') {
        await CallKitService.showIncomingCall(data);
      } else if (data['type'] == 'call_ended') {
        await FlutterCallkitIncoming.endAllCalls();
        if (navigatorKey.currentState?.canPop() ?? false) {
           navigatorKey.currentState?.popUntil((route) => route.settings.name != '/call');
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обработка звонка при холодном старте (только 1 раз)
    if (!_coldStartHandled && widget.initialCallArgs != null) {
      _coldStartHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamed('/call', arguments: widget.initialCallArgs);
      });
    }
  }

  // ... (Ваш метод _getStartScreen и build без изменений)
  Future<Widget> _getStartScreen() async {
    final token = await ApiClient.getAccessToken();
    if (token == null || token.isEmpty) return const LoginPage();
    
    final userId = await ApiClient.getUserId();
    final phone = await ApiClient.getPhone();
    if (userId == null || phone == null) return const LoginPage();

    final hasPin = await SecurityService.hasPin();
    return hasPin 
        ? PinCodePage(mode: PinMode.auth, userId: userId, phone: phone)
        : PinCodePage(mode: PinMode.create, userId: userId, phone: phone);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntelVT Parent',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // ✅ ОБЯЗАТЕЛЬНО
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: FutureBuilder<Widget>(
        future: _getStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data ?? const LoginPage();
        },
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/call') {
          final args = (settings.arguments is Map) 
              ? Map<String, dynamic>.from(settings.arguments as Map) 
              : <String, dynamic>{};
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => CallPage(args: args),
          );
        }
        return null;
      },
    );
  }
}