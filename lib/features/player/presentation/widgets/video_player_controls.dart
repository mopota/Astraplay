import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../injection_container.dart';
import '../../../subtitles/presentation/cubit/subtitle_cubit.dart';
import '../../../subtitles/presentation/widgets/subtitle_downloader_sheet.dart';
import '../../../subtitles/presentation/widgets/subtitle_settings_sheet.dart';
import 'native_video_player.dart';
import 'channel_side_menu.dart';

class VideoPlayerControls extends StatefulWidget {
  final NativePlayerController controller;
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final List<AppStream>? categoryStreams;
  final AppStream? currentStream;
  final Function(AppStream)? onStreamSelected;

  const VideoPlayerControls({
    super.key,
    required this.controller,
    required this.title,
    required this.onBack,
    this.onNext,
    this.onPrevious,
    this.categoryStreams,
    this.currentStream,
    this.onStreamSelected,
  });

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
  bool _isVisible = true;
  Timer? _hideTimer;
  bool _isLocked = false;
  bool _isSideMenuOpen = false;
  
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _isDragging = false;
  String? _gestureType;
  double _gestureValue = 0;
  
  // For horizontal drag seeking
  double? _dragStartX;
  Duration? _dragStartPosition;
  Duration? _seekingPosition;

  EpgProgram? _currentProgram;
  Timer? _epgTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _loadInitialValues();
    _startEpgTimer();
  }

  Future<void> _loadInitialValues() async {
    _brightness = await widget.controller.getBrightness();
    _volume = await widget.controller.getVolume();
    if (mounted) setState(() {});
  }

  void _startEpgTimer() {
    _updateEpg();
    _epgTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateEpg());
  }

  Future<void> _updateEpg() async {
    if (widget.currentStream != null) {
      final db = sl<AppDatabase>();
      final streamId = widget.currentStream!.data.xtreamId ?? widget.currentStream!.id.toString();
      final program = await db.getCurrentProgram(widget.currentStream!.playlistId, streamId);
      if (mounted) setState(() => _currentProgram = program);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isVisible) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.controller.isPlaying && !_isDragging && !_isLocked && !_isSideMenuOpen) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_isSideMenuOpen) {
      setState(() => _isSideMenuOpen = false);
      _startHideTimer();
      return;
    }

    if (_isLocked && !_isVisible) {
       setState(() => _isVisible = true);
       _startHideTimer();
       return;
    }
    setState(() {
      _isVisible = !_isVisible;
      if (_isVisible) _startHideTimer();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _epgTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        if (widget.controller.isInPiP) return const SizedBox.shrink();

        return Stack(
          children: [
            GestureDetector(
              onTap: _toggleControls,
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _isLocked ? null : (details) {
                final double delta = details.primaryDelta! / MediaQuery.of(context).size.height;
                final double width = MediaQuery.of(context).size.width;
                
                setState(() {
                  _isDragging = true;
                  if (details.globalPosition.dx < width / 2) {
                    _gestureType = 'Brightness';
                    _brightness = (_brightness - delta).clamp(0.0, 1.0);
                    widget.controller.setBrightness(_brightness);
                    _gestureValue = _brightness;
                  } else {
                    _gestureType = 'Volume';
                    _volume = (_volume - delta).clamp(0.0, 1.0);
                    widget.controller.setVolume(_volume);
                    _gestureValue = _volume;
                  }
                });
              },
              onVerticalDragEnd: (_) {
                setState(() {
                  _gestureType = null;
                  _isDragging = false;
                });
                _startHideTimer();
              },
              onHorizontalDragStart: _isLocked ? null : (details) {
                setState(() {
                  _isDragging = true;
                  _dragStartX = details.globalPosition.dx;
                  _dragStartPosition = widget.controller.position;
                  _seekingPosition = widget.controller.position;
                  _gestureType = 'Seek';
                });
              },
              onHorizontalDragUpdate: _isLocked ? null : (details) {
                if (_dragStartX == null || _dragStartPosition == null) return;
                
                final double width = MediaQuery.of(context).size.width;
                final double deltaX = details.globalPosition.dx - _dragStartX!;
                final double relativeDelta = deltaX / width;
                final int seekDeltaMs = (relativeDelta * 120000).toInt(); 
                
                setState(() {
                  final newMs = (_dragStartPosition!.inMilliseconds + seekDeltaMs)
                      .clamp(0, widget.controller.duration.inMilliseconds);
                  _seekingPosition = Duration(milliseconds: newMs);
                  _gestureValue = newMs / (widget.controller.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity));
                });
              },
              onHorizontalDragEnd: _isLocked ? null : (_) {
                if (_seekingPosition != null) {
                  widget.controller.seekTo(_seekingPosition!);
                }
                setState(() {
                  _gestureType = null;
                  _isDragging = false;
                  _seekingPosition = null;
                  _dragStartX = null;
                });
                _startHideTimer();
              },
              onDoubleTapDown: (details) {
                 if (_isLocked) return;
                 final double width = MediaQuery.of(context).size.width;
                 if (details.globalPosition.dx < width / 2) {
                   widget.controller.seekTo(widget.controller.position - const Duration(seconds: 10));
                   HapticsHelper.light();
                 } else {
                   widget.controller.seekTo(widget.controller.position + const Duration(seconds: 10));
                   HapticsHelper.light();
                 }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_gestureType != null)
                    _buildGestureIndicator(),
                  IgnorePointer(
                    ignoring: !_isVisible,
                    child: AnimatedOpacity(
                      opacity: _isVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      child: _buildControlsBackground(
                        child: _isLocked ? _buildLockedUI() : _buildFullUI(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSideMenuOpen && widget.categoryStreams != null && widget.currentStream != null)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: ChannelSideMenu(
                  streams: widget.categoryStreams!,
                  currentStream: widget.currentStream!,
                  onStreamSelected: (s) {
                    widget.onStreamSelected?.call(s);
                    setState(() => _isSideMenuOpen = false);
                  },
                  onClose: () => setState(() => _isSideMenuOpen = false),
                ).animate().slideX(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
              ),
          ],
        );
      },
    );
  }

  Widget _buildControlsBackground({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(150),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withAlpha(150),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _isVisible ? 1.5 : 0, sigmaY: _isVisible ? 1.5 : 0),
        child: child,
      ),
    );
  }

  Widget _buildGestureIndicator() {
    IconData icon;
    String text = '';
    
    if (_gestureType == 'Brightness') {
      icon = Icons.light_mode_rounded;
      text = '${(_gestureValue * 100).toInt()}%';
    } else if (_gestureType == 'Volume') {
      icon = Icons.volume_up_rounded;
      text = '${(_gestureValue * 100).toInt()}%';
    } else {
      icon = Icons.history_rounded;
      text = _formatDuration(_seekingPosition ?? Duration.zero);
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 44),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_gestureType != 'Seek') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _gestureValue,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _buildLockedUI() {
    return Stack(
      children: [
        Positioned(
          left: 48,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton.filled(
              onPressed: () {
                HapticsHelper.heavy();
                setState(() => _isLocked = false);
                _startHideTimer();
              },
              icon: const Icon(Icons.lock_rounded, size: 32),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.all(20),
              ),
            ),
          ).animate().scale().fadeIn(),
        ),
      ],
    );
  }

  Widget _buildFullUI() {
    return SafeArea(
      child: Stack(
        children: [
          _buildTopBar(),
          Center(child: _buildCenterControls()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black26,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                _buildEpgInfo(),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cast_rounded, color: Colors.white),
            onPressed: () {
              HapticsHelper.light();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Casting feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
            onPressed: () => widget.controller.enterPiP(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildEpgInfo() {
    if (_currentProgram == null) {
      return Text(
        context.tr('epg_no_program'),
        style: const TextStyle(color: Colors.white54, fontSize: 10),
      );
    }

    return Text(
      'Now: ${_currentProgram!.title}',
      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCenterControls() {
    final isPlaying = widget.controller.isPlaying;
    final isBuffering = widget.controller.playbackState == 'BUFFERING';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.onPrevious != null) ...[
          _buildEpisodeButton(
            icon: Icons.skip_previous_rounded,
            label: context.tr('prev_episode'),
            onTap: widget.onPrevious!,
          ),
          const SizedBox(width: 24),
        ],
        _buildSkipButton(Icons.replay_10_rounded, () {
          widget.controller.seekTo(widget.controller.position - const Duration(seconds: 10));
        }),
        const SizedBox(width: 32),
        if (isBuffering)
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: Theme.of(context).colorScheme.primary,
            ),
          ).animate().scale().fadeIn()
        else
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withAlpha(80),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
            ),
            child: IconButton.filled(
              onPressed: () {
                HapticsHelper.medium();
                if (isPlaying) {
                  widget.controller.pause();
                } else {
                  widget.controller.resume();
                }
                _startHideTimer();
              },
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ).animate(key: ValueKey(isPlaying)).scale(
            duration: 200.ms,
            curve: Curves.easeOutBack,
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.0, 1.0),
          ),
        const SizedBox(width: 32),
        _buildSkipButton(Icons.forward_10_rounded, () {
          widget.controller.seekTo(widget.controller.position + const Duration(seconds: 10));
        }),
        if (widget.onNext != null) ...[
          const SizedBox(width: 24),
          _buildEpisodeButton(
            icon: Icons.skip_next_rounded,
            label: context.tr('next_episode'),
            onTap: widget.onNext!,
          ),
        ],
      ],
    );
  }

  Widget _buildEpisodeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            HapticsHelper.medium();
            onTap();
          },
          icon: Icon(icon, size: 32, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white10,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
      ],
    );
  }

  Widget _buildSkipButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: () {
        HapticsHelper.light();
        onTap();
      },
      icon: Icon(icon, size: 38, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white10,
      ),
    );
  }

  Widget _buildBottomPanel() {
    final displayPosition = _isDragging && _seekingPosition != null 
        ? _seekingPosition! 
        : widget.controller.position;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressBar(),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatDuration(displayPosition),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
              ),
              const Spacer(),
              Text(
                _formatDuration(widget.controller.duration),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (widget.categoryStreams != null)
                  _buildBottomAction(Icons.list_rounded, 'Channels', () {
                    HapticsHelper.light();
                    setState(() {
                      _isSideMenuOpen = true;
                      _isVisible = false;
                    });
                  }),
                _buildBottomAction(Icons.audiotrack_rounded, 'Audio', () => _showTrackSheet('Audio')),
                _buildBottomAction(Icons.subtitles_rounded, 'Subs', _showSubtitleMenu),
                _buildBottomAction(Icons.speed_rounded, 'Speed', _showSpeedSheet),
                _buildBottomAction(Icons.aspect_ratio_rounded, 'Resize', _toggleAspectRatio),
                _buildBottomAction(Icons.screen_rotation_rounded, 'Rotate', () {
                  HapticsHelper.light();
                  setState(() => widget.controller.toggleOrientation());
                }),
                _buildBottomAction(Icons.lock_outline_rounded, 'Lock', () {
                  HapticsHelper.heavy();
                  setState(() {
                     _isLocked = true;
                     _isVisible = true;
                  });
                  _startHideTimer();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final double max = widget.controller.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final double currentPos = widget.controller.position.inMilliseconds.toDouble().clamp(0.0, max);
    final double buffered = widget.controller.bufferedPosition.inMilliseconds.toDouble().clamp(0.0, max);
    
    final double value = _isDragging && _seekingPosition != null 
        ? _seekingPosition!.inMilliseconds.toDouble().clamp(0.0, max)
        : currentPos;

    return Container(
      height: 40,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (buffered / max).clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, pressedElevation: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Theme.of(context).colorScheme.primary.withAlpha(50),
              trackShape: const RoundedRectSliderTrackShape(), 
            ),
            child: Slider(
              value: value,
              max: max,
              onChanged: (val) {
                setState(() {
                  _isDragging = true;
                  _seekingPosition = Duration(milliseconds: val.toInt());
                });
              },
            onChangeEnd: (val) {
              final target = Duration(milliseconds: val.toInt());
              widget.controller.seekTo(target);
              
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _isDragging = false;
                    _seekingPosition = null;
                  });
                }
              });
              _startHideTimer();
            },
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    _showM3Sheet(
      title: 'Playback Settings',
      children: [
        _buildSheetItem(Icons.high_quality_rounded, 'Video Quality', 'Auto', () => _showTrackSheet('Video')),
        _buildSheetItem(Icons.rotate_90_degrees_cw_rounded, 'Rotate View', '90°', _toggleRotation),
      ],
    );
  }

  void _showSpeedSheet() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    _showM3Sheet(
      title: 'Playback Speed',
      children: speeds.map((s) => ListTile(
        title: Text('${s}x', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          HapticsHelper.light();
          widget.controller.setPlaybackSpeed(s);
          Navigator.pop(context);
        },
      )).toList(),
    );
  }

  void _showSubtitleMenu() {
    _showM3Sheet(
      title: 'Subtitles',
      children: [
        _buildSheetItem(Icons.download_rounded, 'Download Subtitles', 'Online', _showSubtitleDownloader),
        _buildSheetItem(Icons.settings_suggest_rounded, 'Subtitle Settings', 'Sync & Style', _showSubtitleSettings),
        const Divider(indent: 16, endIndent: 16, color: Colors.white10),
        ListTile(
          leading: const Icon(Icons.list_rounded),
          title: const Text('Embedded Subtitles'),
          onTap: () {
            Navigator.pop(context);
            _showTrackSheet('Subtitles');
          },
        ),
      ],
    );
  }

  void _showSubtitleDownloader() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BlocProvider(
        create: (context) => sl<SubtitleCubit>(),
        child: SubtitleDownloaderSheet(
          initialQuery: widget.title,
          onSubtitleSelected: (path) {
            widget.controller.setSubtitleSource(path);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Subtitle applied successfully')),
            );
          },
        ),
      ),
    );
  }

  void _showSubtitleSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SubtitleSettingsSheet(controller: widget.controller),
    );
  }

  void _showTrackSheet(String type) {
    final List tracksList = type == 'Audio' 
        ? widget.controller.tracks['audio'] 
        : (type == 'Video' ? widget.controller.tracks['video'] : widget.controller.tracks['subtitles']);
    final int trackType = type == 'Audio' ? 1 : (type == 'Video' ? 2 : 3);

    _showM3Sheet(
      title: 'Select $type',
      children: [
        ListTile(
          title: const Text('Auto / Default'),
          onTap: () {
            HapticsHelper.light();
            widget.controller.selectTrack(trackType, -1, -1);
            Navigator.pop(context);
          },
        ),
        ...tracksList.map((track) {
          final isSelected = track['isSelected'] == true;
          return ListTile(
            title: Text(track['label']?.isEmpty ? (track['language'] ?? 'Unknown Track') : track['label']),
            trailing: isSelected ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () {
              HapticsHelper.light();
              widget.controller.selectTrack(trackType, track['groupIndex'], track['trackIndex']);
              Navigator.pop(context);
            },
          );
        }),
      ],
    );
  }

  void _showM3Sheet({required String title, required List<Widget> children}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: Column(children: children))),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetItem(IconData icon, String title, String value, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () {
        HapticsHelper.light();
        Navigator.pop(context);
        onTap();
      },
    );
  }

  int _aspectRatioMode = 0;
  void _toggleAspectRatio() {
    HapticsHelper.light();
    setState(() => _aspectRatioMode = (_aspectRatioMode + 1) % 5);
    widget.controller.setResizeMode(_aspectRatioMode);
    final modes = ['Fit', 'Fill', 'Zoom', 'Fixed Height', 'Fixed Width'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aspect Ratio: ${modes[_aspectRatioMode]}'),
        behavior: SnackBarBehavior.floating,
        width: 200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  int _rotation = 0;
  void _toggleRotation() {
    _rotation = (_rotation + 90) % 360;
    widget.controller.setRotation(_rotation);
  }
}
