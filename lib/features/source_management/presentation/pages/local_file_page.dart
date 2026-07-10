import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../playlist/presentation/bloc/playlist_bloc.dart';

class LocalFilePage extends StatefulWidget {
  const LocalFilePage({super.key});

  @override
  State<LocalFilePage> createState() => _LocalFilePageState();
}

class _LocalFilePageState extends State<LocalFilePage> {
  String? _selectedPath;
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocListener<PlaylistBloc, PlaylistState>(
      listener: (context, state) {
        if (state.operationSuccess) {
          context.go('/playlists');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File imported successfully')),
          );
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Import Local File')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Playlist File',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.file_upload_outlined, size: 48, color: colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        _selectedPath != null 
                            ? _selectedPath!.split(Platform.pathSeparator).last
                            : 'Tap to select .m3u or .m3u8 file',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: _selectedPath != null ? FontWeight.bold : FontWeight.normal,
                          color: _selectedPath != null ? colorScheme.onSurface : colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_selectedPath != null) ...[
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Playlist Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 32),
                BlocBuilder<PlaylistBloc, PlaylistState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state.isLoading ? null : _importFile,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: state.isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Import Now'),
                      ),
                    );
                  },
                ),
              ],
              
              const Spacer(),
              const Text(
                'Supported extensions: .m3u, .m3u8, .txt',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedPath = result.files.single.path;
          if (_nameController.text.isEmpty) {
            _nameController.text = _selectedPath!.split(Platform.pathSeparator).last.replaceAll('.m3u', '').replaceAll('.m3u8', '');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _importFile() {
    if (_selectedPath == null || _nameController.text.isEmpty) return;

    context.read<PlaylistBloc>().add(AddM3uFilePlaylistEvent(
      name: _nameController.text,
      filePath: _selectedPath!,
    ));
  }
}
