import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../injection_container.dart';
import '../../domain/repositories/stream_repository.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:async';

class SeriesDetailsPage extends StatefulWidget {
  final AppStream stream;
  final List<AppStream>? m3uEpisodes;

  const SeriesDetailsPage({
    super.key,
    required this.stream,
    this.m3uEpisodes,
  });

  @override
  State<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

class _SeriesDetailsPageState extends State<SeriesDetailsPage> {
  Map<String, List<Map<String, String>>> _seasons = {};
  bool _isLoading = true;
  String? _selectedSeason;
  late bool _isFavorite;
  final Set<String> _watchedUrls = {};
  Map<String, dynamic>? _lastWatchedEpisode;
  Map<String, dynamic>? _seriesMetadata;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.stream.isFavorite;
    if (widget.stream.data.metadata != null) {
      try {
        _seriesMetadata = jsonDecode(widget.stream.data.metadata!);
      } catch (_) {}
    }
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    final episodes = await _getEpisodes();
    
    // Fetch history to mark watched episodes
    await _refreshHistory();

    final Map<String, List<Map<String, String>>> grouped = {};

    for (final ep in episodes) {
      String season = ep['season'] ?? '1';
      // Normalize season: "01" -> "1", "Season 1" -> "1"
      final match = RegExp(r'(\d+)').firstMatch(season);
      if (match != null) {
        season = int.tryParse(match.group(1)!)?.toString() ?? season;
      }

      grouped.putIfAbsent(season, () => []).add(ep);
    }

    // Sort episodes within each season by episode number
    grouped.forEach((season, epList) {
      epList.sort((a, b) {
        final na = int.tryParse(a['number'] ?? '');
        final nb = int.tryParse(b['number'] ?? '');
        if (na != null && nb != null) return na.compareTo(nb);
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });
    });

