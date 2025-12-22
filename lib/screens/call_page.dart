import 'dart:async'; // Добавил для StreamSubscription
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Добавил для перехвата пуша
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../services/api_client.dart';

class CallPage extends StatefulWidget {
  final Map<String, dynamic> args;
  const CallPage({super.key, required this.args});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  RtcEngine? _engine;
  StreamSubscription<RemoteMessage>? _fcmSubscription; // Подписка на пуши

  bool _joined = false;
  int? _remoteUid;
  bool _localUserJoined = false;

  // Состояния кнопок
  bool _isMuted = false;
  bool _isVideoOff = false;

  late final String _appId;
  late final String _channel;
  late int _uid;
  late String _token;
  
  // ID звонка для проверки (если передается в args)
  String? _callId; 

  // Настройки сети
  static const bool _forceTcp = true;
  static const bool _enableProxy = true;

  bool _refreshingToken = false;
  DateTime? _lastTokenRefreshAt;

  void _log(String msg) {
    if (kDebugMode) debugPrint('[PARENT] $msg');
  }

  bool get _badArgs => _appId.isEmpty || _channel.isEmpty || _uid <= 0;

  @override
  void initState() {
    super.initState();
    final a = widget.args;

    _appId = (a['agoraAppId'] ?? a['appId'] ?? '').toString();
    _channel = (a['channelName'] ?? a['channel'] ?? '').toString().trim();
    _uid = int.tryParse((a['uid'] ?? '0').toString()) ?? 0;
    _token = (a['agoraToken'] ?? a['token'] ?? '').toString();
    _callId = (a['callId'] ?? '').toString();

    _initAgora();
    _listenToCallEndedPush(); // ✅ Слушаем отмену звонка
  }

