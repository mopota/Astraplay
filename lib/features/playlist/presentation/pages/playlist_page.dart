import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/playlist.entity.dart';
import '../bloc/playlist_bloc.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import 'dart:async';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: BlocListener<PlaylistBloc, PlaylistState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              title: Text(
                'Select Source',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
              ),
              centerTitle: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => context.push('/add-source'),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: BlocBuilder<PlaylistBloc, PlaylistState>(
                  builder: (context, state) {
                    if (state.isLoading && state.playlists.isNotEmpty) {
                      return const LinearProgressIndicator(minHeight: 4);
                    }
                    return const SizedBox(height: 4);
                  },
                ),
              ),
            ),
            BlocBuilder<PlaylistBloc, PlaylistState>(
              builder: (context, state) {
                if (state.isLoading && state.playlists.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (state.playlists.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(context),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final playlist = state.playlists[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PlaylistCard(playlist: playlist),
                        );
                      },
                      childCount: state.playlists.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-source'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add New'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_motion_rounded,
            size: 80,
            color: colorScheme.primary.withAlpha(50),
          ),
          const SizedBox(height: 24),
          Text(
            'No sources added yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a playlist or direct link to start',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.push('/add-source'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('GET STARTED'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final PlaylistEntity playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isXtream = playlist.type == 'xtream';
    final isDirect = playlist.type == 'directStream';

    Color brandColor;
    IconData icon;
    String typeLabel;

    if (isXtream) {
      brandColor = Colors.blue;
      icon = Icons.cloud_queue_rounded;
      typeLabel = 'XTREAM';
    } else if (isDirect) {
      brandColor = Colors.redAccent;
      icon = Icons.bolt_rounded;
      typeLabel = 'DIRECT';
    } else {
      brandColor = Colors.orange;
      icon = Icons.format_list_bulleted_rounded;
      typeLabel = 'M3U';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSelect(context),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                brandColor.withAlpha(isDirect ? 30 : 20),
                colorScheme.surface,
              ],
            ),
            border: Border.all(
              color: brandColor.withAlpha(50),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon with badge
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: brandColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, color: brandColor, size: 30),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: brandColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (isDirect)
                      Text(
                        playlist.url ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withAlpha(150),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Row(
                        children: [
                          _buildStatBadge(context, '${playlist.channelCount}', Icons.live_tv_rounded, brandColor),
                          const SizedBox(width: 8),
                          _buildStatBadge(context, '${playlist.movieCount}', Icons.movie_rounded, brandColor),
                          const SizedBox(width: 8),
                          _buildStatBadge(context, '${playlist.seriesCount}', Icons.video_library_rounded, brandColor),
                        ],
                      ),
                    if (playlist.lastRefresh != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last sync: ${DateFormat.yMMMd().add_jm().format(playlist.lastRefresh!)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant.withAlpha(100),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showMenu(context),
                icon: const Icon(Icons.more_vert_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: brandColor.withAlpha(20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSelect(BuildContext context) async {
    // Set active playlist
    await context.read<SettingsCubit>().setActivePlaylist(playlist.id);
    
    if (!context.mounted) return;

    if (playlist.type == 'directStream') {
      unawaited(context.push('/player', extra: {
        'streamUrl': playlist.url,
        'title': playlist.name,
      }));
    } else {
      context.go('/'); 
    }
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                playlist.name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Refresh Content'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<PlaylistBloc>().add(RefreshPlaylistEvent(id: playlist.id));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Remove Source', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final bloc = context.read<PlaylistBloc>();
    final settingsCubit = context.read<SettingsCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Source?'),
        content: Text('This will remove "${playlist.name}" and all its contents from your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              // If we are deleting the active playlist, unset it
              if (settingsCubit.state.settings.activePlaylistId == playlist.id) {
                await settingsCubit.setActivePlaylist(null);
              }
              bloc.add(DeletePlaylistEvent(id: playlist.id));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Yes, remove'),
          ),
        ],
      ),
    );
  }
}
