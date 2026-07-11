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
}

class M3UParser {
  static final RegExp _attrRegExp = RegExp(r'([a-zA-Z0-9_-]+)\s*=\s*(?:"([^"]*)"|' "'" r"([^']*)" r'|([^,\s]+))');
  
  static const List<String> _liveKeywords = ['live', 'tv', 'قناة', 'قنوات', 'بث مباشر'];
  static final RegExp _seriesRegex = RegExp(r's\d+|e\d+|season|episode|حلقة|موسم', caseSensitive: false);
  static const List<String> _movieExtensions = ['.mp4', '.mkv', '.avi'];

  /// التحليل بنظام التدفق (Streaming) لتوفير الذاكرة
  static Stream<M3UEntry> parseStream(Stream<String> lines) async* {
    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;
    Map<String, String> currentAttributes = {};
    Map<String, String> currentHeaders = {};

    await for (var line in lines) {
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
        }
      } else if (!line.startsWith('#')) {
        if (currentName != null || line.startsWith('http')) {
          final type = _detectType(currentName ?? '', currentGroup ?? '', line);
          yield M3UEntry(
            name: currentName ?? 'Unknown',
            url: line,
            logo: currentLogo,
            group: currentGroup ?? 'Uncategorized',
            type: type,
            epgId: currentEpgId,
            attributes: currentAttributes,
            headers: Map.from(currentHeaders),
          );
        }
        // Reset
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentAttributes = {};
        currentHeaders = {};
      }
    }
  }

  static String _detectType(String name, String group, String url) {
    final n = name.toLowerCase();
    final g = group.toLowerCase();
    final u = url.toLowerCase();

    if (_liveKeywords.any((kw) => n.contains(kw) || g.contains(kw))) return 'live';
    if (_seriesRegex.hasMatch(n) || g.contains('series')) return 'series';
    if (_movieExtensions.any((ext) => u.contains(ext)) || g.contains('movie')) return 'movie';
    return 'live';
  }

  static Map<String, String> _parseAttributes(String line) {
    final Map<String, String> attrs = {};
    final matches = _attrRegExp.allMatches(line);
    for (final m in matches) {
      final key = m.group(1)!;
      final value = m.group(2) ?? m.group(3) ?? m.group(4);
      if (value != null) attrs[key] = value.trim();
    }
    return attrs;
  }
}
