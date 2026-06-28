import 'package:flutter/foundation.dart';
import 'm3u_parser.dart';

class BackgroundParser {
  static Future<List<M3UEntry>> parseM3u(String content) async {
    return await compute(_parseM3uIsolate, content);
  }

  static List<M3UEntry> _parseM3uIsolate(String content) {
    return M3UParser.parse(content);
  }
}
