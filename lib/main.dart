import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'firebase_options.dart';
import 'src/features/auth/presentation/pages/login_page.dart';
import 'src/features/calls/presentation/pages/call_page.dart';
import 'src/features/auth/presentation/pages/pin_code_page.dart';
import 'src/core/services/callkit_service.dart';
import 'src/core/api/client/api_client.dart';
import 'src/core/services/security_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, dynamic>? _initialCallArgs;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('🌙 [Background] Push received: ${message.data}');
  
  final data = message.data;
  // Проверяем тип пуша, чтобы не реагировать на обычные сообщения как на звонок
  // (Адаптируй под свои ключи, если type приходит в другом месте)
  if (data['type'] == 'incoming_call' || (data['extra'] != null && data['extra'].toString().contains('incoming_call'))) {
    await CallKitService.showIncomingCall(data);
  } else if (data['type'] == 'call_ended') {
    await FlutterCallkitIncoming.endAllCalls();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Инициализация сервиса звонков
  CallKitService.init();
  
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // 🔥 ХОЛОДНЫЙ СТАРТ: Проверяем, было ли приложение открыто кликом по "Принять"
  try {
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List && calls.isNotEmpty) {
      print('❄️ [Main] Found active calls on cold start: $calls');
      final lastCall = calls.last;
      if (lastCall['extra'] != null) {
        _initialCallArgs = Map<String, dynamic>.from(lastCall['extra']);
        CallKitService.isCallAcceptedMode = true; 
        print('❄️ [Main] Restored args: $_initialCallArgs');
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
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupForegroundPushListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 Lifecycle changed: $state');
    if (state == AppLifecycleState.resumed) {
      _checkActiveCallsOnResume();
    }
  }

  Future<void> _checkActiveCallsOnResume() async {
    if (CallKitService.ignoreActiveCalls) {
      debugPrint('[MAIN] Ignoring active calls (cooldown)');
      return;
    }

    // Небольшая задержка, чтобы CallKit успел обновить статус
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      var calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        final lastCall = calls.last;
        print('⚡ [Resume] Active call found: ${lastCall['id']}');
        
        if (lastCall['extra'] != null) {
          final args = Map<String, dynamic>.from(lastCall['extra']);
          
          bool isAlreadyInCall = false;
          navigatorKey.currentState?.popUntil((route) {
            if (route.settings.name == '/call') isAlreadyInCall = true;
            return true; 
          });

          if (!isAlreadyInCall) {
             print('⚡ [Resume] Navigating to /call');
             CallKitService.isCallAcceptedMode = true;
             navigatorKey.currentState?.pushNamed('/call', arguments: args);
          } else {
             print('⚡ [Resume] Already in /call screen');
          }
        }
      }
    } catch (e) {
      print('Error on resume check: $e');
    }
  }

  void _setupForegroundPushListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('☀️ [Foreground] Push received: ${message.data}');
      final data = message.data;
      if (data['type'] == 'incoming_call') {
        await CallKitService.showIncomingCall(data);
      } else if (data['type'] == 'call_ended') {
        await FlutterCallkitIncoming.endAllCalls();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntelVT Parent',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthCheckScreen(initialCallArgs: widget.initialCallArgs),
        '/call': (context) {
          final args = (ModalRoute.of(context)?.settings.arguments is Map)
              ? Map<String, dynamic>.from(ModalRoute.of(context)?.settings.arguments as Map)
              : <String, dynamic>{};
          print('🖥️ [Route] Opening /call with args: $args');
          return CallPage(args: args);
        }
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  final Map<String, dynamic>? initialCallArgs;
  const AuthCheckScreen({super.key, this.initialCallArgs});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (CallKitService.ignoreActiveCalls) {
      debugPrint('[AuthCheck] Ignoring start args because of cooldown');
      await _checkAuth();
      return;
    }

    // ХОЛОДНЫЙ СТАРТ ЗВОНКА (Приложение было закрыто)
    if (widget.initialCallArgs != null || CallKitService.isCallAcceptedMode) {
      print('🚀 [AuthCheck] Cold start detected, going to call immediately');
      final args = widget.initialCallArgs ?? {}; 
      
      // Используем addPostFrameCallback, чтобы навигация сработала после построения виджета
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/call', arguments: args);
      });
      return;
    }

    await _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Твоя логика авторизации без изменений
    final token = await ApiClient.getAccessToken();
    if (token == null || token.isEmpty) {
      _navTo(const LoginPage());
      return;
    }

    final userId = await ApiClient.getUserId();
    final phone = await ApiClient.getPhone();
    
    if (userId == null || phone == null) {
      _navTo(const LoginPage());
      return;
    }

    final hasPin = await SecurityService.hasPin();
    if (hasPin) {
      _navTo(PinCodePage(mode: PinMode.auth, userId: userId, phone: phone));
    } else {
      _navTo(PinCodePage(mode: PinMode.create, userId: userId, phone: phone));
    }
  }

  void _navTo(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}