  // ✅ Слушаем "тихий" пуш об отмене звонка прямо на этом экране
  void _listenToCallEndedPush() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      // Бэкенд KioskController.cs шлет type="call_ended"
      if (data['type'] == 'call_ended') {
        _log('Получен пуш о завершении звонка. Закрываем экран.');
        // Проверяем ID звонка, если он есть, чтобы не закрыть чужой (опционально)
        if (_callId != null && data['callId'] != null) {
          if (data['callId'].toString() != _callId) return;
        }
        _onCallEnd();
      }
    });
  }

  Future<void> _initAgora() async {
    try {
      if (_badArgs) return;

      final res = await [
        Permission.microphone,
        Permission.camera,
        if (!kIsWeb && Platform.isAndroid) Permission.notification,
      ].request();

      if (res[Permission.microphone] != PermissionStatus.granted ||
          res[Permission.camera] != PermissionStatus.granted) {
        _log('Permissions denied');
        return;
      }

      final engine = createAgoraRtcEngine();

      await engine.initialize(
        RtcEngineContext(
          appId: _appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engine = engine;

      if (_forceTcp) await engine.setParameters('{"rtc.force_tcp":true}');
      if (_enableProxy) {
        await engine.setParameters('{"rtc.enable_proxy":true}');
        await engine.setParameters('{"rtc.use_cloud_proxy":true}');
      }

      await engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 360),
          frameRate: 15,
          bitrate: 400,
        ),
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onConnectionStateChanged: (connection, state, reason) async {
            _log('connState=$state reason=$reason');
            if (reason == ConnectionChangedReasonType.connectionChangedInvalidToken) {
              await _refreshTokenAndRecover('reason=InvalidToken');
            }
          },
          onJoinChannelSuccess: (connection, elapsed) {
            _log('join success');
            if (!mounted) return;
            setState(() {
              _joined = true;
              _localUserJoined = true;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            _log('remote joined uid=$remoteUid');
            if (!mounted) return;
            setState(() => _remoteUid = remoteUid);
          },
          // ✅ ГЛАВНОЕ ИСПРАВЛЕНИЕ:
          // Когда киоск отключается (finishCall), приходит это событие.
          // Раньше мы просто удаляли видео, теперь мы завершаем звонок.
          onUserOffline: (connection, remoteUid, reason) {
            _log('remote offline uid=$remoteUid -> FINISHING CALL');
            _onCallEnd(); 
          },
          onError: (err, msg) async {
            _log('ERROR $err $msg');
            final s = ('$msg').toLowerCase();
            if (s.contains('invalid token') || s.contains('token')) {
              await _refreshTokenAndRecover('onError token');
            }
          },
          onRequestToken: (connection) async {
            await _refreshTokenAndRecover('onRequestToken');
          },
          onTokenPrivilegeWillExpire: (connection, token) async {
            await _refreshTokenOnly('willExpire');
          },
        ),
      );

      await engine.enableAudio();
      await engine.enableVideo();
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.startPreview();

      if (_token.isEmpty) {
        _token = await ApiClient.getRtcToken(channel: _channel, uid: _uid);
      }

      await engine.joinChannel(
        token: _token,
        channelId: _channel,
        uid: _uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      _log('init exception: $e');
    }
  }

  Future<void> _refreshTokenOnly(String why) async {
    if (_refreshingToken) return;
    _refreshingToken = true;
    try {
      final newToken = await ApiClient.getRtcToken(channel: _channel, uid: _uid);
      _token = newToken;
      await _engine?.renewToken(newToken);
    } catch (e) {
      _log('refreshTokenOnly error: $e');
    } finally {
      _refreshingToken = false;
    }
  }

  Future<void> _refreshTokenAndRecover(String why) async {
    final now = DateTime.now();
    if (_lastTokenRefreshAt != null &&
        now.difference(_lastTokenRefreshAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastTokenRefreshAt = now;
    if (_refreshingToken) return;
    _refreshingToken = true;

    try {
      final newToken = await ApiClient.getRtcToken(channel: _channel, uid: _uid);
      _token = newToken;
      final engine = _engine;
      if (engine == null) return;

      await engine.renewToken(newToken);
      if (!_joined) {
        try {
          await engine.leaveChannel();
        } catch (_) {}
        await engine.joinChannel(
          token: _token,
          channelId: _channel,
          uid: _uid,
          options: const ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      }
    } catch (e) {
      _log('refreshTokenAndRecover error: $e');
    } finally {
      _refreshingToken = false;
    }
  }

  // --- Действия пользователя ---

  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _onToggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    _engine?.muteLocalVideoStream(_isVideoOff);
  }

  void _onSwitchCamera() {
    _engine?.switchCamera();
  }

  Future<void> _onCallEnd() async {
    // Отписываемся от пушей
    _fcmSubscription?.cancel();
    
    // Сбрасываем CallKit (чтобы не висел в шторке)
    await FlutterCallkitIncoming.endAllCalls();
    
    try {
      // Пытаемся сообщить бэку (опционально, если есть метод)
      // В вашем api_client есть endCall, можно дернуть его:
      if (_callId != null) {
         try {
           final cid = int.tryParse(_callId!);
           if (cid != null) await ApiClient.endCall(cid);
         } catch(_) {}
      }

      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}

    if (!mounted) return;
    // Закрываем экран, возвращаемся назад
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_badArgs) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Ошибка: Неверные данные звонка', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Основной слой - Видео собеседника
          _buildRemoteVideo(),

          // 2. Локальное видео (PiP)
          _buildLocalVideo(),

          // 3. Панель управления (Кнопки)
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_remoteUid != null && _engine != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: _channel),
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: 20),
            Text(
              // Если joined = false, значит мы еще коннектимся
              // Если joined = true, но remoteUid = null — значит ждем собеседника
              _joined ? 'Ожидание подключения терминала...' : 'Подключение к серверу...',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildLocalVideo() {
    if (!_localUserJoined || _engine == null) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      top: 50 + MediaQuery.of(context).viewPadding.top,
      width: 110,
      height: 150,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _isVideoOff
              ? Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white54),
                  ),
                )
              : AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ToolButton(
              onTap: _onToggleMute,
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              backgroundColor: _isMuted ? Colors.white : Colors.white24,
              iconColor: _isMuted ? Colors.black : Colors.white,
            ),
            _ToolButton(
              onTap: _onCallEnd,
              icon: Icons.call_end,
              backgroundColor: Colors.redAccent,
              iconColor: Colors.white,
              size: 72,
            ),
            _ToolButton(
              onTap: _onToggleVideo,
              icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
              backgroundColor: _isVideoOff ? Colors.white : Colors.white24,
              iconColor: _isVideoOff ? Colors.black : Colors.white,
            ),
             _ToolButton(
              onTap: _onSwitchCamera,
              icon: Icons.cameraswitch,
              backgroundColor: Colors.white24,
              iconColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  const _ToolButton({
    required this.onTap,
    required this.icon,
    this.backgroundColor = Colors.white24,
    this.iconColor = Colors.white,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}