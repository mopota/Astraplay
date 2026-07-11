import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class NativeVideoPlayer extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? headers;
  final void Function(NativePlayerController controller)? onCreated;
  final bool hardwareAcceleration;
  final int bufferMs;

  const NativeVideoPlayer({
    super.key,
    required this.url,
    required this.title,
    this.headers,
    this.onCreated,
    this.hardwareAcceleration = true,
    this.bufferMs = 5000,
  });

  @override
  State<NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends State<NativeVideoPlayer> {
  NativePlayerController? _controller;
  WebViewController? _webController;
  bool _isWebMode = false;

  @override
  void initState() {
    super.initState();
    _isWebMode = _checkIsWeb(widget.url);
    if (_isWebMode) {
      _initWebController();
    }
  }

  bool _checkIsWeb(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.html') || 
           lowerUrl.contains('.php') || 
           lowerUrl.contains('youtube.com') || 
           lowerUrl.contains('youtu.be');
  }

  void _initWebController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
             _controller?._onWebReady();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    if (_webController!.platform is AndroidWebViewController) {
      (_webController!.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  void didUpdateWidget(NativeVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url && _controller != null) {
      _controller!.play(widget.url, headers: widget.headers);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isWebMode) {
      return Stack(
        children: [
          WebViewWidget(controller: _webController!),
          // Overlay an invisible layer to capture gestures if needed, 
          // but we'll let the existing VideoPlayerControls handle the UI.
          _buildInternalCreatedNotifier(),
        ],
      );
    }

    const String viewType = 'astraplay/native_player';
    final Map<String, dynamic> creationParams = {
      'url': widget.url,
      'title': widget.title,
      'headers': widget.headers,
      'hardwareAcceleration': widget.hardwareAcceleration,
      'bufferMs': widget.bufferMs,
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

  Widget _buildInternalCreatedNotifier() {
    return FutureBuilder(
      future: Future.microtask(() {}),
      builder: (context, snapshot) {
        if (_controller == null) {
          _controller = NativePlayerController(-1, webController: _webController);
          if (widget.onCreated != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onCreated!(_controller!);
            });
          }
        }
        return const SizedBox.shrink();
      },
    );
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
  final WebViewController? webController;
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
  bool isCasting = false;
  bool isCastAvailable = false;

  DateTime? _lastSeekTime;
  Timer? _webProgressTimer;

  NativePlayerController(this.id, {this.webController}) {
    if (id != -1) {
      _channel = MethodChannel('astraplay/native_player_$id');
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  void _onWebReady() {
    isPlaying = true;
    playbackState = 'READY';
    _startWebPolling();
    notifyListeners();
  }

  void _startWebPolling() {
    _webProgressTimer?.cancel();
    _webProgressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (webController == null) return;
      try {
        final current = await webController!.runJavaScriptReturningResult(
          "document.querySelector('video').currentTime"
        );
        final total = await webController!.runJavaScriptReturningResult(
          "document.querySelector('video').duration"
        );
        
        position = Duration(milliseconds: ((double.tryParse(current.toString()) ?? 0) * 1000).toInt());
        duration = Duration(milliseconds: ((double.tryParse(total.toString()) ?? 0) * 1000).toInt());
        notifyListeners();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _webProgressTimer?.cancel();
    if (id != -1) {
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPiPModeChanged':
        isInPiP = call.arguments['isInPiP'];
        notifyListeners();
        break;
      case 'onCastStateChanged':
        isCasting = call.arguments['isCasting'];
        notifyListeners();
        break;
      case 'onCastAvailabilityChanged':
        isCastAvailable = call.arguments['available'];
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
    if (webController != null) {
      await webController!.loadRequest(Uri.parse(url));
    } else {
      await _channel.invokeMethod('play', {'url': url, 'headers': headers});
    }
  }

  Future<void> pause() async {
    if (webController != null) {
      await webController!.runJavaScript("document.querySelector('video').pause()");
      isPlaying = false;
      notifyListeners();
    } else {
      await _channel.invokeMethod('pause');
    }
  }

  Future<void> resume() async {
    if (webController != null) {
      await webController!.runJavaScript("document.querySelector('video').play()");
      isPlaying = true;
      notifyListeners();
    } else {
      await _channel.invokeMethod('resume');
    }
  }

  Future<void> seekTo(Duration targetPosition) async {
    _lastSeekTime = DateTime.now();
    position = targetPosition;
    notifyListeners();
    
    if (webController != null) {
      final seconds = targetPosition.inMilliseconds / 1000;
      await webController!.runJavaScript("document.querySelector('video').currentTime = $seconds");
    } else {
      await _channel.invokeMethod('seekTo', {'position': targetPosition.inMilliseconds});
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (webController != null) {
      await webController!.runJavaScript("document.querySelector('video').playbackRate = $speed");
    } else {
      await _channel.invokeMethod('setPlaybackSpeed', {'speed': speed});
    }
  }

  Future<void> setResizeMode(int mode) async {
    if (webController == null) {
      await _channel.invokeMethod('setResizeMode', {'mode': mode});
    }
  }

  Future<void> selectTrack(int type, int groupIndex, int trackIndex) async {
    if (webController == null) {
      await _channel.invokeMethod('selectTrack', {
        'type': type,
        'groupIndex': groupIndex,
        'trackIndex': trackIndex,
      });
    }
  }

  Future<void> enterPiP() async {
    if (webController == null) {
      await _channel.invokeMethod('enterPiP');
    }
  }

  Future<void> setRotation(int rotation) async {
    if (webController == null) {
      await _channel.invokeMethod('setRotation', {'rotation': rotation});
    }
  }

  Future<void> toggleOrientation() async {
    if (webController == null) {
      await _channel.invokeMethod('toggleOrientation');
    }
  }

  Future<void> setVolume(double volume) async {
    if (webController != null) {
      await webController!.runJavaScript("document.querySelector('video').volume = $volume");
    } else {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    }
  }

  Future<void> setSubtitleSource(String? path) async {
    if (webController == null) {
      await _channel.invokeMethod('setSubtitleSource', {'path': path});
    }
  }

  Future<void> setSubtitleOffset(int offsetMs) async {
    if (webController == null) {
      await _channel.invokeMethod('setSubtitleOffset', {'offset': offsetMs});
    }
  }

  Future<void> setSubtitleStyle({
    double? fontSize,
    String? color,
    String? backgroundColor,
  }) async {
    if (webController == null) {
      await _channel.invokeMethod('setSubtitleStyle', {
        'fontSize': fontSize,
        'color': color,
        'backgroundColor': backgroundColor,
      });
    }
  }

  Future<void> setBrightness(double brightness) async {
    if (id != -1) {
      await _channel.invokeMethod('setBrightness', {'brightness': brightness});
    }
  }

  Future<void> openExternalPlayer({String? url}) async {
    if (id != -1) {
      await _channel.invokeMethod('openExternal', {'url': url});
    }
  }

  Future<void> showCastDialog() async {
    if (id != -1) {
      await _channel.invokeMethod('showCastDialog');
    }
  }

  Future<double> getVolume() async {
    if (id != -1) {
      return await _channel.invokeMethod('getVolume');
    }
    return 0.5;
  }

  Future<double> getBrightness() async {
    if (id != -1) {
      return await _channel.invokeMethod('getBrightness');
    }
    return 0.5;
  }
}
