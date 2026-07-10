import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/subtitle_cubit.dart';
import '../../data/models/subtitle_model.dart';

class SubtitleDownloaderSheet extends StatefulWidget {
  final String initialQuery;
  final Function(String path) onSubtitleSelected;

  const SubtitleDownloaderSheet({
    super.key,
    required this.initialQuery,
    required this.onSubtitleSelected,
  });

  @override
  State<SubtitleDownloaderSheet> createState() => _SubtitleDownloaderSheetState();
}

class _SubtitleDownloaderSheetState extends State<SubtitleDownloaderSheet> {
  late TextEditingController _searchController;
  String _selectedLanguage = 'ar';
  final List<Map<String, String>> _languages = [
    {'name': 'Arabic', 'code': 'ar'},
    {'name': 'English', 'code': 'en'},
    {'name': 'French', 'code': 'fr'},
    {'name': 'Spanish', 'code': 'es'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    // Auto search on open
    context.read<SubtitleCubit>().search(widget.initialQuery, languages: _selectedLanguage);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          const SizedBox(height: 24),
          _buildHeader(theme),
          const SizedBox(height: 20),
          _buildSearchAndFilters(theme),
          const SizedBox(height: 16),
          Expanded(child: _buildResultsList(theme)),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subtitle Downloader',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Powered by OpenSubtitles.org',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for movie or series...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () {
                context.read<SubtitleCubit>().search(_searchController.text, languages: _selectedLanguage);
              },
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) {
            context.read<SubtitleCubit>().search(value, languages: _selectedLanguage);
          },
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _languages.map((lang) {
              final isSelected = _selectedLanguage == lang['code'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(lang['name']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedLanguage = lang['code']!);
                    context.read<SubtitleCubit>().search(_searchController.text, languages: _selectedLanguage);
                  },
                  selectedColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(ThemeData theme) {
    return BlocConsumer<SubtitleCubit, SubtitleState>(
      listener: (context, state) {
        if (state is SubtitleDownloadSuccess) {
          widget.onSubtitleSelected(state.path);
          Navigator.pop(context);
        } else if (state is SubtitleError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is SubtitleLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SubtitleSearchSuccess) {
          if (state.results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.subtitles_off_rounded, size: 64, color: theme.colorScheme.outline.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('No subtitles found', style: TextStyle(color: theme.colorScheme.outline)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: state.results.length,
            itemBuilder: (context, index) {
              final sub = state.results[index];
              return _buildSubtitleItem(sub, theme);
            },
          );
        }

        return Center(
          child: Text('Enter a title to search', style: TextStyle(color: theme.colorScheme.outline)),
        );
      },
    );
  }

  Widget _buildSubtitleItem(SubtitleSearchResult sub, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(sub.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Row(
          children: [
            Icon(Icons.star_rounded, size: 14, color: Colors.amber),
            const SizedBox(width: 4),
            Text(sub.rating.toString(), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 12),
            Icon(Icons.download_rounded, size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(sub.downloadCount.toString(), style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: IconButton.filledTonal(
          onPressed: () => context.read<SubtitleCubit>().download(sub),
          icon: const Icon(Icons.download_rounded),
        ),
      ),
    );
  }
}
