import 'package:dio/dio.dart';

abstract class StalkerRemoteDataSource {
  Future<String> handshake(String url, String mac);
  Future<List<dynamic>> getCategories(String token);
  Future<List<dynamic>> getStreams(String token, String categoryId);
}

class StalkerRemoteDataSourceImpl implements StalkerRemoteDataSource {
  final Dio dio;

  StalkerRemoteDataSourceImpl({required this.dio});

  @override
  Future<String> handshake(String url, String mac) async {
    // Implement Stalker portal handshake (action=handshake)
    return "token";
  }

  @override
  Future<List<dynamic>> getCategories(String token) async {
    // Implement action=get_categories
    return [];
  }

  @override
  Future<List<dynamic>> getStreams(String token, String categoryId) async {
    // Implement action=get_ordered_list
    return [];
  }
}
