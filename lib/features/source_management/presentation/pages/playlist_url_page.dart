import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/presentation/widgets/progress_button.dart';
import '../../../playlist/presentation/bloc/playlist_bloc.dart';

class PlaylistUrlPage extends StatefulWidget {
  const PlaylistUrlPage({super.key});

  @override
  State<PlaylistUrlPage> createState() => _PlaylistUrlPageState();
}

class _PlaylistUrlPageState extends State<PlaylistUrlPage> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlaylistBloc, PlaylistState>(
      listener: (context, state) {
        if (state.operationSuccess) {
          context.go('/playlists');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('playlist_success'))),
          );
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.tr('error')}: ${state.error}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('add_m3u_playlist'))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('import_remote_playlist'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('playlist_name'),
                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: context.tr('m3u_url_label'),
                  hintText: 'http://example.com/playlist.m3u',
                  prefixIcon: const Icon(Icons.cloud_download_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 32),
              BlocBuilder<PlaylistBloc, PlaylistState>(
                builder: (context, state) {
                  return ProgressButton(
                    isLoading: state.isLoading,
                    progress: state.progress,
                    statusMessage: state.statusMessage,
                    label: context.tr('import_playlist'),
                    onPressed: _importPlaylist,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('import_note'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _importPlaylist() {
    if (_nameController.text.isEmpty || _urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('fill_all_fields'))),
      );
      return;
    }

    context.read<PlaylistBloc>().add(AddM3uPlaylistEvent(
      name: _nameController.text,
      url: _urlController.text,
    ));
  }
}
