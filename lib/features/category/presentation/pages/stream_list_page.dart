import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../injection_container.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/repositories/stream_repository.dart';
import 'package:dartz/dartz.dart' as dartz;
import '../../../../core/errors/failures.dart';

class StreamListPage extends StatefulWidget {
  final int playlistId;
  final String category;
  final StreamType type;

  const StreamListPage({
    super.key,
    required this.playlistId,
    required this.category,
    required this.type,
  });

  @override
  State<StreamListPage> createState() => _StreamListPageState();
}

class _StreamListPageState extends State<StreamListPage> {
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'newest'
  final TextEditingController _searchController = TextEditingController();
  late Future<dartz.Either<Failure, List<AppStream>>> _streamsFuture;

  @override
  void initState() {
    super.initState();
    _streamsFuture = sl<StreamRepository>().getStreams(widget.playlistId, widget.category, widget.type);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.type == StreamType.live;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(widget.category, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            actions: [
              _buildSortMenu(),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search in ${widget.category}...',
                onChanged: (value) => setState(() => _searchQuery = value),
                leading: const Icon(Icons.search_rounded, size: 20),
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withAlpha(120)),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: FutureBuilder(
              future: _streamsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                final result = snapshot.data;
                if (result == null) return const SliverToBoxAdapter(child: SizedBox());

                return result.fold(
                  (failure) => SliverFillRemaining(child: Center(child: Text(failure.message))),
                  (streams) {
                    final filteredStreams = streams.where((s) {
                      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
                    }).toList();

                    // Sort streams
                    if (_sortBy == 'name') {
                      filteredStreams.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    }

                    if (filteredStreams.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty ? Icons.video_library_outlined : Icons.search_off_rounded,
                                size: 80,
                                color: colorScheme.outline.withAlpha(100),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No items found' : 'No results for "$_searchQuery"',
                                style: TextStyle(color: colorScheme.outline, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Smart Grouping for M3U Series (mimics Xtream)
                    final Map<String, List<AppStream>> groupedM3uSeries = {};
                    List<String> m3uSeriesNames = [];

                    final bool isGroupedM3u = widget.type == StreamType.series && 
                                            streams.isNotEmpty && 
                                            streams.every((s) => s.data.xtreamId == null);

                    if (isGroupedM3u) {
                      for (var s in filteredStreams) {
                        String cleanName = s.name.split(RegExp(
                          r'(\s?[sS]\d{1,2}|\s?[eE]\d{1,2}|\d{1,2}x\d{1,2}|Season|Episode| - |:|\||حلقة|الموسم|part|جزء|موسم|الحلقة|\(\d{4}\)|4k|1080p|720p|hd|sd)',
                          caseSensitive: false
                        )).first.trim();
                        
                        if (RegExp(r'\s\d{1,3}$').hasMatch(cleanName) && cleanName.length > 5) {
                          cleanName = cleanName.replaceAll(RegExp(r'\s\d+$'), '').trim();
                        }

                        final key = cleanName.isEmpty ? s.name : cleanName;
                        groupedM3uSeries.putIfAbsent(key, () => []).add(s);
                      }
                      m3uSeriesNames = groupedM3uSeries.keys.toList();
                      m3uSeriesNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                    }
                    
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isLive ? 2 : 3,
                        childAspectRatio: isLive ? 1.4 : 0.62,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (isGroupedM3u) {
                            final seriesName = m3uSeriesNames[index];
                            final epList = groupedM3uSeries[seriesName]!;
                            return _StreamCard(
                              stream: epList.first,
                              type: widget.type,
                              customTitle: seriesName,
                              m3uEpisodes: epList,
                            );
                          } else {
                            return _StreamCard(stream: filteredStreams[index], type: widget.type);
                          }
                        },
                        childCount: isGroupedM3u ? m3uSeriesNames.length : filteredStreams.length,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort_rounded),
      onSelected: (value) => setState(() => _sortBy = value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'name', child: Text('Sort by Name (A-Z)')),
        const PopupMenuItem(value: 'newest', child: Text('Sort by Newest')),
      ],
    );
  }
}

class _StreamCard extends StatefulWidget {
  final AppStream stream;
  final StreamType type;
  final String? customTitle;
  final List<AppStream>? m3uEpisodes;

  const _StreamCard({
    required this.stream,
    required this.type,
    this.customTitle,
    this.m3uEpisodes,
  });

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.stream.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.type == StreamType.live;
    final isSeries = widget.type == StreamType.series;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isSeries) {
            context.push('/series-details', extra: {
              'stream': widget.stream,
              'm3uEpisodes': widget.m3uEpisodes,
            });
          } else if (widget.type == StreamType.movie) {
            context.push('/movie-details', extra: {
              'stream': widget.stream,
            });
          } else {
            unawaited(context.push('/player', extra: {
              'streamUrl': widget.stream.data.streamUrl,
              'title': widget.stream.name,
              'streamId': widget.stream.id,
              'headers': widget.stream.data.headersJson != null
                  ? Map<String, String>.from(jsonDecode(widget.stream.data.headersJson!))
                  : null,
            }));
          }
        },
        onLongPress: _toggleFavorite,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (widget.stream.data.logoUrl != null && widget.stream.data.logoUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.stream.data.logoUrl!,
                fit: isLive ? BoxFit.contain : BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined, color: colorScheme.outline),
                ),
              )
            else
              Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  isSeries ? Icons.video_library_rounded : (isLive ? Icons.live_tv_rounded : Icons.movie_rounded),
                  size: isLive ? 32 : 40,
                  color: colorScheme.primary.withAlpha(100),
                ),
              ),
            
            // Premium Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 0.7, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(100),
                      Colors.black.withAlpha(220),
                    ],
                  ),
                ),
              ),
            ),

            // Content Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.customTitle ?? widget.stream.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isLive ? 13 : 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Top Status Bar
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                          const SizedBox(width: 4),
                          const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    )
                  else if (isSeries)
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text("SERIES", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    )
                  else
                    const SizedBox(),
                    
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(50)),
                      ),
                      child: Icon(
                        _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _isFavorite ? Colors.redAccent : Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFavorite() async {
    final result = await sl<StreamRepository>().toggleFavorite(widget.stream.id);
    result.fold(
      (l) => null,
      (r) => setState(() => _isFavorite = !_isFavorite),
    );
  }
}
