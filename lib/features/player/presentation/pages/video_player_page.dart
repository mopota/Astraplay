import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../../../injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../playlist/domain/repositories/playlist_repository.dart';
import '../widgets/native_video_player.dart';
import '../widgets/video_player_controls.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VideoPlayerPage extends StatefulWidget {
  final String streamUrl;
  final String title;
  final int? streamId;
  final Map<String, String>? headers;
  final String? episodeMetadata;
  final List<Map<String, String>>? playlist;
  final int? initialIndex;
  final int? playlistId;
  final String? categoryName;
  final AppStream? stream;

  const VideoPlayerPage({
    super.key,
    required this.streamUrl,
    required this.title,
    this.streamId,
    this.headers,
    this.episodeMetadata,
    this.playlist,
    this.initialIndex,
    this.playlistId,
    this.categoryName,
    this.stream,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with WidgetsBindingObserver {
  NativePlayerController? _controller;
  
  late String _currentUrl;
  late String _currentTitle;
  String? _currentMetadata;
  int? _currentIndex;
  bool _isPopping = false;
  
  int _retryCount = 0;
  Timer? _retryTimer;
  bool _isReconnecting = false;

  List<AppStream>? _categoryStreams;
  AppStream? _currentAppStream;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.streamUrl;
    _currentTitle = widget.title;
    _currentMetadata = widget.episodeMetadata;
    _currentIndex = widget.initialIndex;

    WidgetsBinding.instance.addObserver(this);
    
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _loadCurrentStream();
    await _addToHistory();
    await _loadCategoryStreams();
  }

  Future<void> _loadCurrentStream() async {
    if (widget.stream != null) {
      setState(() => _currentAppStream = widget.stream);
      await _fetchEpg();
      return;
    }

    if (widget.streamId != null && widget.streamId != 0) {
      final db = sl<AppDatabase>();
      final stream = await db.isar.appStreams.get(widget.streamId!);
      if (mounted) {
        setState(() => _currentAppStream = stream);
        await _fetchEpg();
      }
    }
  }

  Future<void> _fetchEpg() async {
    final streamId = _currentAppStream?.data.xtreamId ?? widget.streamId?.toString();
    final pId = _currentAppStream?.playlistId ?? widget.playlistId;
    
    if (streamId != null && pId != null) {
      await sl<PlaylistRepository>().fetchEpg(pId, streamId);
    }
  }

  Future<void> _loadCategoryStreams() async {
    if (widget.playlistId != null && widget.categoryName != null) {
      final db = sl<AppDatabase>();
      final streams = await db.isar.appStreams
          .filter()
          .playlistIdEqualTo(widget.playlistId!)
          .categoryNameEqualTo(widget.categoryName!)
          .streamTypeEqualTo(StreamType.live)
          .findAll();
      if (mounted) setState(() => _categoryStreams = streams);
    }
  }

  Future<void> _addToHistory() async {
    if (_currentAppStream != null) {
      await sl<AppDatabase>().addToHistory(
        _currentAppStream!, 
        episodeMetadata: _currentMetadata,
      );
    }
  }

  @override
  void dispose() {
    _savePosition();
    _retryTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);

    // Reset orientations to portrait when leaving the player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller == null) return;

    // Detect if stream stopped unexpectedly
    final isError = _controller!.error != null;
    final isIdle = _controller!.playbackState == 'IDLE';
    final isEnded = _controller!.playbackState == 'ENDED';

    if ((isError || isIdle || isEnded) && !_isPopping && !_isReconnecting) {
      // If it's a live stream or we were playing, try to reconnect
      _handleReconnect();
    }

    if (_controller!.isPlaying && _isReconnecting) {
      setState(() {
        _isReconnecting = false;
        _retryCount = 0;
      });
    }
  }

  void _handleReconnect() {
    if (_retryCount >= 5) {
      setState(() => _isReconnecting = false);
      return;
    }

    _retryTimer?.cancel();
    setState(() => _isReconnecting = true);
    
    _retryCount++;
    final delay = Duration(seconds: _retryCount * 2);
    
    _retryTimer = Timer(delay, () async {
      if (!mounted || _isPopping) return;
      debugPrint('Attempting to reconnect stream... ($_retryCount)');
      await _controller?.play(_currentUrl, headers: widget.headers);
    });
  }

  void _savePosition() {
    if (_currentAppStream != null && _controller != null) {
      final pos = _controller!.position.inMilliseconds;
      final dur = _controller!.duration.inMilliseconds;
      if (pos > 5000) {
        unawaited(sl<AppDatabase>().addToHistory(
          _currentAppStream!,
          position: pos, 
          duration: dur,
          episodeMetadata: _currentMetadata,
        ));
      }
    }
  }

  Future<void> _changeEpisode(int newIndex) async {
    if (widget.playlist == null || newIndex < 0 || newIndex >= widget.playlist!.length) return;
    
    _savePosition();
    
    final ep = widget.playlist![newIndex];
    final epUrl = ep['url'] ?? '';
    final epName = ep['name'] ?? '';
    final seriesTitle = widget.title.contains(' - ') 
        ? widget.title.split(' - ').first 
        : widget.title;

    setState(() {
      _currentIndex = newIndex;
      _currentUrl = epUrl;
      _currentTitle = '$seriesTitle - $epName';
      _currentMetadata = jsonEncode({
        'url': epUrl,
        'name': epName,
        'episodeId': ep['id'] ?? '',
        'season': ep['season'] ?? '',
      });
    });

    if (_controller != null) {
      await _controller!.play(_currentUrl, headers: widget.headers);
      await _addToHistory();
      
      final streamId = _currentAppStream?.id ?? widget.streamId;
      if (streamId != null) {
        final lastPos = await sl<AppDatabase>().getLastPosition(
          streamId, 
          episodeMetadata: _currentMetadata,
        );
        if (lastPos > 0) {
          await _controller!.seekTo(Duration(milliseconds: lastPos));
        }
      }
    }
  }

  Future<void> _switchStream(AppStream stream) async {
    _savePosition();
    
    setState(() {
      _currentAppStream = stream;
      _currentUrl = stream.data.streamUrl ?? '';
      _currentTitle = stream.name;
      _currentMetadata = null;
    });

    if (_controller != null) {
      final headers = stream.data.headersJson != null 
          ? Map<String, String>.from(jsonDecode(stream.data.headersJson!)) 
          : widget.headers;
      
      await _controller!.play(_currentUrl, headers: headers);
      
      unawaited(sl<AppDatabase>().addToHistory(stream));
      
      final lastPos = await sl<AppDatabase>().getLastPosition(stream.id);
      if (lastPos > 0) {
        await _controller!.seekTo(Duration(milliseconds: lastPos));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _savePosition();
    }
  }

  void _handleBack() {
    if (_isPopping) return;
    _isPopping = true;
    
    debugPrint('[Navigation] Manual back triggered, saving position and popping.');
    _savePosition();
    
    if (mounted) {
      // Use GoRouter context for a clean pop from the current location
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable system back to handle it manually
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: NativeVideoPlayer(
                  url: _currentUrl,
                  title: _currentTitle,
                  headers: widget.headers,
                  hardwareAcceleration: state.settings.hardwareAcceleration,
                  bufferMs: state.settings.bufferMs,
                  onCreated: (controller) async {
                    setState(() => _controller = controller);
                    controller.addListener(_onControllerChanged);
                    
                    final streamId = _currentAppStream?.id ?? widget.streamId;
                    if (streamId != null) {
                      final lastPos = await sl<AppDatabase>().getLastPosition(
                        streamId, 
                        episodeMetadata: _currentMetadata,
                      );
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
                      
                      final hasPlaylist = widget.playlist != null && widget.playlist!.isNotEmpty;
                      final hasNext = hasPlaylist && _currentIndex != null && _currentIndex! < widget.playlist!.length - 1;
                      final hasPrev = hasPlaylist && _currentIndex != null && _currentIndex! > 0;
    
                      return VideoPlayerControls(
                        controller: _controller!,
                        title: _currentTitle,
                        streamUrl: _currentUrl,
                        onBack: _handleBack,
                        onNext: hasNext ? () => _changeEpisode(_currentIndex! + 1) : null,
                        onPrevious: hasPrev ? () => _changeEpisode(_currentIndex! - 1) : null,
                        categoryStreams: _categoryStreams,
                        currentStream: _currentAppStream,
                        onStreamSelected: _switchStream,
                        playlist: widget.playlist,
                        initialIndex: _currentIndex,
                        onEpisodeSelected: _changeEpisode,
                      );
                    },
                  ),
                ),
              if (_controller == null || _controller!.playbackState == 'IDLE' && !_isReconnecting)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.red),
                      const SizedBox(height: 24),
                      Text(
                        context.tr('loading_stream'),
                        style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              if (_isReconnecting)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${context.tr('reconnecting')}... ($_retryCount/5)',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
     ),
    );
  }
}
