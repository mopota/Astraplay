import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../injection_container.dart';
import '../../../../core/database/app_database.dart';
import '../../../../features/category/domain/repositories/stream_repository.dart';
import 'package:isar_community/isar.dart';

import '../../../settings/presentation/cubit/settings_cubit.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<AppStream> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final db = sl<AppDatabase>();
    final activePlaylistId = sl<SettingsCubit>().state.settings.activePlaylistId;
    
    if (activePlaylistId == null) {
      if (mounted) {
        setState(() {
          _favorites = [];
          _isLoading = false;
        });
      }
      return;
    }

    final favorites = await db.isar.appStreams
        .filter()
        .playlistIdEqualTo(activePlaylistId)
        .isFavoriteEqualTo(true)
        .findAll();
    
    if (mounted) {
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Library',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton.filledTonal(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadFavorites,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesGrid(),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: 80,
              color: colorScheme.primary.withAlpha(50),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your collection is empty',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Long press any movie, series or channel to add it to your favorites',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.outline, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
            label: const Text('DISCOVER CONTENT'),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final stream = _favorites[index];
        return _FavoriteCard(
          stream: stream,
          onRefresh: _loadFavorites,
        );
      },
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final AppStream stream;
  final VoidCallback onRefresh;

  const _FavoriteCard({required this.stream, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLive = stream.streamType == StreamType.live;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (stream.streamType == StreamType.series) {
            context.push('/series-details', extra: {'stream': stream});
          } else {
            context.push('/player', extra: {
              'streamUrl': stream.data.streamUrl,
              'title': stream.name,
              'streamId': stream.id,
              'headers': stream.data.headersJson != null
                  ? Map<String, String>.from(jsonDecode(stream.data.headersJson!))
                  : null,
            });
          }
        },
        onLongPress: () async {
          final confirmed = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  const Text('Manage Favorite', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Do you want to remove this item from your list?', style: TextStyle(color: colorScheme.outline)),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          if (confirmed == true) {
            await sl<StreamRepository>().toggleFavorite(stream.id);
            onRefresh();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (stream.data.logoUrl != null && stream.data.logoUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: stream.data.logoUrl!,
                fit: isLive ? BoxFit.contain : BoxFit.cover,
                placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHighest),
                errorWidget: (context, url, error) => const Center(child: Icon(Icons.movie_rounded)),
              )
            else
              Container(
                color: colorScheme.surfaceContainerHighest,
                child: Opacity(
                  opacity: 0.5,
                  child: Icon(isLive ? Icons.live_tv_rounded : Icons.movie_outlined, color: colorScheme.primary.withAlpha(50)),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(220),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
