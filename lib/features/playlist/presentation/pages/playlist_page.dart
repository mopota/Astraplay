import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/playlist.entity.dart';
import '../bloc/playlist_bloc.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import 'dart:async';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar.large(
              title: Text(
                'Select Source',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
              ),
              centerTitle: false,
              pinned: true,
              floating: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => context.push('/add-source'),
                  ),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: const [
                  Tab(text: 'Playlists'),
                  Tab(text: 'Direct Streams'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPlaylistList(context, isDirect: false),
              _buildPlaylistList(context, isDirect: true),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-source'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add New'),
      ),
    );
  }

  Widget _buildPlaylistList(BuildContext context, {required bool isDirect}) {
    return BlocBuilder<PlaylistBloc, PlaylistState>(
      builder: (context, state) {
        if (state.isLoading && state.playlists.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredPlaylists = state.playlists.where((p) {
          final isPDirect = p.type == 'directStream';
          return isDirect ? isPDirect : !isPDirect;
        }).toList();

        if (filteredPlaylists.isEmpty) {
          return _buildEmptyState(context, isDirect: isDirect);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: filteredPlaylists.length,
          itemBuilder: (context, index) {
            final playlist = filteredPlaylists[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlaylistCard(playlist: playlist),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isDirect}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDirect ? Icons.bolt_rounded : Icons.auto_awesome_motion_rounded,
            size: 80,
            color: colorScheme.primary.withAlpha(50),
          ),
          const SizedBox(height: 24),
          Text(
            isDirect ? 'No direct streams' : 'No playlists added',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDirect ? 'Add a direct link to watch instantly' : 'Add an M3U or Xtream source',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.push('/add-source'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('ADD NOW'),
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

    if (isXtream) {
      brandColor = Colors.blue;
      icon = Icons.cloud_queue_rounded;
    } else if (isDirect) {
      brandColor = Colors.teal;
      icon = Icons.bolt_rounded;
    } else {
      brandColor = Colors.orange;
      icon = Icons.format_list_bulleted_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSelect(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: colorScheme.surfaceContainerLow,
            border: Border.all(
              color: brandColor.withAlpha(40),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: brandColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: brandColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (isDirect)
                      Text(
                        playlist.url ?? '',
                        style: TextStyle(
                          fontSize: 11,
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
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () => _showMenu(context),
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String count, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color.withAlpha(180)),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _handleSelect(BuildContext context) async {
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                playlist.name,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Details'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context);
              },
            ),
            if (playlist.type != 'directStream')
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Sync Content'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<PlaylistBloc>().add(RefreshPlaylistEvent(id: playlist.id));
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete Source', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameController = TextEditingController(text: playlist.name);
    final urlController = TextEditingController(text: playlist.url);
    final userController = TextEditingController(text: playlist.username);
    final passController = TextEditingController(text: playlist.password);
    final isXtream = playlist.type == 'xtream';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Source'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              if (playlist.type != 'm3uFile')
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(labelText: isXtream ? 'Server URL' : 'URL'),
                ),
              if (isXtream) ...[
                TextField(
                  controller: userController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: passController,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<PlaylistBloc>().add(UpdatePlaylistEvent(
                id: playlist.id,
                name: nameController.text,
                url: urlController.text.isNotEmpty ? urlController.text : null,
                username: userController.text.isNotEmpty ? userController.text : null,
                password: passController.text.isNotEmpty ? passController.text : null,
              ));
              Navigator.pop(dialogContext);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final bloc = context.read<PlaylistBloc>();
    final settingsCubit = context.read<SettingsCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Remove "${playlist.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              if (settingsCubit.state.settings.activePlaylistId == playlist.id) {
                await settingsCubit.setActivePlaylist(null);
              }
              bloc.add(DeletePlaylistEvent(id: playlist.id));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
