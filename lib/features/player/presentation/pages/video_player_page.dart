import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../injection_container.dart';
import '../widgets/native_video_player.dart';
import '../widgets/video_player_controls.dart';

class VideoPlayerPage extends StatefulWidget {
  final String streamUrl;
  final String title;
  final int? streamId;
  final Map<String, String>? headers;
  final String? episodeMetadata;

  const VideoPlayerPage({
    super.key,
    required this.streamUrl,
    required this.title,
    this.streamId,
    this.headers,
    this.episodeMetadata,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with WidgetsBindingObserver {
  NativePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.streamId != null) {
      unawaited(sl<AppDatabase>().addToHistory(
        widget.streamId!, 
        episodeMetadata: widget.episodeMetadata,
      ));
    }
  }

  @override
  void dispose() {
    _savePosition();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _savePosition() {
    if (widget.streamId != null && _controller != null) {
      final pos = _controller!.position.inMilliseconds;
      final dur = _controller!.duration.inMilliseconds;
      // Only save if we have some progress and it's not at the very end (e.g. within last 5 seconds)
      if (pos > 5000) {
        unawaited(sl<AppDatabase>().addToHistory(
          widget.streamId!, 
          position: pos, 
          duration: dur,
          episodeMetadata: widget.episodeMetadata,
        ));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _savePosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        // عندما يضغط المستخدم على زر الرجوع في الهاتف
        _savePosition();
        if (context.mounted) {
          context.pop(); // نطلب الرجوع مرة واحدة فقط
        }
        return true; // نخبر النظام أننا قمنا بالمعالجة ولا نريد منه فعل شيء آخر
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: NativeVideoPlayer(
                url: widget.streamUrl,
                title: widget.title,
                headers: widget.headers,
                onCreated: (controller) async {
                  setState(() => _controller = controller);
                  
                  // Resume position if available
                  if (widget.streamId != null) {
                    final lastPos = await sl<AppDatabase>().getLastPosition(widget.streamId!);
                    if (lastPos > 0) {
                      await controller.seekTo(Duration(milliseconds: lastPos));
                    }
                  }
                },
              ),
            ),
            if (_controller != null)
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _controller!,
                  builder: (context, _) {
                    if (_controller!.isInPiP) return const SizedBox.shrink();
                    return VideoPlayerControls(
                      controller: _controller!,
                      title: widget.title,
                      onBack: () => context.pop(),
                    );
                  },
                ),
              ),
            if (_controller == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
