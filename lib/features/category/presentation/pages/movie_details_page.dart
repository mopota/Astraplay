import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../injection_container.dart';

class MovieDetailsPage extends StatefulWidget {
  final AppStream stream;

  const MovieDetailsPage({super.key, required this.stream});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late bool _isFavorite;
  Map<String, dynamic>? _metadata;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.stream.isFavorite;
    if (widget.stream.data.metadata != null) {
      try {
        _metadata = jsonDecode(widget.stream.data.metadata!);
      } catch (_) {}
    }
  }

  Future<void> _toggleFavorite() async {
    final db = sl<AppDatabase>();
    await db.toggleFavorite(widget.stream.id);
    setState(() => _isFavorite = !_isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    final plot = _metadata?['plot']?.toString() ?? _metadata?['description']?.toString();
    final rating = _metadata?['rating']?.toString() ?? _metadata?['rating_5based']?.toString();
    final year = _metadata?['year']?.toString() ?? _metadata?['releaseDate']?.toString().split('-').first;
    final director = _metadata?['director']?.toString();
    final cast = _metadata?['cast']?.toString();
    final genre = _metadata?['genre']?.toString();

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
                  // Info Badges
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
                  
                  // Play Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _playMovie,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                        shadowColor: colorScheme.primary.withAlpha(100),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 32),
                      label: const Text('WATCH NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (plot != null && plot.isNotEmpty) ...[
                    Text('Storyline', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20)),
                    const SizedBox(height: 12),
                    Text(
                      plot,
                      style: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(200), height: 1.6, fontSize: 15),
                    ),
                  ],

                  if (director != null || cast != null) ...[
                    const SizedBox(height: 32),
                    Divider(color: colorScheme.outlineVariant.withAlpha(50)),
                    const SizedBox(height: 24),
                    if (director != null) _buildInfoRow('Director', director, colorScheme),
                    if (cast != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow('Cast', cast, colorScheme),
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
        title: Text(
          widget.stream.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
            shadows: [const Shadow(offset: Offset(0, 2), blurRadius: 10.0, color: Colors.black87)],
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
                errorWidget: (_, __, ___) => Container(color: colorScheme.surfaceContainerHighest),
              )
            else
              Container(color: colorScheme.surfaceContainerHighest),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black],
                  stops: [0.0, 0.3, 0.6, 1.0],
                ),
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
      'headers': widget.stream.data.headersJson != null 
          ? Map<String, String>.from(jsonDecode(widget.stream.data.headersJson!)) 
          : null,
    });
  }
}
