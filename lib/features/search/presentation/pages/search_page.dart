import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar_community/isar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/database/app_database.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../domain/repositories/search_repository.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<AppStream> _localResults = [];
  List<String> _history = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = sl<AppDatabase>();
    final history = await db.isar.searchHistorys.where().sortByTimestampDesc().limit(10).findAll();
    if (mounted) {
      setState(() {
        _history = history.map((h) => h.query).toList();
      });
    }
  }

  Future<void> _saveToHistory(String query) async {
    if (query.trim().isEmpty) return;
    final db = sl<AppDatabase>();
    final h = SearchHistory()..query = query.trim().toLowerCase()..timestamp = DateTime.now();
    await db.isar.writeTxn(() => db.isar.searchHistorys.put(h));
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _localResults = []);
      return;
    }
    setState(() => _isLoading = true);
    
    final activeId = context.read<SettingsCubit>().state.settings.activePlaylistId;
    final result = await sl<SearchRepository>().search(query, playlistId: activeId);

    result.fold(
      (failure) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (streams) {
        if (mounted) {
          setState(() {
            _localResults = streams;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SearchBar(
            controller: _controller,
            autoFocus: true,
            hintText: 'Search movies, series or channels...',
            onChanged: _onSearchChanged,
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withAlpha(120)),
            leading: const Icon(Icons.search_rounded),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            trailing: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _controller.clear();
                    _performSearch('');
                  },
                ),
            ],
          ),
        ),
      ),
      body: _buildLocalResults(),
    );
  }

  Widget _buildLocalResults() {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    if (_localResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_controller.text.isEmpty && _history.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Searches', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16)),
                  TextButton(
                    onPressed: () async {
                      final db = sl<AppDatabase>();
                      await db.isar.writeTxn(() => db.isar.searchHistorys.clear());
                      _loadHistory();
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _history.map((q) => ActionChip(
                  label: Text(q),
                  onPressed: () {
                    _controller.text = q;
                    _performSearch(q);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                )).toList(),
              ),
              const SizedBox(height: 32),
            ],
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha(10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _controller.text.isEmpty ? Icons.search_rounded : Icons.search_off_rounded,
                        size: 80,
                        color: colorScheme.primary.withAlpha(50),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _controller.text.isEmpty ? 'Find your favorites' : 'No matches found',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _controller.text.isEmpty ? 'Search through your added playlists' : 'Try different keywords',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _localResults.length,
      itemBuilder: (context, index) {
        final stream = _localResults[index];
        final isLive = stream.streamType == StreamType.live;
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colorScheme.outlineVariant.withAlpha(50)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: stream.data.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: stream.data.logoUrl!,
                      fit: isLive ? BoxFit.contain : BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => const Icon(Icons.movie_filter_outlined),
                    )
                  : const Icon(Icons.play_arrow_rounded),
            ),
            title: Text(
              stream.name, 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stream.streamType.name.toUpperCase(),
                      style: TextStyle(color: colorScheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stream.categoryName,
                      style: TextStyle(fontSize: 12, color: colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ),
            onTap: () async {
              if (stream.streamType == StreamType.series) {
                List<AppStream>? m3uEpisodes;
                if (stream.data.xtreamId == null) {
                  final allStreams = await sl<AppDatabase>().getStreamsByCategory(
                    stream.playlistId,
                    stream.categoryName,
                    StreamType.series,
                  );
                  
                  String getBaseName(String name) {
                    return name.split(RegExp(
                      r'(\s?[sS]\d{1,2}|\s?[eE]\d{1,2}|\d{1,2}x\d{1,2}|Season|Episode| - |:|\||حلقة|الموسم|part|جزء|موسم|الحلقة|\(\d{4}\)|4k|1080p|720p|hd|sd)', 
                      caseSensitive: false
                    )).first.trim().replaceAll(RegExp(r'\s+\d+$'), '').trim();
                  }

                  final targetBaseName = getBaseName(stream.name);
                  m3uEpisodes = allStreams.where((s) => getBaseName(s.name) == targetBaseName).toList();
                }

                _saveToHistory(_controller.text);
                if (context.mounted) {
                  await context.push('/series-details', extra: {
                    'stream': stream,
                    'm3uEpisodes': m3uEpisodes,
                  });
                }
              } else if (stream.streamType == StreamType.movie) {
                _saveToHistory(_controller.text);
                if (context.mounted) {
                  await context.push('/movie-details', extra: {
                    'stream': stream,
                  });
                }
              } else {
                _saveToHistory(_controller.text);
                if (context.mounted) {
                  await context.push('/player', extra: {
                    'streamUrl': stream.data.streamUrl,
                    'title': stream.name,
                    'streamId': stream.id,
                    'headers': stream.data.headersJson != null
                        ? Map<String, String>.from(jsonDecode(stream.data.headersJson!))
                        : null,
                  });
                }
              }
            },
          ),
        ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.1, end: 0);
      },
    );
  }
}
