class M3UEntry {
  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String type; // 'live', 'movie', 'series'
  final String? epgId;
  final Map<String, String> attributes;
  final Map<String, String> headers;

  M3UEntry({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.type = 'live',
    this.epgId,
    this.attributes = const {},
    this.headers = const {},
  });

  @override
  String toString() => 'M3UEntry(name: $name, group: $group, type: $type)';
}

class M3UParser {
  static List<M3UEntry> parse(String content) {
    final List<M3UEntry> entries = [];
    final lines = content.split('\n');
    
    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;
    String currentType = 'live';
    Map<String, String> currentAttributes = {};
    Map<String, String> currentHeaders = {};

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final infoPart = line.substring(8);
        currentAttributes = _parseAttributes(infoPart);

        final commaIndex = infoPart.lastIndexOf(',');
        if (commaIndex != -1) {
          currentName = infoPart.substring(commaIndex + 1).trim();
        }

        currentLogo = currentAttributes['tvg-logo'];
        currentGroup = currentAttributes['group-title'];
        currentEpgId = currentAttributes['tvg-id'];
        
      } else if (line.startsWith('#EXTGRP:')) {
        currentGroup = line.substring(8).trim();
      } else if (line.startsWith('#EXTVLCOPT:')) {
        final opt = line.substring(11).trim();
        if (opt.startsWith('http-user-agent=')) {
          currentHeaders['User-Agent'] = opt.substring(16);
        } else if (opt.startsWith('http-referrer=')) {
          currentHeaders['Referer'] = opt.substring(14);
        } else if (opt.startsWith('http-origin=')) {
          currentHeaders['Origin'] = opt.substring(12);
        }
      } else if (line.startsWith('#HTTP-USER-AGENT:')) {
        currentHeaders['User-Agent'] = line.substring(17).trim();
      } else if (!line.startsWith('#')) {
        if (currentName != null || line.startsWith('http')) {
          currentType = _detectFinalType(currentName ?? '', currentGroup ?? '', line);

          entries.add(M3UEntry(
            name: currentName ?? 'Unknown Channel',
            url: line,
            logo: currentLogo,
            group: currentGroup ?? 'Uncategorized',
            type: currentType,
            epgId: currentEpgId,
            attributes: currentAttributes,
            headers: Map.from(currentHeaders),
          ));
        }
        // Reset for next entry
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentEpgId = null;
        currentType = 'live';
        currentAttributes = {};
        currentHeaders = {};
      }
    }
    return entries;
  }

  static String _detectFinalType(String name, String group, String url) {
    final n = name.toLowerCase();
    final g = group.toLowerCase();
    final u = url.toLowerCase();

    // 1. Live TV Protection (Must be first)
    final liveKeywords = ['live', 'tv', 'قناة', 'قنوات', 'بث مباشر', 'beIn', 'osn', 'mbc', 'ssc', 'sports', 'nilesat'];
    final hasLiveMarker = liveKeywords.any((kw) => n.contains(kw) || g.contains(kw));
    
    // If it's a stream with no extension or a live marker, it's Live
    if (hasLiveMarker && !u.contains('.mp4') && !u.contains('.mkv')) return 'live';

    // 2. Series Deep Detection (Regex for S01E01, Part 1, Season, etc.)
    final seriesRegex = RegExp(r's\d+|e\d+|season|episode|حلقة|موسم|مسلسل|جزء', caseSensitive: false);
    final isSeriesGroup = g.contains('series') || g.contains('مسلسلات') || g.contains('رمضان') || g.contains('anime');
    
    if (seriesRegex.hasMatch(n) || isSeriesGroup) {
      // Final check: if it has a movie extension and no series marker in name, it might be a movie in a wrong group
      if ((u.contains('.mp4') || u.contains('.mkv')) && !seriesRegex.hasMatch(n)) {
        return 'movie';
      }
      return 'series';
    }

    // 3. Movie Detection
    final movieExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv'];
    final movieKeywords = ['movie', 'aflam', 'افلام', 'cinema', 'نتفلكس', 'watchit', 'فيلم'];
    
    if (movieExtensions.any((ext) => u.contains(ext)) || movieKeywords.any((kw) => g.contains(kw) || n.contains(kw))) {
      return 'movie';
    }

    return 'live';
  }

  static Map<String, String> _parseAttributes(String line) {
    final Map<String, String> attrs = {};
    // Advanced Regex to handle spaces in attributes without quotes
    final matches = RegExp(r'([a-zA-Z0-9_-]+)\s*=\s*(?:"([^"]*)"|' "'" r"([^']*)" r'|([^,\s]+))').allMatches(line);
    for (final m in matches) {
      final key = m.group(1)!;
      final value = m.group(2) ?? m.group(3) ?? m.group(4);
      if (value != null) {
        attrs[key] = value.trim();
      }
    }
    return attrs;
  }
}
