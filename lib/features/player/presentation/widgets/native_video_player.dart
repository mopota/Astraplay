import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class NativeVideoPlayer extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? headers;
  final void Function(NativePlayerController controller)? onCreated;

  const NativeVideoPlayer({
    super.key,
    required this.url,
    required this.title,
    this.headers,
    this.onCreated,
  });

  @override
  State<NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends State<NativeVideoPlayer> {
  NativePlayerController? _controller;

  @override
  Widget build(BuildContext context) {
    const String viewType = 'astraplay/native_player';
    final Map<String, dynamic> creationParams = {
      'url': widget.url,
      'title': widget.title,
      'headers': widget.headers,
    };

    if (Platform.isAndroid) {
      return PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () {
              params.onFocusChanged(true);
            },
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener(_onPlatformViewCreated)
            ..create();
        },
      );
    } else if (Platform.isIOS) {
      return UiKitView(
        viewType: viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const Center(child: Text('Platform not supported'));
  }

  void _onPlatformViewCreated(int id) {
    _controller = NativePlayerController(id);
    if (widget.onCreated != null) {
      widget.onCreated!(_controller!);
    }
  }
}

class NativePlayerController extends ChangeNotifier {
  final int id;
  late MethodChannel _channel;

  bool isPlaying = false;
  String playbackState = 'IDLE';
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration bufferedPosition = Duration.zero;
  Size videoSize = Size.zero;
  Map<String, dynamic> tracks = {'video': [], 'audio': [], 'subtitles': []};
  String? error;
  bool isInPiP = false;

  DateTime? _lastSeekTime;

  NativePlayerController(this.id) {
    _channel = MethodChannel('astraplay/native_player_$id');
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPiPModeChanged':
        isInPiP = call.arguments['isInPiP'];
        notifyListeners();
        break;
      case 'onPlaybackStateChanged':
        playbackState = call.arguments['state'];
        notifyListeners();
        break;
      case 'onIsPlayingChanged':
        isPlaying = call.arguments['isPlaying'];
        notifyListeners();
        break;
      case 'onProgress':
        // Ignore progress updates for 2 seconds after a seek to prevent jump-back
        if (_lastSeekTime != null && 
            DateTime.now().difference(_lastSeekTime!) < const Duration(seconds: 2)) {
          return;
        }
        position = Duration(milliseconds: call.arguments['position']);
        duration = Duration(milliseconds: call.arguments['duration']);
        bufferedPosition = Duration(milliseconds: call.arguments['bufferedPosition']);
        notifyListeners();
        break;
      case 'onTracksChanged':
        tracks = Map<String, dynamic>.from(call.arguments);
        notifyListeners();
        break;
      case 'onVideoSizeChanged':
        videoSize = Size(
          (call.arguments['width'] as num).toDouble(),
          (call.arguments['height'] as num).toDouble(),
        );
        notifyListeners();
        break;
      case 'onPlayerError':
        error = call.arguments['message'];
        notifyListeners();
        break;
    }
  }

  Future<void> play(String url, {Map<String, String>? headers}) async {
    await _channel.invokeMethod('play', {'url': url, 'headers': headers});
  }

  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  Future<void> resume() async {
    await _channel.invokeMethod('resume');
  }

  Future<void> seekTo(Duration targetPosition) async {
    // Optimistically update position to prevent UI jump back
    _lastSeekTime = DateTime.now();
    position = targetPosition;
    notifyListeners();
    await _channel.invokeMethod('seekTo', {'position': targetPosition.inMilliseconds});
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _channel.invokeMethod('setPlaybackSpeed', {'speed': speed});
  }

  Future<void> setResizeMode(int mode) async {
    await _channel.invokeMethod('setResizeMode', {'mode': mode});
  }

  Future<void> selectTrack(int type, int groupIndex, int trackIndex) async {
    await _channel.invokeMethod('selectTrack', {
      'type': type,
      'groupIndex': groupIndex,
      'trackIndex': trackIndex,
    });
  }

  Future<void> enterPiP() async {
    await _channel.invokeMethod('enterPiP');
  }

  Future<void> setRotation(int rotation) async {
    await _channel.invokeMethod('setRotation', {'rotation': rotation});
  }

  Future<void> toggleOrientation() async {
    await _channel.invokeMethod('toggleOrientation');
  }

  Future<void> setVolume(double volume) async {
    await _channel.invokeMethod('setVolume', {'volume': volume});
  }

  Future<void> setBrightness(double brightness) async {
    await _channel.invokeMethod('setBrightness', {'brightness': brightness});
  }

  Future<double> getVolume() async {
    return await _channel.invokeMethod('getVolume');
  }

  Future<double> getBrightness() async {
    return await _channel.invokeMethod('getBrightness');
  }
}
