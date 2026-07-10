import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
            const SnackBar(content: Text('Playlist imported successfully')),
          );
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Add M3U Playlist')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import Remote Playlist',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Playlist Name',
                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'M3U URL',
                  hintText: 'http://example.com/playlist.m3u',
                  prefixIcon: const Icon(Icons.cloud_download_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 32),
              BlocBuilder<PlaylistBloc, PlaylistState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isLoading ? null : _importPlaylist,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: state.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Import Playlist'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Note: Large playlists may take a few seconds to parse and save to your device.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    context.read<PlaylistBloc>().add(AddM3uPlaylistEvent(
      name: _nameController.text,
      url: _urlController.text,
    ));
  }
}
