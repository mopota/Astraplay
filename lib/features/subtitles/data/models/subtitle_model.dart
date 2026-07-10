import 'package:equatable/equatable.dart';

class SubtitleSearchResult extends Equatable {
  final String id;
  final String fileName;
  final String language;
  final String? release;
  final double rating;
  final int downloadCount;
  final String downloadUrl;

  const SubtitleSearchResult({
    required this.id,
    required this.fileName,
    required this.language,
    this.release,
    required this.rating,
    required this.downloadCount,
    required this.downloadUrl,
  });

  factory SubtitleSearchResult.fromOpenSubtitles(Map<String, dynamic> json) {
    final attributes = json['attributes'];
    final files = attributes['files'] as List;
    final firstFile = files.first;

    return SubtitleSearchResult(
      id: json['id'],
      fileName: attributes['release'] ?? attributes['feature_details']['title'] ?? 'Unknown',
      language: attributes['language'],
      release: attributes['release'],
      rating: (attributes['ratings'] as num).toDouble(),
      downloadCount: attributes['download_count'] as int,
      downloadUrl: firstFile['file_id'].toString(), // We might need to call another API to get the actual link
    );
  }

  @override
  List<Object?> get props => [id, fileName, language, release, rating, downloadCount, downloadUrl];
}
