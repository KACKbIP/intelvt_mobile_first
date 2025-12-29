import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_client.dart';
import '../services/callkit_service.dart';

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
  bool _isSpeakerOn = true; // По умолчанию громкая связь для видео

  StreamSubscription<RemoteMessage>? _fcmSub;
  Timer? _callDurationTimer;
  int _secondsInCall = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    final a = widget.args;
    // Парсим аргументы с защитой от null
    _appId = (a['agoraAppId'] ?? a['appId'] ?? '').toString().trim();
    _channel = (a['channelName'] ?? a['channel'] ?? '').toString().trim();
    _uid = int.tryParse((a['uid'] ?? '0').toString()) ?? 0;
    _token = (a['agoraToken'] ?? a['token'] ?? '').toString().trim();
    _callId = (a['callId'] ?? '').toString().trim();
    if (_callId != null && _callId!.isEmpty) _callId = null;

    print("🟢 [CallPage] Init with: channel=$_channel, uid=$_uid");

    if (_appId.isEmpty || _channel.isEmpty || _token.isEmpty) {
      print("🔴 [CallPage] BAD ARGS detected!");
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

      // 1. Запрашиваем права
      final perms = await [
        Permission.microphone,
        Permission.camera,
        if (!kIsWeb && Platform.isAndroid) Permission.notification,
      ].request();

      if (perms[Permission.microphone] != PermissionStatus.granted ||
          perms[Permission.camera] != PermissionStatus.granted) {
        print("🔴 [CallPage] Permissions denied");
        if (!mounted) return;
        setState(() => _initializing = false);
        return;
      }

      // 2. Инициализация движка
      _engine = createAgoraRtcEngine();
      
      await _engine!.initialize(RtcEngineContext(
        appId: _appId,
        // 🔥 ВАЖНО: Для видеозвонка 1-на-1 используем COMMUNICATION
        channelProfile: ChannelProfileType.channelProfileCommunication,
        // 🔥 ВАЖНО: Default сценарий лучше всего работает с CallKit
        audioScenario: AudioScenarioType.audioScenarioDefault, 
      ));

      // 3. Настройка обработчиков событий
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            print("✅ [Agora] Joined Channel: ${connection.channelId}");
            if (!mounted || _finishing) return;
            setState(() {
              _joined = true;
              _localReady = true;
              _initializing = false;
            });
            _startCallTimer();
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            print("✅ [Agora] Remote User Joined: $remoteUid");
            if (!mounted || _finishing) return;
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            print("⚠️ [Agora] Remote User Offline: $reason");
            _finishCall(reason: 'agora:user_offline');
          },
          onLeaveChannel: (connection, stats) {
            print("⚠️ [Agora] Left Channel");
          },
          onError: (err, msg) {
            print("❌ [Agora] Error: $err, Msg: $msg");
          },
        ),
      );

      // 4. Включаем видео
      await _engine!.enableVideo();
      await _engine!.startPreview();

      // 5. Джойнимся в канал
      await _engine!.joinChannel(
        token: _token,
        channelId: _channel,
        uid: _uid,
        options: const ChannelMediaOptions(
          // Для Communication профиля роль Broadcaster ставится автоматически, но можно явно указать
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      
      // По умолчанию включаем динамик (громкая связь) для видео
      await _engine!.setEnableSpeakerphone(true);

    } catch (e) {
      print("❌ [CallPage] Exception in _initAgora: $e");
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

  Future<void> _finishCall({required String reason}) async {
    print("🛑 [CallPage] Finishing call. Reason: $reason");
    if (_finishing) return;
    _finishing = true;

    if (mounted) {
      setState(() {
        _joined = false;
        _remoteUid = null;
      });
    }

    CallKitService.isCallAcceptedMode = false;
    
    // Блокировка повторного открытия CallKit
    CallKitService.ignoreActiveCalls = true;
    Future.delayed(const Duration(seconds: 3), () {
      CallKitService.ignoreActiveCalls = false;
    });

    _callDurationTimer?.cancel();
    _fcmSub?.cancel();

    // Завершаем в CallKit
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      print("Error ending CallKit: $e");
    }

    // Отправляем на бэк
    try {
      if (_callId != null) {
        final cid = int.tryParse(_callId!) ?? 0;
        if (cid > 0) ApiClient.endCall(cid).catchError((_) {});
      }
    } catch (_) {}

    // Убиваем Agora
    final engine = _engine;
    _engine = null;
    try {
      if (engine != null) {
        await engine.leaveChannel();
        await engine.release();
      }
    } catch (e) {
      print("Error releasing Agora: $e");
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _toggleMute() { 
    setState(() => _isMuted = !_isMuted); 
    _engine?.muteLocalAudioStream(_isMuted); 
  }
  
  void _toggleVideo() { 
    setState(() => _isVideoOff = !_isVideoOff); 
    _engine?.muteLocalVideoStream(_isVideoOff); 
  }
  
  void _switchCamera() { 
    _engine?.switchCamera(); 
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _engine?.setEnableSpeakerphone(_isSpeakerOn);
  }

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
            Text(
              _initializing ? 'Инициализация...' : 'Ожидание собеседника...', 
              style: const TextStyle(color: Colors.white54)
            ),
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
        child: _isVideoOff 
          ? const Center(child: Icon(Icons.videocam_off, color: Colors.white54)) 
          : AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine!, 
                canvas: const VideoCanvas(uid: 0) // 0 для локального видео
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callDurationTimer?.cancel();
    _fcmSub?.cancel();
    // На всякий случай, если finishCall не вызвался
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_badArgs) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Ошибка соединения (Args)', style: TextStyle(color: Colors.white))));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Видео собеседника (на весь экран)
            Positioned.fill(child: _buildRemoteVideo()),
            
            // 2. Статус и таймер
            Positioned(
              left: 16, top: 16,
              child: SafeArea(
                child: Text(
                  _joined ? 'В звонке • ${_formatDuration(_secondsInCall)}' : 'Соединение...', 
                  style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black)])
                ),
              ),
            ),

            // 3. Локальное видео (сверху справа)
            Positioned(
              right: 16, top: 16, 
              child: SafeArea(child: _buildLocalPreview())
            ),

            // 4. Панель управления
            Positioned(
              left: 20, right: 20, bottom: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleBtn(
                      icon: _isMuted ? Icons.mic_off : Icons.mic, 
                      onTap: _toggleMute, 
                      background: _isMuted ? Colors.white : Colors.white24, 
                      iconColor: _isMuted ? Colors.black : Colors.white
                    ),
                    _CircleBtn(
                      icon: _isVideoOff ? Icons.videocam_off : Icons.videocam, 
                      onTap: _toggleVideo, 
                      background: _isVideoOff ? Colors.white : Colors.white24, 
                      iconColor: _isVideoOff ? Colors.black : Colors.white
                    ),
                    _CircleBtn(
                      icon: Icons.cameraswitch, 
                      onTap: _switchCamera, 
                      background: Colors.white24, 
                      iconColor: Colors.white
                    ),
                    _CircleBtn(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.phone_in_talk, 
                      onTap: _toggleSpeaker, 
                      background: Colors.white24, 
                      iconColor: Colors.white
                    ),
                    _CircleBtn(
                      icon: Icons.call_end, 
                      onTap: () => _finishCall(reason: 'user_hangup'), 
                      background: Colors.red, 
                      iconColor: Colors.white, 
                      size: 64
                    ),
                  ],
                ),
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
  const _CircleBtn({required this.icon, required this.onTap, required this.background, required this.iconColor, this.size = 50});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size, 
        decoration: BoxDecoration(color: background, shape: BoxShape.circle), 
        child: Icon(icon, color: iconColor, size: size * 0.5)
      ),
    );
  }
}