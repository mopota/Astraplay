import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import '../../../../features/playlist/domain/entities/playlist.entity.dart';
import '../../../../features/playlist/domain/repositories/playlist_repository.dart';
import '../../../../injection_container.dart';
import '../../../../core/database/app_database.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<AppStream> _favorites = [];
  List<HistoryRecord> _history = [];
  final Map<int, AppStream> _historyStreams = {};
  bool _isLoading = true;
  Playlist? _activePlaylist;
  static DateTime? _lastAutoRefresh;
  StreamSubscription? _streamsSubscription;
  StreamSubscription? _historySubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData(isInitial: true));
    _initWatchers();
  }

  void _initWatchers() {
    final db = sl<AppDatabase>();
    
    // Watch for changes in streams (favorites)
    _streamsSubscription = db.isar.appStreams.watchLazy().listen((_) {
      _loadData(isInitial: false, silent: true);
    });

    // Watch for changes in history
    _historySubscription = db.isar.historyRecords.watchLazy().listen((_) {
      _loadData(isInitial: false, silent: true);
    });
  }

  @override
  void dispose() {
    _streamsSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isInitial = false, bool silent = false}) async {
    if (!mounted) return;
    
    if (!silent) setState(() => _isLoading = true);
    
    final db = sl<AppDatabase>();
    final activePlaylistId = sl<SettingsCubit>().state.settings.activePlaylistId;

    if (activePlaylistId == null) {
      if (mounted) context.go('/playlists');
      return;
    }

    final activePlaylist = await db.isar.playlists.get(activePlaylistId);
    
    // Auto Refresh logic for remote playlists
    if (isInitial && activePlaylist != null) {
      final isRemote = activePlaylist.type == PlaylistType.m3uUrl || 
                       activePlaylist.type == PlaylistType.xtream;
      
      final needsRefresh = activePlaylist.lastRefresh == null || 
          DateTime.now().difference(activePlaylist.lastRefresh!).inHours >= 12;

      final sessionNeedsRefresh = _lastAutoRefresh == null || 
          DateTime.now().difference(_lastAutoRefresh!).inMinutes >= 30;

      if (isRemote && needsRefresh && sessionNeedsRefresh) {
        _lastAutoRefresh = DateTime.now();
        unawaited(_refreshPlaylist(activePlaylist.id));
      }
    }

    // Fetch Favorites ONLY for the active playlist
    final favorites = await db.isar.appStreams
        .filter()
        .playlistIdEqualTo(activePlaylistId)
        .isFavoriteEqualTo(true)
        .limit(20)
        .findAll();

    // Fetch History
    final history = await db.isar.historyRecords
        .where()
        .sortByLastWatchedDesc()
        .findAll();
    
    _historyStreams.clear();
    final List<HistoryRecord> filteredHistory = [];
    for (var h in history) {
      final stream = await db.isar.appStreams.get(h.streamId);
      if (stream != null && stream.playlistId == activePlaylistId) {
        _historyStreams[h.streamId] = stream;
        filteredHistory.add(h);
        if (filteredHistory.length >= 20) break;
      }
    }

    if (mounted) {
      setState(() {
        _activePlaylist = activePlaylist;
        _favorites = favorites;
        _history = filteredHistory;
        if (!silent) _isLoading = false;
      });
    }
  }

  Future<void> _handleManualRefresh() async {
    final activePlaylistId = sl<SettingsCubit>().state.settings.activePlaylistId;
    if (activePlaylistId != null) {
      await _refreshPlaylist(activePlaylistId);
    } else {
      await _loadData();
    }
  }

  Future<void> _refreshPlaylist(int id) async {
    try {
      final repo = sl<PlaylistRepository>();
      await repo.refreshPlaylist(id);
      if (mounted) {
        await _loadData();
      }
    } catch (e) {
      debugPrint('Auto-refresh error: $e');
    }
  }

  Future<void> _navigateToPlayer(Map<String, dynamic> extra) async {
    await context.push('/player', extra: extra);
    if (mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use BlocListener to reload data when playlist changes
    return BlocListener<SettingsCubit, SettingsState>(
      listenWhen: (previous, current) => 
          previous.settings.activePlaylistId != current.settings.activePlaylistId,
      listener: (context, state) {
        _loadData(isInitial: true);
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerLow,
              ],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _handleManualRefresh,
            displacement: 100,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildModernAppBar(context),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: _buildMainDashboard(context),
                  ),
                ),

                if (!_isLoading && _history.isNotEmpty) ...[
                  _buildSliverSectionHeader(context, 'Continue Watching', Icons.play_circle_outline_rounded),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _buildContinueWatchingList(),
                    ),
                  ),
                ],

                if (!_isLoading && _favorites.isNotEmpty) ...[
                  _buildSliverSectionHeader(
                    context, 
                    'Your Favorites', 
                    Icons.favorite_rounded,
                    onSeeAll: () => unawaited(context.push('/favorites')),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _buildFavoritesList(),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SliverAppBar(
      expandedHeight: 120,
      collapsedHeight: 80,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: colorScheme.surface.withAlpha(200),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        centerTitle: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                 'Astra Play',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: colorScheme.primary,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _activePlaylist?.name.toUpperCase() ?? 'ASTRA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () async {
                    await context.read<SettingsCubit>().setActivePlaylist(null);
                    if (context.mounted) context.go('/playlists');
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => unawaited(context.push('/settings')),
                  icon: const Icon(Icons.settings_outlined, size: 20),
                ),
              ],
            ),
          ],
        ),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _buildMainDashboard(BuildContext context) {
    return Column(
      children: [
        _buildSearchShortcut(context),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildDashboardItem(
              context,
              'LIVE TV',
              Icons.live_tv_rounded,
              Colors.orange,
              () => _handleQuickAction(context, StreamType.live),
            ),
            _buildDashboardItem(
              context,
              'MOVIES',
              Icons.movie_filter_rounded,
              Colors.blue,
              () => _handleQuickAction(context, StreamType.movie),
            ),
            _buildDashboardItem(
              context,
              'SERIES',
              Icons.video_library_rounded,
              Colors.purple,
              () => _handleQuickAction(context, StreamType.series),
            ),
            _buildDashboardItem(
              context,
              'FAVORITES',
              Icons.favorite_outline_rounded,
              Colors.red,
              () => unawaited(context.push('/favorites')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardItem(
    BuildContext context, 
    String title, 
    IconData icon, 
    Color color,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withAlpha(50), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1,
                  color: color.withAlpha(220),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildSearchShortcut(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => unawaited(context.push('/search')),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(150),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: colorScheme.primary, size: 24),
            const SizedBox(width: 16),
            Text(
              'Search for content...',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withAlpha(150),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.2, end: 0);
  }

  Widget _buildSliverSectionHeader(BuildContext context, String title, IconData icon, {VoidCallback? onSeeAll}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 10, 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See All'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueWatchingList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final h = _history[index];
          final stream = _historyStreams[h.streamId];
          if (stream == null) return const SizedBox();

          Map<String, dynamic>? episodeInfo;
          if (h.episodeMetadata != null) {
            try {
              episodeInfo = jsonDecode(h.episodeMetadata!);
            } catch (_) {}
          }

          final displayTitle = episodeInfo != null 
              ? '${stream.name} - ${episodeInfo['name']}'
              : stream.name;
          
          final streamUrl = episodeInfo != null 
              ? episodeInfo['url'] 
              : stream.data.streamUrl;

          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => _navigateToPlayer({
                'streamUrl': streamUrl,
                'title': displayTitle,
                'streamId': stream.id,
                'episodeMetadata': h.episodeMetadata,
                'headers': stream.data.headersJson != null 
                    ? Map<String, String>.from(jsonDecode(stream.data.headersJson!)) 
                    : null,
              }),
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: stream.data.logoUrl ?? '',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.play_circle_outline_rounded, size: 48),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(180)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: h.totalDuration > 0 ? (h.lastPosition / h.totalDuration).clamp(0.0, 1.0) : 0,
                            backgroundColor: Colors.white.withAlpha(50),
                            color: Theme.of(context).colorScheme.primary,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.2, end: 0);
        },
      ),
    );
  }

  Widget _buildFavoritesList() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final stream = _favorites[index];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () {
                if (stream.streamType == StreamType.series) {
                  context.push('/series-details', extra: {'stream': stream});
                } else {
                  _navigateToPlayer({
                    'streamUrl': stream.data.streamUrl,
                    'title': stream.name,
                    'streamId': stream.id,
                  });
                }
              },
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: stream.data.logoUrl ?? '',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.favorite_rounded, color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stream.name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (index * 50).ms).scale(begin: const Offset(0.8, 0.8));
        },
      ),
    );
  }

  void _handleQuickAction(BuildContext context, StreamType type) async {
    final activePlaylistId = sl<SettingsCubit>().state.settings.activePlaylistId;
    if (activePlaylistId == null) return;

    final db = sl<AppDatabase>();
    final playlist = await db.isar.playlists.get(activePlaylistId);
    if (playlist == null) return;

    final entity = PlaylistEntity(
      id: playlist.id,
      name: playlist.name,
      type: playlist.type.name,
      url: playlist.info.url ?? playlist.info.serverUrl,
      lastRefresh: playlist.lastRefresh,
      channelCount: playlist.info.channelCount,
      movieCount: playlist.info.movieCount,
      seriesCount: playlist.info.seriesCount,
    );
    
    if (!context.mounted) return;

    unawaited(context.push('/playlists/categories', extra: {
      'playlist': entity,
      'type': type,
    }));
  }
}
