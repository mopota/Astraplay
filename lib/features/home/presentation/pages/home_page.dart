import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
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
    _streamsSubscription = db.isar.appStreams.watchLazy().listen((_) {
      _loadData(isInitial: false, silent: true);
    });
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
    
    // 1. Fetch Favorites and History Records in parallel
    // We fetch history without playlist filter to avoid the missing method error
    final results = await Future.wait([
      db.isar.appStreams.filter()
          .playlistIdEqualTo(activePlaylistId)
          .isFavoriteEqualTo(true)
          .limit(20)
          .findAll(),
      db.isar.historyRecords
          .where()
          .sortByLastWatchedDesc()
          .limit(100) // Fetch more to find enough for this playlist
          .findAll(),
    ]);

    final favorites = results[0] as List<AppStream>;
    final historyRecords = results[1] as List<HistoryRecord>;
    
    // 2. Batch fetch streams and filter by playlistId in memory
    _historyStreams.clear();
    final List<HistoryRecord> filteredHistory = [];
    
    if (historyRecords.isNotEmpty) {
      final streamIds = historyRecords.map((h) => h.streamId).toList();
      final streams = await db.isar.appStreams.getAll(streamIds);
      
      for (var i = 0; i < historyRecords.length; i++) {
        final h = historyRecords[i];
        final s = streams[i];
        
        // Check if stream exists and belongs to active playlist
        if (s != null && s.playlistId == activePlaylistId) {
          _historyStreams[h.streamId] = s;
          filteredHistory.add(h);
          if (filteredHistory.length >= 20) break; // Limit to 20 items
        }
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

  Future<void> _navigateToPlayer(Map<String, dynamic> extra) async {
    await context.push('/player', extra: extra);
    if (mounted) await _loadData(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocListener<SettingsCubit, SettingsState>(
      listenWhen: (prev, curr) => prev.settings.activePlaylistId != curr.settings.activePlaylistId,
      listener: (context, state) => _loadData(isInitial: true),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () => _loadData(silent: false),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(context),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: _buildMainDashboard(context),
                  ),
                ),

                if (!_isLoading && _history.isNotEmpty) ...[
                  _buildSectionHeader('Continue Watching', Icons.history_rounded),
                  SliverToBoxAdapter(child: _buildHistoryList()),
                ],

                if (!_isLoading && _favorites.isNotEmpty) ...[
                  _buildSectionHeader('Your Favorites', Icons.favorite_rounded, 
                    onSeeAll: () => context.push('/favorites')),
                  SliverToBoxAdapter(child: _buildFavoritesList()),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
      pinned: true,
      elevation: 0,
      backgroundColor: colorScheme.surface.withAlpha(200),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Astra Play', style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.primary)),
                if (_activePlaylist != null)
                  Text(_activePlaylist!.name.toUpperCase(), style: TextStyle(fontSize: 10, color: colorScheme.outline)),
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
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined, size: 20),
                ),
              ],
            ),
          ],
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
            _buildDashboardItem('LIVE TV', Icons.live_tv_rounded, Colors.orange, () => _handleQuickAction(context, StreamType.live)),
            _buildDashboardItem('MOVIES', Icons.movie_filter_rounded, Colors.blue, () => _handleQuickAction(context, StreamType.movie)),
            _buildDashboardItem('SERIES', Icons.video_library_rounded, Colors.purple, () => _handleQuickAction(context, StreamType.series)),
            _buildDashboardItem('FAVORITES', Icons.favorite_rounded, Colors.red, () => context.push('/favorites')),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchShortcut(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/search'),
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
            Text('Search for content...', style: TextStyle(color: colorScheme.outline, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {VoidCallback? onSeeAll}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 10, 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (onSeeAll != null)
              TextButton(onPressed: onSeeAll, child: const Text('See All')),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final h = _history[index];
          final stream = _historyStreams[h.streamId];
          if (stream == null) return const SizedBox();
          
          Map<String, dynamic>? epInfo;
          if (h.episodeMetadata != null) {
            try {
              epInfo = jsonDecode(h.episodeMetadata!);
            } catch (_) {}
          }
          final title = epInfo != null ? '${stream.name} - ${epInfo['name']}' : stream.name;

          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => _navigateToPlayer({
                'streamUrl': epInfo != null ? epInfo['url'] : stream.data.streamUrl,
                'title': title,
                'streamId': stream.id,
                'episodeMetadata': h.episodeMetadata,
                'headers': stream.data.headersJson != null ? Map<String, String>.from(jsonDecode(stream.data.headersJson!)) : null,
              }),
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: CachedNetworkImage(
                      imageUrl: stream.data.logoUrl ?? '',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: Colors.black12, child: const Icon(Icons.play_circle_outline, size: 48)),
                    ),
                  ),
                  Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: h.totalDuration > 0 ? h.lastPosition / h.totalDuration : 0,
                          backgroundColor: Colors.white24,
                          color: Theme.of(context).colorScheme.primary,
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesList() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final stream = _favorites[index];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () {
                if (stream.streamType == StreamType.series) {
                  context.push('/series-details', extra: {'stream': stream});
                } else if (stream.streamType == StreamType.movie) {
                  context.push('/movie-details', extra: {'stream': stream});
                } else {
                  _navigateToPlayer({
                    'streamUrl': stream.data.streamUrl, 
                    'title': stream.name, 
                    'streamId': stream.id,
                    'headers': stream.data.headersJson != null ? Map<String, String>.from(jsonDecode(stream.data.headersJson!)) : null,
                  });
                }
              },
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CachedNetworkImage(imageUrl: stream.data.logoUrl ?? '', fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.favorite, color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(stream.name, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
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
      id: playlist.id, name: playlist.name, type: playlist.type.name,
      url: playlist.info.url ?? playlist.info.serverUrl,
      lastRefresh: playlist.lastRefresh,
      channelCount: playlist.info.channelCount,
      movieCount: playlist.info.movieCount,
      seriesCount: playlist.info.seriesCount,
    );
    
    if (context.mounted) {
      context.push('/playlists/categories', extra: {'playlist': entity, 'type': type});
    }
  }
}
