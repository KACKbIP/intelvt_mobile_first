import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CallPage extends StatefulWidget {
  final Map<String, dynamic> args;

  const CallPage({super.key, required this.args});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  RtcEngine? _engine;

  bool _joined = false;
  int? _remoteUid;

  String _status = 'init';
  String? _err;

  late String _appId;
  late String _channel;
  late String _token;
  late int _uid;

  void _log(String msg) {
    if (kDebugMode) debugPrint('[PARENT] $msg');
  }

  @override
  void initState() {
    super.initState();

    // Берём аргументы прямо из конструктора (а не из route)
    final args = widget.args;

    _appId = (args['agoraAppId'] ?? args['appId'] ?? '').toString();
    _channel = (args['channelName'] ?? args['channel'] ?? '').toString();
    _token = (args['agoraToken'] ?? args['token'] ?? '').toString();
    _uid = int.tryParse((args['uid'] ?? '0').toString()) ?? 0;

    _log('args: appIdLen=${_appId.length} channel=$_channel tokenLen=${_token.length} uid=$_uid');

    _initAgora();
  }

  Future<void> _initAgora() async {
    try {
      if (_appId.isEmpty || _channel.isEmpty || _token.isEmpty || _uid == 0) {
        if (!mounted) return;
        setState(() {
          _status = 'bad args';
          _err = 'appId/channel/token/uid пустые';
        });
        return;
      }

      if (!mounted) return;
      setState(() => _status = 'permissions...');

      await [Permission.microphone, Permission.camera].request();

      if (!mounted) return;
      setState(() => _status = 'engine init...');

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: _appId));

      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _log('join success ch=${connection.channelId} localUid=${connection.localUid}');
          if (!mounted) return;
          setState(() {
            _joined = true;
            _status = 'joined uid=${connection.localUid}';
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _log('remote joined uid=$remoteUid');
          if (!mounted) return;
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          _log('remote offline uid=$remoteUid reason=$reason');
          if (!mounted) return;
          setState(() => _remoteUid = null);
        },
        onError: (err, msg) {
          _log('ERROR $err $msg');
          if (!mounted) return;
          setState(() {
            _err = '$err $msg';
            _status = 'error';
          });
        },
        onConnectionStateChanged: (connection, state, reason) {
          _log('connState=$state reason=$reason');
          if (!mounted) return;
          setState(() => _status = 'connState=$state reason=$reason');
        },
      ));

      await engine.enableVideo();
      await engine.startPreview();

      if (!mounted) return;
      setState(() => _status = 'joining...');

      await engine.joinChannel(
        token: _token,
        channelId: _channel,
        uid: _uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      _engine = engine;
    } catch (e) {
      _log('init exception: $e');
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _status = 'init exception';
      });
    }
  }

  Future<void> _hangUp() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bad = _appId.isEmpty || _channel.isEmpty || _token.isEmpty || _uid == 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Видеозвонок'),
        actions: [
          IconButton(onPressed: _hangUp, icon: const Icon(Icons.call_end)),
        ],
      ),
      body: bad
          ? const Center(
              child: Text(
                'Пустые данные appId/channel/token/uid',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: _remoteUid == null
                      ? const Center(
                          child: Text(
                            'Ожидание подключения…',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        )
                      : AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: _remoteUid),
                            connection: RtcConnection(channelId: _channel),
                          ),
                        ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  width: 160,
                  height: 220,
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                    child: _joined && _engine != null
                        ? AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: _engine!,
                              canvas: VideoCanvas(uid: _uid),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'status: $_status\n'
                      'ch: $_channel\n'
                      'uid(local): $_uid\n'
                      'tokenLen: ${_token.length}\n'
                      'remoteUid: ${_remoteUid ?? "-"}\n'
                      'err: ${_err ?? "-"}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
