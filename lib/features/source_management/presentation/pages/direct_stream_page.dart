import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../playlist/presentation/bloc/playlist_bloc.dart';

class DirectStreamPage extends StatefulWidget {
  const DirectStreamPage({super.key});

  @override
  State<DirectStreamPage> createState() => _DirectStreamPageState();
}

class _DirectStreamPageState extends State<DirectStreamPage> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Direct Stream')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Stream Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Stream Name',
                hintText: 'e.g., My Favorite Channel',
                prefixIcon: const Icon(Icons.label_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Stream URL',
                hintText: 'http://.../stream.m3u8',
                prefixIcon: const Icon(Icons.link_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveStream,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save & Watch'),
              ),
            ),
            const SizedBox(height: 24),
            _buildSupportedFormats(),
          ],
        ),
      ),
    );
  }

  void _saveStream() async {
    if (_nameController.text.isEmpty || _urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Add to playlist
    context.read<PlaylistBloc>().add(AddDirectStreamEvent(
      name: _nameController.text,
      url: _urlController.text,
    ));

    // Wait for a bit for the operation to complete (or listen to state)
    // For simplicity, we just push to player after a small delay or success signal
    // In a real app, listen to Bloc listener
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      context.pushReplacement('/player', extra: {
        'streamUrl': _urlController.text,
        'title': _nameController.text,
      });
    }
  }

  Widget _buildSupportedFormats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Supported Formats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '.m3u8', '.mpd', '.ts', '.mp4', '.mkv', '.avi', '.mov', '.flv', '.webm', '.mp3'
          ].map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 11)))).toList(),
        ),
      ],
    );
  }
}
