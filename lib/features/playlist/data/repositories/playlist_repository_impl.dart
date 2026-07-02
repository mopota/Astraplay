import 'dart:io';
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart' as db;
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/background_parser.dart';
import '../../domain/entities/playlist.entity.dart';
import '../../domain/repositories/playlist_repository.dart';
import 'package:astraplay/features/playlist/data/datasources/playlist_remote_data_source.dart';
import '../../../category/domain/repositories/category_repository.dart';
import '../../../category/domain/repositories/stream_repository.dart';
import '../../../../injection_container.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  final db.AppDatabase database;
  final PlaylistRemoteDataSource remoteDataSource;
  final Dio dio;

  PlaylistRepositoryImpl({
    required this.database,
    required this.remoteDataSource,
    required this.dio,
  });

  Future<String> _getUniqueName(String name) async {
    final playlists = await database.getAllPlaylists();
    final existingNames = playlists.map((p) => p.name).toList();
    
    if (!existingNames.contains(name)) {
      return name;
    }

    int counter = 1;
    String newName = '$name$counter';
    while (existingNames.contains(newName)) {
      counter++;
      newName = '$name$counter';
    }
    return newName;
  }

  String _fixUrl(String url) {
    if (url.startsWith('https://')) {
      return url.replaceFirst('https://', 'http://');
    }
    return url;
  }

  @override
  Future<Either<Failure, Unit>> addDirectStream(String name, String url) async {
    try {
      final uniqueName = await _getUniqueName(name);
      final playlist = db.Playlist()
        ..name = uniqueName
        ..type = db.PlaylistType.directStream
        ..info = (db.PlaylistInfo()..url = _fixUrl(url))
        ..lastRefresh = DateTime.now();

      await database.isar.writeTxn(() async {
        await database.isar.playlists.put(playlist);
      });

      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> validateStreamUrl(String url) async {
    try {
      final response = await dio.get(
        _fixUrl(url),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Range': 'bytes=0-1024'},
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return Right(response.statusCode != null);
    } catch (e) {
      return Left(ServerFailure('Unable to reach stream URL: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PlaylistEntity>>> getPlaylists() async {
    try {
      final playlists = await database.getAllPlaylists();
      return Right(playlists.map((p) => PlaylistEntity(
        id: p.id,
        name: p.name,
        type: p.type.name,
        url: p.info.url ?? p.info.serverUrl,
        lastRefresh: p.lastRefresh,
        channelCount: p.info.channelCount,
        movieCount: p.info.movieCount,
        seriesCount: p.info.seriesCount,
      )).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> addM3uPlaylist(String name, String url) async {
    try {
      final normalizedUrl = _fixUrl(url);
      final uniqueName = await _getUniqueName(name);
      
      // محاولة استخراج بيانات الاكستريم من رابط الـ M3U
      final xtreamData = _extractXtreamFromUrl(normalizedUrl);
      
      if (xtreamData != null) {
        final playlist = db.Playlist()
          ..name = uniqueName
          ..type = db.PlaylistType.m3uUrl
          ..info = (db.PlaylistInfo()
            ..url = normalizedUrl
            ..serverUrl = _fixUrl(xtreamData['server']!)
            ..username = xtreamData['user']
            ..password = xtreamData['password'] ?? xtreamData['pass'])
          ..lastRefresh = DateTime.now();

        await database.isar.writeTxn(() async {
          await database.isar.playlists.put(playlist);
        });
        
        await _syncXtreamData(playlist);
        return const Right(unit);
      }

      final content = await remoteDataSource.fetchM3uContent(normalizedUrl);
      final playlist = db.Playlist()
        ..name = uniqueName
        ..type = db.PlaylistType.m3uUrl
        ..info = (db.PlaylistInfo()..url = normalizedUrl);

      await _syncM3uData(playlist, content);
      return const Right(unit);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(e.toString()));
    }
  }

  Map<String, String>? _extractXtreamFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final user = uri.queryParameters['username'] ?? uri.queryParameters['user'];
      final pass = uri.queryParameters['password'] ?? uri.queryParameters['pass'];
      
      if (user != null && pass != null) {
        final server = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
        return {
          'server': server,
          'user': user,
          'pass': pass,
        };
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<Either<Failure, Unit>> addXtreamPlaylist({
    required String name,
    required String url,
    required String username,
    required String password,
  }) async {
    try {
      final normalizedUrl = _fixUrl(url);
      final uniqueName = await _getUniqueName(name);
      final playlist = db.Playlist()
        ..name = uniqueName
        ..type = db.PlaylistType.xtream
        ..info = (db.PlaylistInfo()
          ..serverUrl = normalizedUrl
          ..username = username
          ..password = password)
        ..lastRefresh = DateTime.now();

      await database.isar.writeTxn(() async {
        await database.isar.playlists.put(playlist);
      });

      // Sync data from Xtream
      await _syncXtreamData(playlist);

      return const Right(unit);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<void> _syncXtreamData(db.Playlist playlist) async {
    final url = playlist.info.serverUrl!;
    final user = playlist.info.username!;
    final pass = playlist.info.password!;

    // Helper to fetch data safely without failing the whole sync
    Future<List<dynamic>> safeFetch(String action) async {
      try {
        return await remoteDataSource.getXtreamData(url, user, pass, action);
      } catch (e) {
        debugPrint('Xtream sync warning ($action): $e');
        return [];
      }
    }

    // Fetch categories and streams for all types in parallel
    final results = await Future.wait([
      safeFetch('get_live_categories'),
      safeFetch('get_live_streams'),
      safeFetch('get_vod_categories'),
      safeFetch('get_vod_streams'),
      safeFetch('get_series_categories'),
      safeFetch('get_series'),
    ]);

    final liveCats = results[0];
    final liveStreams = results[1];
    final movieCats = results[2];
    final movieStreams = results[3];
    final seriesCats = results[4];
    final seriesList = results[5];

    final liveCatMap = <String, String>{};
    for (var c in liveCats) {
      liveCatMap[c['category_id'].toString()] = c['category_name'].toString();
    }
    
    final movieCatMap = <String, String>{};
    for (var c in movieCats) {
      movieCatMap[c['category_id'].toString()] = c['category_name'].toString();
    }
    
    final seriesCatMap = <String, String>{};
    for (var c in seriesCats) {
      seriesCatMap[c['category_id'].toString()] = c['category_name'].toString();
    }

    // Get existing streams to preserve favorites and IDs
    final existingStreams = await database.isar.appStreams
        .filter()
        .playlistIdEqualTo(playlist.id)
        .findAll();
    
    final Map<String, db.AppStream> xtreamIdMap = {};
    final Map<String, db.AppStream> nameCatMap = {};

    for (var s in existingStreams) {
      if (s.data.xtreamId != null) {
        xtreamIdMap[s.data.xtreamId!] = s;
      }
      nameCatMap['${s.name}_${s.categoryName}_${s.streamType.name}'] = s;
    }

    final List<db.AppStream> allStreams = [];
    final Set<int> keptIds = {};

    void processStream(db.AppStream s) {
      db.AppStream? existing;
      
      // Try match by Xtream ID first
      if (s.data.xtreamId != null) {
        existing = xtreamIdMap[s.data.xtreamId!];
      }
      
      // Fallback to Name + Category if URL/ID changed but content is same
      existing ??= nameCatMap['${s.name}_${s.categoryName}_${s.streamType.name}'];

      if (existing != null) {
        s.id = existing.id;
        s.isFavorite = existing.isFavorite;
        keptIds.add(existing.id);
      }
      allStreams.add(s);
    }

    for (var s in liveStreams) {
      processStream(db.AppStream()
        ..playlistId = playlist.id
        ..categoryName = liveCatMap[s['category_id'].toString()] ?? 'Uncategorized'
        ..name = s['name']?.toString() ?? 'Unknown'
        ..streamType = db.StreamType.live
        ..data = (db.StreamData()
          ..streamUrl = _fixUrl('$url/live/$user/$pass/${s['stream_id']}.ts')
          ..logoUrl = s['stream_icon']?.toString()
          ..xtreamId = s['stream_id']?.toString()));
    }

    for (var s in movieStreams) {
      processStream(db.AppStream()
        ..playlistId = playlist.id
        ..categoryName = movieCatMap[s['category_id'].toString()] ?? 'Uncategorized'
        ..name = s['name']?.toString() ?? 'Unknown'
        ..streamType = db.StreamType.movie
        ..data = (db.StreamData()
          ..streamUrl = _fixUrl('$url/movie/$user/$pass/${s['stream_id']}.${s['container_extension'] ?? 'mp4'}')
          ..logoUrl = s['stream_icon']?.toString()
          ..xtreamId = s['stream_id']?.toString()
          ..metadata = jsonEncode(s)));
    }

    for (var s in seriesList) {
      processStream(db.AppStream()
        ..playlistId = playlist.id
        ..categoryName = seriesCatMap[s['category_id'].toString()] ?? 'Uncategorized'
        ..name = s['name']?.toString() ?? 'Unknown'
        ..streamType = db.StreamType.series
        ..data = (db.StreamData()
          ..streamUrl = ''
          ..logoUrl = s['cover']?.toString()
          ..xtreamId = s['series_id']?.toString()
          ..metadata = jsonEncode(s)));
    }

    await database.isar.writeTxn(() async {
      // Delete streams that no longer exist in the new sync
      final idsToDelete = existingStreams
          .map((e) => e.id)
          .where((id) => !keptIds.contains(id))
          .toList();
      
      if (idsToDelete.isNotEmpty) {
        await database.isar.appStreams.deleteAll(idsToDelete);
      }

      await database.isar.appStreams.putAll(allStreams);
      
      playlist.info.channelCount = liveStreams.length;
      playlist.info.movieCount = movieStreams.length;
      playlist.info.seriesCount = seriesList.length;
      playlist.lastRefresh = DateTime.now();
      await database.isar.playlists.put(playlist);
    });
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> validateXtream(String url, String username, String password) async {
    try {
      final data = await remoteDataSource.loginXtream(_fixUrl(url), username, password);
      return Right(data);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deletePlaylist(int id) async {
    try {
      await database.deletePlaylist(id);
      _clearAllCaches();
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  void _clearAllCaches() {
    try {
      sl<CategoryRepository>().clearCache();
      sl<StreamRepository>().clearCache();
    } catch (_) {}
  }

  @override
  Future<Either<Failure, Unit>> refreshPlaylist(int id) async {
    try {
      final playlist = await database.isar.playlists.get(id);
      if (playlist == null) return const Left(DatabaseFailure('Playlist not found'));
      
      _clearAllCaches();
      
      if (playlist.type == db.PlaylistType.m3uUrl) {
        if (playlist.info.username != null && playlist.info.password != null) {
          await _syncXtreamData(playlist);
        } else {
          final content = await remoteDataSource.fetchM3uContent(playlist.info.url!);
          await _syncM3uData(playlist, content);
        }
      } else if (playlist.type == db.PlaylistType.m3uFile) {
        final content = await File(playlist.info.filePath!).readAsString();
        await _syncM3uData(playlist, content);
      } else if (playlist.type == db.PlaylistType.xtream) {
        await _syncXtreamData(playlist);
      }
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<void> _syncM3uData(db.Playlist playlist, String content) async {
    final entries = await BackgroundParser.parseM3u(content);
    
    // Get existing streams to preserve favorites and IDs
    final existingStreams = await database.isar.appStreams
        .filter()
        .playlistIdEqualTo(playlist.id)
        .findAll();
    
    final Map<String, db.AppStream> urlMap = {};
    final Map<String, db.AppStream> nameCatMap = {};

    for (var s in existingStreams) {
      urlMap[s.data.streamUrl] = s;
      nameCatMap['${s.name}_${s.categoryName}_${s.streamType.name}'] = s;
    }

    final Set<int> keptIds = {};
    final streams = entries.map((e) {
      final s = _mapToAppStream(e, playlist.id);
      
      // Match by URL or fallback to Name+Category
      db.AppStream? existing = urlMap[s.data.streamUrl];
      existing ??= nameCatMap['${s.name}_${s.categoryName}_${s.streamType.name}'];

      if (existing != null) {
        s.id = existing.id;
        s.isFavorite = existing.isFavorite;
        keptIds.add(existing.id);
      }
      return s;
    }).toList();

    await database.isar.writeTxn(() async {
      // 1. Save/Update Playlist to get ID and update counts
      playlist.info.channelCount = entries.where((e) => e.type == 'live').length;
      playlist.info.movieCount = entries.where((e) => e.type == 'movie').length;
      playlist.info.seriesCount = entries.where((e) => e.type == 'series').length;
      playlist.lastRefresh = DateTime.now();
      
      final id = await database.isar.playlists.put(playlist);

      // 2. Delete streams that no longer exist
      final idsToDelete = existingStreams
          .map((e) => e.id)
          .where((id) => !keptIds.contains(id))
          .toList();
      
      if (idsToDelete.isNotEmpty) {
        await database.isar.appStreams.deleteAll(idsToDelete);
      }
      
      // 3. Add/Update streams
      await database.isar.appStreams.putAll(streams);
    });
  }

  @override
  Future<Either<Failure, Unit>> addM3uFilePlaylist(String name, String filePath) async {
    try {
      final uniqueName = await _getUniqueName(name);
      final content = await File(filePath).readAsString();
      
      final playlist = db.Playlist()
        ..name = uniqueName
        ..type = db.PlaylistType.m3uFile
        ..info = (db.PlaylistInfo()..filePath = filePath);

      await _syncM3uData(playlist, content);
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  db.AppStream _mapToAppStream(dynamic e, int playlistId) {
    db.StreamType sType;
    if (e.type == 'movie') {
      sType = db.StreamType.movie;
    } else if (e.type == 'series') {
      sType = db.StreamType.series;
    } else {
      sType = db.StreamType.live;
    }
    
    return db.AppStream()
      ..playlistId = playlistId
      ..categoryName = e.group ?? 'Uncategorized'
      ..name = e.name
      ..streamType = sType
      ..data = (db.StreamData()
        ..streamUrl = _fixUrl(e.url)
        ..logoUrl = e.logo
        ..headersJson = e.headers.isNotEmpty ? jsonEncode(e.headers) : null);
  }
}
