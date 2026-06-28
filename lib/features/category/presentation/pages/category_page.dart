import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../injection_container.dart';
import '../../../../core/database/app_database.dart';
import '../../../playlist/domain/entities/playlist.entity.dart';
import '../../domain/repositories/category_repository.dart';

class CategoryPage extends StatelessWidget {
  final PlaylistEntity playlist;
  final StreamType type;

  const CategoryPage({
    super.key, 
    required this.playlist, 
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    String title = 'Categories';
    switch (type) {
      case StreamType.live: title = 'Live TV'; break;
      case StreamType.movie: title = 'Movies'; break;
      case StreamType.series: title = 'Series'; break;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playlist.name.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            floating: true,
            pinned: true,
            actions: [
              IconButton.filledTonal(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => context.push('/search'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverFillRemaining(
            child: _CategoryList(playlistId: playlist.id, type: type),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final int playlistId;
  final StreamType type;

  const _CategoryList({required this.playlistId, required this.type});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sl<CategoryRepository>().getCategories(playlistId, type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final result = snapshot.data;
        if (result == null) return const SizedBox();

        return result.fold(
          (failure) => Center(child: Text(failure.message)),
          (categories) {
            if (categories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.category_outlined, size: 80, color: Theme.of(context).colorScheme.outline.withAlpha(100)),
                    const SizedBox(height: 16),
                    Text(
                      'No categories found',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryCard(context, category, index);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(BuildContext context, dynamic category, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(80),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToStreams(context, category.name),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainerHigh,
                colorScheme.surfaceContainerLow,
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconForType(type),
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.count} items',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withAlpha(150),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 40).ms).scale(begin: const Offset(0.9, 0.9));
  }

  void _navigateToStreams(BuildContext context, String categoryName) {
    context.push('/playlists/categories/streams', extra: {
      'playlistId': playlistId,
      'category': categoryName,
      'type': type.name,
    });
  }


  IconData _getIconForType(StreamType type) {
    switch (type) {
      case StreamType.live:
        return Icons.live_tv_rounded;
      case StreamType.movie:
        return Icons.movie_filter_outlined;
      case StreamType.series:
        return Icons.video_library_outlined;
    }
  }
}
