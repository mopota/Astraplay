import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';

abstract class PlaylistRemoteDataSource {
  Future<List<dynamic>> getXtreamData(String url, String username, String password, String action);
  Future<String> fetchM3uContent(String url);
  Future<Map<String, dynamic>> loginXtream(String url, String username, String password);
}

class PlaylistRemoteDataSourceImpl implements PlaylistRemoteDataSource {
  final Dio dio;

  PlaylistRemoteDataSourceImpl({required this.dio}) {
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.options.sendTimeout = const Duration(seconds: 10);
  }

  String _handleError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout) return 'Connection timeout';
      if (e.type == DioExceptionType.receiveTimeout) return 'Server taking too long to respond';
      if (e.type == DioExceptionType.connectionError) return 'Server connection failed. Check URL/Network';
      if (e.response?.statusCode == 401) return 'Unauthorized: Invalid username/password';
      if (e.response?.statusCode == 404) return 'Server API not found (404)';
      return e.message ?? 'Network error occurred';
    }
    return e.toString();
  }

  @override
  Future<String> fetchM3uContent(String url) async {
    try {
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        return response.data.toString();
      } else {
        throw ServerFailure('Failed to fetch M3U (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (e is ServerFailure) rethrow;
      throw ServerFailure(_handleError(e));
    }
  }

  @override
  Future<Map<String, dynamic>> loginXtream(String url, String username, String password) async {
    try {
      final response = await dio.get('$url/player_api.php', queryParameters: {
        'username': username,
        'password': password,
      });
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw const ServerFailure('Invalid response format from Xtream API');
        }
      } else {
        throw ServerFailure('Xtream login failed (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (e is ServerFailure) rethrow;
      throw ServerFailure(_handleError(e));
    }
  }

  @override
  Future<List<dynamic>> getXtreamData(String url, String username, String password, String action) async {
    try {
      final response = await dio.get('$url/player_api.php', queryParameters: {
        'username': username,
        'password': password,
        'action': action,
      });
      if (response.statusCode == 200) {
        if (response.data is List) {
          return response.data;
        }
        return [];
      } else {
        throw ServerFailure('Failed to fetch $action (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (e is ServerFailure) rethrow;
      throw ServerFailure(_handleError(e));
    }
  }
}
