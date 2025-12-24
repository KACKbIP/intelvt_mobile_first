import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_client.dart';
import '../services/callkit_service.dart'; // ✅ Импорт обязателен

class CallPage extends StatefulWidget {
  final Map<String, dynamic> args;
  const CallPage({super.key, required this.args});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with WidgetsBindingObserver {
  RtcEngine? _engine;

  late final String _appId;
  late final String _channel;
  late final int _uid;
  late String _token;
  String? _callId;

  bool _badArgs = false;
  bool _initializing = true;
  bool _joined = false;
  bool _localReady = false;
  int? _remoteUid;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _finishing = false;

  StreamSubscription<RemoteMessage>? _fcmSub;
  DateTime? _lastTokenRefreshAt;
  bool _refreshingToken = false;
  Timer? _callDurationTimer;
  int _secondsInCall = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final a = widget.args;
    _appId = (a['agoraAppId'] ?? a['appId'] ?? '').toString().trim();
    _channel = (a['channelName'] ?? a['channel'] ?? '').toString().trim();
    _uid = int.tryParse((a['uid'] ?? '0').toString()) ?? 0;
    _token = (a['agoraToken'] ?? a['token'] ?? '').toString().trim();
    _callId = (a['callId'] ?? '').toString().trim();
    if (_callId != null && _callId!.isEmpty) _callId = null;

    if (_appId.isEmpty || _channel.isEmpty || _token.isEmpty) {
      _badArgs = true;
      _initializing = false;
    } else {
      _listenToCallEndedPush();
      _initAgora();
    }
  }

  void _listenToCallEndedPush() {
    _fcmSub?.cancel();
    _fcmSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'call_ended') {
        if (_callId != null && data['callId'] != null) {
          if (data['callId'].toString() != _callId) return;
        }
        _finishCall(reason: 'push:call_ended');
      }
    });
  }

  Future<void> _initAgora() async {
    try {
      if (_badArgs) return;
      final perms = await [
        Permission.microphone,
        Permission.camera,
        if (!kIsWeb && Platform.isAndroid) Permission.notification,
      ].request();

      if (perms[Permission.microphone] != PermissionStatus.granted ||
          perms[Permission.camera] != PermissionStatus.granted) {
        if (!mounted) return;
        setState(() => _initializing = false);
        return;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      await _engine!.enableVideo();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted || _finishing) return;
            setState(() {
              _joined = true;
              _localReady = true;
              _initializing = false;
            });
            _startCallTimer();
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted || _finishing) return;
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            _finishCall(reason: 'agora:user_offline');
          },
          onLeaveChannel: (connection, stats) {
            _finishCall(reason: 'agora:on_leave_channel');
          },
          onError: (err, msg) async {
            final s = (msg ?? '').toString().toLowerCase();
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

      await _engine!.joinChannel(
        token: _token,
        channelId: _channel,
        uid: _uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _startCallTimer() {
    _callDurationTimer?.cancel();
    _secondsInCall = 0;
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finishing) return;
      setState(() => _secondsInCall++);
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshTokenOnly(String why) async { /* ... старый код ... */ }
  Future<void> _refreshTokenAndRecover(String why) async { /* ... старый код ... */ }

  // 🔥 ИСПРАВЛЕННАЯ ФУНКЦИЯ ЗАВЕРШЕНИЯ 🔥
  Future<void> _finishCall({required String reason}) async {
    if (_finishing) return;
    _finishing = true;

    if (mounted) {
      setState(() {
        _joined = false;
        _remoteUid = null;
      });
    }

    // 1. Снимаем флаг "в звонке"
    CallKitService.isCallAcceptedMode = false;

    // 2. 🛑 ВКЛЮЧАЕМ БЛОКИРОВКУ (Игнор) на 3 секунды.
    // Это предотвращает повторное открытие окна звонка в main.dart
    CallKitService.ignoreActiveCalls = true;
    Future.delayed(const Duration(seconds: 3), () {
      CallKitService.ignoreActiveCalls = false;
    });

    _callDurationTimer?.cancel();
    _fcmSub?.cancel();

    // 3. Сбрасываем CallKit
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}

    // 4. API EndCall
    try {
      if (_callId != null) {
        final cid = int.tryParse(_callId!) ?? 0;
        if (cid > 0) ApiClient.endCall(cid).catchError((_) {});
      }
    } catch (_) {}

    // 5. Agora
    final engine = _engine;
    _engine = null;
    try {
      if (engine != null) {
        await Future.any([
          engine.leaveChannel(),
          Future.delayed(const Duration(milliseconds: 500)),
        ]);
        try { engine.release(); } catch (_) {}
      }
    } catch (_) {}

    if (!mounted) return;

    // 6. Уходим на главную
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _toggleMute() { setState(() => _isMuted = !_isMuted); _engine?.muteLocalAudioStream(_isMuted); }
  void _toggleVideo() { setState(() => _isVideoOff = !_isVideoOff); _engine?.muteLocalVideoStream(_isVideoOff); }
  void _switchCamera() { _engine?.switchCamera(); }

  Widget _buildRemoteVideo() {
    if (!_joined || _engine == null || _remoteUid == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: 16),
            Text(_initializing ? 'Подключение...' : 'Ожидание собеседника...', style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: _channel),
      ),
    );
  }

  Widget _buildLocalPreview() {
    if (!_localReady || _engine == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 120, height: 160, color: Colors.black,
        child: _isVideoOff ? const Center(child: Icon(Icons.videocam_off, color: Colors.white54)) : AgoraVideoView(
          controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callDurationTimer?.cancel();
    _fcmSub?.cancel();
    _engine?.release(); // fallback
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_badArgs) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Error: Bad args', style: TextStyle(color: Colors.white))));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildRemoteVideo()),
            Positioned(
              left: 16, top: 16,
              child: Text(_joined ? 'В звонке • ${_formatDuration(_secondsInCall)}' : 'Соединение...', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ),
            Positioned(right: 16, top: 56, child: _buildLocalPreview()),
            Positioned(
              left: 0, right: 0, bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleBtn(icon: _isMuted ? Icons.mic_off : Icons.mic, onTap: _toggleMute, background: Colors.white10, iconColor: Colors.white),
                  _CircleBtn(icon: Icons.call_end, onTap: () => _finishCall(reason: 'user_hangup'), background: Colors.red, iconColor: Colors.white, size: 72),
                  _CircleBtn(icon: _isVideoOff ? Icons.videocam_off : Icons.videocam, onTap: _toggleVideo, background: Colors.white10, iconColor: Colors.white),
                  _CircleBtn(icon: Icons.cameraswitch, onTap: _switchCamera, background: Colors.white10, iconColor: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color background; final Color iconColor; final double size;
  const _CircleBtn({required this.icon, required this.onTap, required this.background, required this.iconColor, this.size = 56});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: size, height: size, decoration: BoxDecoration(color: background, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: size * 0.48)),
    );
  }
}