import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Legal & Privacy',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Privacy Policy'),
              Tab(text: 'Terms of Service'),
            ],
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            indicatorColor: colorScheme.primary,
            labelColor: colorScheme.primary,
          ),
        ),
        body: TabBarView(
          children: [
            _buildPrivacyPolicy(context),
            _buildTermsOfService(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicy(BuildContext context) {
    return _buildLegalContent(
      context,
      title: 'Privacy Policy',
      lastUpdated: 'October 26, 2023',
      sections: [
        _LegalSection(
          title: '1. Information We Collect',
          content: 'AstraPlay is designed to be a privacy-first IPTV player. We do not collect personal identification information such as your name, email, or phone number. We may store local data on your device including your playlists, favorites, and watch history to improve your experience.',
        ),
        _LegalSection(
          title: '2. Local Data Storage',
          content: 'All playlist URLs, credentials (if any), and stream history are stored locally on your device using an encrypted-ready database. We do not transmit this data to our servers.',
        ),
        _LegalSection(
          title: '3. Third-Party Services',
          content: 'When you play a stream, the application connects directly to the URL provided by your IPTV provider. Your IP address and device information may be visible to your IPTV provider as part of the standard HTTP request process.',
        ),
        _LegalSection(
          title: '4. Analytics',
          content: 'We may collect anonymous crash reports to help improve the stability of the application. These reports do not contain any data that could identify you or your content sources.',
        ),
      ],
    );
  }

  Widget _buildTermsOfService(BuildContext context) {
    return _buildLegalContent(
      context,
      title: 'Terms of Service',
      lastUpdated: 'October 26, 2023',
      sections: [
        _LegalSection(
          title: '1. Acceptance of Terms',
          content: 'By using AstraPlay, you agree to comply with and be bound by these terms. If you do not agree, please do not use the application.',
        ),
        _LegalSection(
          title: '2. No Content Provided',
          content: 'AstraPlay DOES NOT PROVIDE ANY CONTENT. We are a pure media player. Users are responsible for providing their own content, including M3U playlists and Xtream Codes credentials. We do not endorse the streaming of copyrighted material without permission.',
        ),
        _LegalSection(
          title: '3. Legal Use',
          content: 'You agree to use AstraPlay only for lawful purposes. You are solely responsible for ensuring that your use of the application and the content you access complies with all applicable laws in your jurisdiction.',
        ),
        _LegalSection(
          title: '4. Disclaimer of Warranty',
          content: 'AstraPlay is provided "as is" without warranty of any kind. We do not guarantee that the application will be error-free or that the streams will be compatible with our player.',
        ),
        _LegalSection(
          title: '5. Limitation of Liability',
          content: 'In no event shall AstraPlay or its developers be liable for any damages arising out of the use or inability to use the application.',
        ),
      ],
    );
  }

  Widget _buildLegalContent(
    BuildContext context, {
    required String title,
    required String lastUpdated,
    required List<_LegalSection> sections,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last Updated: $lastUpdated',
          style: TextStyle(
            color: colorScheme.outline,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        ...sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    section.content,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _LegalSection {
  final String title;
  final String content;

  _LegalSection({required this.title, required this.content});
}