    if (mounted) {
      setState(() {
        _seasons = grouped;
        if (grouped.keys.isNotEmpty) {
          final sortedKeys = grouped.keys.toList()
            ..sort((a, b) {
              final na = int.tryParse(a);
              final nb = int.tryParse(b);
              if (na != null && nb != null) return na.compareTo(nb);
              return a.compareTo(b);
            });
          _selectedSeason = sortedKeys.first;
        } else {
          _selectedSeason = null;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHistory() async {
    try {
      final db = sl<AppDatabase>();
      final history = await db.isar.historyRecords
          .filter()
          .streamIdEqualTo(widget.stream.id)
          .sortByLastWatchedDesc()
          .findAll();
      
      final watched = <String>{};
      Map<String, dynamic>? lastEp;
      
      for (final record in history) {
        if (record.episodeMetadata != null) {
          try {
            final data = jsonDecode(record.episodeMetadata!);
            if (data['url'] != null) {
              watched.add(data['url']);
              lastEp ??= data;
            }
          } catch (_) {}
        }
      }
      
      if (mounted) {
        setState(() {
          _watchedUrls.clear();
          _watchedUrls.addAll(watched);
          _lastWatchedEpisode = lastEp;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final result = await sl<StreamRepository>().toggleFavorite(widget.stream);
      result.fold(
        (l) => null,
        (updatedStream) {
          if (mounted) {
            setState(() {
              _isFavorite = updatedStream.isFavorite;
              widget.stream.id = updatedStream.id;
              widget.stream.isFavorite = updatedStream.isFavorite;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  Future<List<Map<String, String>>> _getEpisodes() async {
    // 1. IF XTREAM: Always fetch from API
    if (widget.stream.data.xtreamId != null) {
      try {
        final db = sl<AppDatabase>();
        final playlist = await db.isar.playlists.get(widget.stream.playlistId);
        if (playlist == null) return [];

        final url = playlist.info.serverUrl!;
        final user = playlist.info.username!;
        final pass = playlist.info.password!;
        final seriesId = widget.stream.data.xtreamId!;

        final dio = sl<Dio>();
        final response = await dio.get('$url/player_api.php', queryParameters: {
          'username': user,
          'password': pass,
          'action': 'get_series_info',
          'series_id': seriesId,
        });

        if (response.statusCode == 200 && response.data != null) {
          dynamic responseData = response.data;
          if (responseData is String) {
            try {
              responseData = jsonDecode(responseData);
            } catch (_) {}
          }

          dynamic episodesData;
          if (responseData is Map) {
            episodesData = responseData['episodes'];
          }

          final List<Map<String, String>> episodes = [];
          
          if (episodesData is Map) {
            episodesData.forEach((seasonKey, epList) {
              if (epList is List) {
                for (final e in epList) {
                  final id = e['id'] ?? e['stream_id'];
                  if (id == null) continue;
                  
                  final ext = e['container_extension'] ?? 'mp4';
                  final epNum = e['episode_num']?.toString() ?? '';
                  final title = e['title']?.toString();
                  
                  // Use season number from data if available, else from the map key
                  String sNum = e['season']?.toString() ?? seasonKey.toString();
                  sNum = sNum.replaceAll(RegExp(r'[^0-9]'), '');
                  if (sNum.isEmpty) sNum = '1';

                  episodes.add({
                    'name': (title == null || title.isEmpty) ? 'Episode $epNum' : title,
                    'url': '$url/series/$user/$pass/$id.$ext',
                    'season': sNum,
                    'number': epNum,
                    'id': id.toString(),
                  });
                }
              }
            });
          } else if (episodesData is List) {
            for (final e in episodesData) {
              final id = e['id'] ?? e['stream_id'];
              if (id == null) continue;

              final ext = e['container_extension'] ?? 'mp4';
              final epNum = e['episode_num']?.toString() ?? '';
              final title = e['title']?.toString();
              
              String sNum = e['season']?.toString() ?? '1';
              sNum = sNum.replaceAll(RegExp(r'[^0-9]'), '');
              if (sNum.isEmpty) sNum = '1';

              episodes.add({
                'name': (title == null || title.isEmpty) ? 'Episode $epNum' : title,
                'url': '$url/series/$user/$pass/$id.$ext',
                'season': sNum,
                'number': epNum,
                'id': id.toString(),
              });
            }
          }
          if (episodes.isNotEmpty) return episodes;
        }
      } catch (e) {
        debugPrint('Error fetching Xtream episodes: $e');
      }
    }

    // 2. IF M3U:
    List<AppStream> m3uList = widget.m3uEpisodes ?? [];

    // If M3U and no episodes provided (e.g. from Home Page or Search), fetch them from DB
    if (m3uList.isEmpty && widget.stream.data.xtreamId == null) {
      try {
        final db = sl<AppDatabase>();
        
        String getBaseName(String name) {
          // Remove season/episode indicators
          String n = name.split(RegExp(
            r'(\s?[sS]\d{1,2}|\s?[eE]\d{1,2}|\d{1,2}x\d{1,2}|Season|Episode| - |:|\||حلقة|الموسم|part|جزء|موسم|الحلقة|\(\d{4}\)|4k|1080p|720p|hd|sd)',
            caseSensitive: false
          )).first.trim();
          
          // Only strip trailing numbers if the name doesn't seem to be a title with a number (like The 100)
          // Usually, episode numbers at the end are preceded by a space and are 1-3 digits
          if (RegExp(r'\s\d{1,3}$').hasMatch(n) && n.length > 5) {
             n = n.replaceAll(RegExp(r'\s\d+$'), '').trim();
          }
          return n;
        }

        final targetBase = getBaseName(widget.stream.name);
        
        // Search in the whole playlist, not just the category
        final potentialMatches = await db.isar.appStreams
            .filter()
            .playlistIdEqualTo(widget.stream.playlistId)
            .streamTypeEqualTo(StreamType.series)
            .findAll();
        
        m3uList = potentialMatches.where((s) {
          final base = getBaseName(s.name);
          return base.toLowerCase() == targetBase.toLowerCase() || 
                 s.name.toLowerCase().contains(targetBase.toLowerCase());
        }).toList();
      } catch (e) {
        debugPrint('Error fetching M3U episodes from DB: $e');
      }
    }

    if (m3uList.isNotEmpty) {
      final List<Map<String, String>> result = [];
      for (final e in m3uList) {
        final name = e.name.toLowerCase();
        String season = '1';
        String episode = '';

        // Match Season: S01, Season 1, 1x01 (the '1' before x)
        final sMatch = RegExp(r's(\d+)|season\s?(\d+)|(\d+)x\d+', caseSensitive: false).firstMatch(name);
        if (sMatch != null) {
          season = sMatch.group(1) ?? sMatch.group(2) ?? sMatch.group(3) ?? '1';
        }

        // Match Episode: E01, Episode 1, الحلقة 1, 1x01 (the '01' after x), or trailing number
        final eMatch = RegExp(r'e(\d+)|episode\s?(\d+)|حلقة\s?(\d+)|\d+x(\d+)|(?:\s|ح|h)(\d+)$', caseSensitive: false).firstMatch(name);
        if (eMatch != null) {
          episode = eMatch.group(1) ?? eMatch.group(2) ?? eMatch.group(3) ?? eMatch.group(4) ?? eMatch.group(5) ?? '';
        }

        // Normalize
        season = int.tryParse(season)?.toString() ?? season;
        final episodeNum = int.tryParse(episode)?.toString() ?? episode;

        result.add({
          'name': e.name,
          'url': e.data.streamUrl,
          'season': season,
          'number': episodeNum,
          'id': e.id.toString(),
        });
      }
      return result;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, size, colorScheme),
          
          if (_isLoading)
            const SliverFillRemaining(
              child: SizedBox.shrink(),
            )
          else if (_seasons.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No episodes found')),
            )
          else ...[
            _buildSeriesInfo(colorScheme),
            _buildSeasonSelector(colorScheme),
            _buildEpisodeList(colorScheme),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }

  Widget _buildSeriesInfo(ColorScheme colorScheme) {
    final plot = _seriesMetadata?['plot']?.toString() ?? 
                 _seriesMetadata?['description']?.toString();
    final rating = _seriesMetadata?['rating']?.toString();
    final releaseDate = _seriesMetadata?['releaseDate']?.toString() ?? 
                        _seriesMetadata?['last_modified']?.toString();
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (rating != null && rating != '0') ...[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                ],
                if (releaseDate != null) ...[
                  Icon(Icons.calendar_today_rounded, color: colorScheme.outline, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    releaseDate.split('-').first,
                    style: TextStyle(color: colorScheme.outline, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            if (plot != null && plot.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Storyline',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                plot,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withAlpha(200),
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (_lastWatchedEpisode != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final ep = _lastWatchedEpisode!.cast<String, String>();
                    final String? targetSeason = ep['season'];
                    if (targetSeason != null && _seasons.containsKey(targetSeason)) {
                       setState(() => _selectedSeason = targetSeason);
                    }
                    _playEpisode(ep);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('RESUME: ${_lastWatchedEpisode!['name']}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Size size, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: size.height * 0.45,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withAlpha(100),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withAlpha(100),
            child: IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorite ? Colors.redAccent : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        title: Text(
          widget.stream.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.white,
            shadows: [
              const Shadow(
                offset: Offset(0, 2),
                blurRadius: 10.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.stream.data.logoUrl != null)
              CachedNetworkImage(
                imageUrl: widget.stream.data.logoUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.movie_rounded, size: 64),
                ),
              )
            else
              Container(color: colorScheme.surfaceContainerHighest),
            // Multi-layer gradient for better text readability and cinematic look
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonSelector(ColorScheme colorScheme) {
    final sortedSeasons = _seasons.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: sortedSeasons.map((season) {
              final isSelected = _selectedSeason == season;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: InkWell(
                  onTap: () => setState(() => _selectedSeason = season),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: 300.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : colorScheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(100),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    child: Text(
                      'SEASON $season',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeList(ColorScheme colorScheme) {
    final episodes = _seasons[_selectedSeason] ?? [];
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final ep = episodes[index];
            final epNumber = (ep['number']?.isNotEmpty == true) ? ep['number']! : '${index + 1}';
            final isWatched = _watchedUrls.contains(ep['url']);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () => _playEpisode(ep, index),
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isWatched 
                        ? colorScheme.primary.withAlpha(60)
                        : colorScheme.outlineVariant.withAlpha(40),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Episode Number Box
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isWatched 
                            ? colorScheme.primary.withAlpha(40)
                            : colorScheme.primaryContainer.withAlpha(80),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            epNumber,
                            style: GoogleFonts.poppins(
                              color: isWatched ? colorScheme.primary : colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title and Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ep['name'] ?? 'Episode $epNumber',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isWatched) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.visibility_rounded,
                                    size: 18,
                                    color: colorScheme.primary.withAlpha(200),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Season $_selectedSeason',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Play Button
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isWatched
                            ? colorScheme.primary.withAlpha(30)
                            : colorScheme.surfaceContainerHighest.withAlpha(150),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isWatched ? Icons.play_circle_outline_rounded : Icons.play_arrow_rounded,
                          size: 24,
                          color: isWatched ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: episodes.length,
        ),
      ),
    );
  }

  void _playEpisode(Map<String, String> ep, [int? index]) async {
    final url = ep['url'];
    if (url != null) {
      setState(() {
        _watchedUrls.add(url);
      });
    }

    final season = ep['season'] ?? _selectedSeason;
    final currentEpisodes = _seasons[season] ?? [];
    int actualIndex = index ?? -1;
    
    if (actualIndex == -1) {
      actualIndex = currentEpisodes.indexWhere((e) => e['url'] == ep['url']);
    }

    await context.push('/player', extra: {
      'streamUrl': ep['url'],
      'title': '${widget.stream.name} - ${ep['name']}',
      'streamId': widget.stream.id,
      'stream': widget.stream,
      'episodeMetadata': jsonEncode({
        'url': ep['url'],
        'name': ep['name'],
        'episodeId': ep['id'],
        'season': ep['season'],
      }),
      'playlist': currentEpisodes.isNotEmpty ? currentEpisodes : null,
      'initialIndex': actualIndex != -1 ? actualIndex : null,
    });
    
    // Refresh history when coming back to ensure sync
    if (mounted) {
      unawaited(_refreshHistory());
    }
  }
}
