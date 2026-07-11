import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/app_localizations.dart';

class AddSourcePage extends StatelessWidget {
  const AddSourcePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('new_source'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_to_queue_rounded, size: 48, color: colorScheme.primary),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              context.tr('add_content'),
              style: GoogleFonts.poppins(
                fontSize: 28, 
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              context.tr('add_content_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.outline, fontSize: 14),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 48),
            
            _SourceTypeCard(
              title: context.tr('xtream_codes'),
              subtitle: context.tr('xtream_desc'),
              icon: Icons.vpn_key_rounded,
              color: colorScheme.primary,
              onTap: () => context.push('/add-source/xtream'),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
            
            const SizedBox(height: 16),
            _SourceTypeCard(
              title: context.tr('m3u_playlist'),
              subtitle: context.tr('m3u_desc'),
              icon: Icons.link_rounded,
              color: colorScheme.secondary,
              onTap: () => context.push('/add-source/playlist'),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
            
            const SizedBox(height: 16),
            _SourceTypeCard(
              title: context.tr('single_stream'),
              subtitle: context.tr('direct_stream_card_desc'),
              icon: Icons.bolt_rounded,
              color: Colors.orange,
              onTap: () => context.push('/add-source/direct'),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
            
            const SizedBox(height: 16),
            _SourceTypeCard(
              title: context.tr('local_import'),
              subtitle: context.tr('local_import_desc'),
              icon: Icons.folder_open_rounded,
              color: Colors.purple,
              onTap: () => context.push('/add-source/local'),
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }
}

class _SourceTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SourceTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant.withAlpha(150)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.outlineVariant, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
