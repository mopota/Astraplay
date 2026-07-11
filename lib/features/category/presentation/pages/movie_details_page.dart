import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/repositories/stream_repository.dart';

class MovieDetailsPage extends StatefulWidget {
  final AppStream stream;
  const MovieDetailsPage({super.key, required this.stream});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.stream.isFavorite;
  }

  Future<void> _toggleFavorite() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    
    final meta = widget.stream.data.metadata;
    final plot = meta?.plot;
    final rating = meta?.rating;
    final year = meta?.year ?? meta?.releaseDate?.split('-').first;
    final director = meta?.director;
    final cast = meta?.cast;
    final genre = meta?.genre;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, size, colorScheme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (rating != null && rating != '0') ...[
                        _buildBadge(Icons.star_rounded, rating, Colors.amber),
                        const SizedBox(width: 12),
                      ],
                      if (year != null) ...[
                        _buildBadge(Icons.calendar_today_rounded, year, colorScheme.primary),
                        const SizedBox(width: 12),
                      ],
                      if (genre != null)
                        Expanded(child: _buildBadge(Icons.movie_filter_rounded, genre, colorScheme.secondary)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _playMovie,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 32),
                      label: Text(context.tr('watch_now'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (plot != null && plot.isNotEmpty) ...[
                    Text(context.tr('storyline'), style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20)),
                    const SizedBox(height: 12),
                    Text(plot, style: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(200), height: 1.6, fontSize: 15)),
                  ],
                  if (director != null || cast != null) ...[
                    const SizedBox(height: 32),
                    Divider(color: colorScheme.outlineVariant.withAlpha(50)),
                    const SizedBox(height: 24),
                    if (director != null) _buildInfoRow(context.tr('director'), director, colorScheme),
                    if (cast != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(context.tr('cast'), cast, colorScheme),
                    ],
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Size size, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: size.height * 0.5,
      pinned: true,
      backgroundColor: colorScheme.surface,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black45,
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
            backgroundColor: Colors.black45,
            child: IconButton(
              icon: Icon(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _isFavorite ? Colors.redAccent : Colors.white),
              onPressed: _toggleFavorite,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(widget.stream.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.stream.data.logoUrl != null)
              CachedNetworkImage(imageUrl: widget.stream.data.logoUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: colorScheme.surfaceContainerHighest))
            else
              Container(color: colorScheme.surfaceContainerHighest),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playMovie() {
    context.push('/player', extra: {
      'streamUrl': widget.stream.data.streamUrl,
      'title': widget.stream.name,
      'streamId': widget.stream.id,
      'stream': widget.stream,
      'headers': widget.stream.data.headersJson != null ? Map<String, String>.from(jsonDecode(widget.stream.data.headersJson!)) : null,
    });
  }
}
