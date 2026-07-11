import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../playlist/presentation/bloc/playlist_bloc.dart';

class DirectStreamPage extends StatefulWidget {
  const DirectStreamPage({super.key});

  @override
  State<DirectStreamPage> createState() => _DirectStreamPageState();
}

class _DirectStreamPageState extends State<DirectStreamPage> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();

  String _normalizeUrl(String url) {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'http://$trimmed';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlaylistBloc, PlaylistState>(
      listener: (context, state) {
        if (state.operationSuccess) {
          final url = _normalizeUrl(_urlController.text);
          final name = _nameController.text.trim();
          
          // Clear any errors or loading states
          context.go('/playlists'); 
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('direct_stream_success'))),
          );
          
          // Small delay to ensure the router has settled
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              context.push('/player', extra: {
                'streamUrl': url,
                'title': name,
              });
            }
          });
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('direct_stream'))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('watch_single_link'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('direct_stream_desc_long'),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('friendly_name'),
                  hintText: 'e.g., Sports Channel',
                  prefixIcon: const Icon(Icons.label_important_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: context.tr('stream_url'),
                  hintText: 'http://.../playlist.m3u8',
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(height: 40),
              BlocBuilder<PlaylistBloc, PlaylistState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isLoading ? null : _saveAndPlay,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: state.isLoading 
                        ? const SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : Text(context.tr('save_watch_now'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              _buildSupportedFormats(),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAndPlay() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_name_url'))),
      );
      return;
    }

    context.read<PlaylistBloc>().add(AddDirectStreamEvent(
      name: name,
      url: _normalizeUrl(url),
    ));
  }

  Widget _buildSupportedFormats() {
    return Opacity(
      opacity: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('formats_support'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'HLS (.m3u8)', 'DASH (.mpd)', 'MP4', 'MKV', 'TS', 'MOV'
            ].map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withAlpha(100)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(e, style: const TextStyle(fontSize: 10)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
