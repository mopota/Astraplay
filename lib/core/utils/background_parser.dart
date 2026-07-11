import 'dart:convert';
import 'dart:io';
import 'm3u_parser.dart';

class BackgroundParser {
  /// تحليل ملف M3U من مسار محلي بكفاءة عالية
  static Stream<M3UEntry> parseM3uFile(String filePath) {
    final file = File(filePath);
    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    return M3UParser.parseStream(lines);
  }

  /// تحليل نص M3U (للرابط البعيد) بكفاءة
  static Stream<M3UEntry> parseM3uString(String content) {
    final lines = Stream.fromIterable(const LineSplitter().convert(content));
    return M3UParser.parseStream(lines);
  }
}
