import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/subtitle_model.dart';

class SubtitleService {
  // TODO: Move to a secure backend or environment variable in Production
  static const String _apiKey = 'rjnnL8CsmJk1u1oP6JIpLdHl1o0xYJgm';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.opensubtitles.com/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Api-Key': _apiKey,
      'User-Agent': 'Astra',
      'Accept': 'application/json',
    },
  ));

  Future<List<SubtitleSearchResult>> searchSubtitles({
    String? query,
    String? languages,
    String? imdbId,
    String? movieHash,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (query != null) params['query'] = query;
      if (languages != null) params['languages'] = languages;
      if (imdbId != null) params['imdb_id'] = imdbId;
      if (movieHash != null) params['moviehash'] = movieHash;

      final response = await _dio.get('/subtitles', queryParameters: params);
      
      if (response.statusCode == 200) {
        final List data = response.data['data'];
        return data.map((item) => SubtitleSearchResult.fromOpenSubtitles(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<String?> downloadSubtitle(SubtitleSearchResult sub) async {
    int retryCount = 0;
    const int maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        // 1. Get download link
        final response = await _dio.post('/download', data: {
          'file_id': int.tryParse(sub.downloadUrl) ?? 0,
        });

        if (response.statusCode == 200) {
          final downloadUrl = response.data['link'];
          
          // 2. Download the file
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/${sub.id}.srt';
          
          await _dio.download(downloadUrl, filePath);
          return filePath;
        }
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 503) {
          retryCount++;
          if (retryCount <= maxRetries) {
            // Wait for 2 seconds before retrying 503 errors
            await Future.delayed(Duration(seconds: 2 * retryCount));
            continue;
          }
          throw Exception('OpenSubtitles is currently overloaded (503). Please try again in a few moments.');
        }
        rethrow;
      }
      break;
    }
    return null;
  }
}
