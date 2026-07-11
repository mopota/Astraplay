import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart' hide ProgressCallback;
import 'package:flutter/foundation.dart';
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
    if (!existingNames.contains(name)) return name;
    int counter = 1;
    String newName = '$name$counter';
    while (existingNames.contains(newName)) {
      counter++;
      newName = '$name$counter';
    }
    return newName;
  }

  String _fixUrl(String url) {
    final String trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'http://$trimmed';
    }
    return trimmed;
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
      await database.isar.writeTxn(() => database.isar.playlists.put(playlist));
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> validateStreamUrl(String url) async {
    try {
      final response = await dio.get(_fixUrl(url),
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Range': 'bytes=0-1024'},
            validateStatus: (status) => status != null && status < 400,
          ));
      return Right(response.statusCode != null);
    } catch (e) {
      return Left(ServerFailure('Stream unreachable: $e'));
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
        username: p.info.username,
        password: p.info.password,
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
  Future<Either<Failure, Unit>> addM3uPlaylist(String name, String url, {ProgressCallback? onProgress}) async {
    try {
      final normalizedUrl = _fixUrl(url);
      final uniqueName = await _getUniqueName(name);
      final xtreamData = _extractXtreamFromUrl(normalizedUrl);
      
      final playlist = db.Playlist()
        ..name = uniqueName
        ..type = db.PlaylistType.m3uUrl;

      if (xtreamData != null) {
        playlist.info = db.PlaylistInfo()
          ..url = normalizedUrl
          ..serverUrl = _fixUrl(xtreamData['server']!)
          ..username = xtreamData['user']
          ..password = xtreamData['password'] ?? xtreamData['pass'];
        await database.isar.writeTxn(() => database.isar.playlists.put(playlist));
        await _syncXtreamData(playlist, onProgress: onProgress);
      } else {
        playlist.info = db.PlaylistInfo()..url = normalizedUrl;
        onProgress?.call(0.1, 'Fetching content...');
        final content = await remoteDataSource.fetchM3uContent(normalizedUrl);
        await _syncM3uData(playlist, content, onProgress: onProgress);
      }
      return const Right(unit);
    } catch (e) {
      return Left(e is Failure ? e : ServerFailure(e.toString()));
    }
  }

  Map<String, String>? _extractXtreamFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final user = uri.queryParameters['username'] ?? uri.queryParameters['user'];
      final pass = uri.queryParameters['password'] ?? uri.queryParameters['pass'];
      if (user != null && pass != null) {
        return {
          'server': '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}',
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
    ProgressCallback? onProgress,
  }) async {
    try {
      final playlist = db.Playlist()
        ..name = await _getUniqueName(name)
        ..type = db.PlaylistType.xtream
        ..info = (db.PlaylistInfo()
          ..serverUrl = _fixUrl(url)
          ..username = username
          ..password = password);
      await database.isar.writeTxn(() => database.isar.playlists.put(playlist));
      await _syncXtreamData(playlist, onProgress: onProgress);
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<void> _syncXtreamData(db.Playlist playlist, {ProgressCallback? onProgress}) async {
    final url = playlist.info.serverUrl!;
    final user = playlist.info.username!;
    final pass = playlist.info.password!;
    final sw = Stopwatch()..start();

    try {
      onProgress?.call(0.05, 'Connecting to server...');
      
      final fetchResults = await Future.wait([
        remoteDataSource.getXtreamData(url, user, pass, 'get_live_categories'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_vod_categories'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_series_categories'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_live_streams'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_vod_streams'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_series'),
      ]);

      onProgress?.call(0.3, 'Processing categories...');

      final liveCats = fetchResults[0];
      final movieCats = fetchResults[1];
      final seriesCats = fetchResults[2];
      final liveStreams = fetchResults[3];
      final movieStreams = fetchResults[4];
      final seriesList = fetchResults[5];

      final List<db.AppStream> incoming = [];
      final List<db.StreamCategory> cats = [];

      void processItems(List items, List categories, db.StreamType type, double baseProgress, double stageWeight) {
        final catMap = {for (var c in categories) c['category_id'].toString(): c['category_name'].toString()};
        for (var c in categories) {
          final cid = c['category_id'].toString();
          final count = items.where((i) => i['category_id'].toString() == cid).length;
          cats.add(db.StreamCategory()..playlistId = playlist.id..name = catMap[cid] ?? 'Unknown'..categoryId = cid..streamType = type..count = count);
        }

        final int total = items.length;
        for (var i = 0; i < total; i++) {
          final item = items[i];
          final id = (item['stream_id'] ?? item['series_id']).toString();
          final cid = item['category_id'].toString();
          final stream = db.AppStream()
            ..playlistId = playlist.id
            ..categoryName = catMap[cid] ?? 'Uncategorized'
            ..name = item['name']?.toString() ?? 'Unknown'
            ..streamType = type
            ..businessKey = 'xtream_${playlist.id}_${type.name}_$id'
            ..data = (db.StreamData()
              ..xtreamId = id
              ..logoUrl = item['stream_icon']?.toString() ?? item['cover']?.toString()
              ..metadata = _mapXtreamMetadata(item));
          
          if (type == db.StreamType.live) {
            stream.data.streamUrl = '$url/live/$user/$pass/$id.ts';
          } else if (type == db.StreamType.movie) {
            stream.data.streamUrl = '$url/movie/$user/$pass/$id.${item['container_extension'] ?? 'mp4'}';
          }
          incoming.add(stream);

          if (i % 100 == 0) {
            final p = baseProgress + (i / total) * stageWeight;
            final typeStr = type == db.StreamType.live ? 'channels' : (type == db.StreamType.movie ? 'movies' : 'series');
            onProgress?.call(p, 'Loading $typeStr ($i/$total)...');
          }
        }
      }

      processItems(liveStreams, liveCats, db.StreamType.live, 0.3, 0.2); // 30% -> 50%
      processItems(movieStreams, movieCats, db.StreamType.movie, 0.5, 0.2); // 50% -> 70%
      processItems(seriesList, seriesCats, db.StreamType.series, 0.7, 0.2); // 70% -> 90%

      onProgress?.call(0.9, 'Saving to database...');
      await _incrementalUpsert(playlist, incoming, cats);
      
      playlist.info.channelCount = liveStreams.length;
      playlist.info.movieCount = movieStreams.length;
      playlist.info.seriesCount = seriesList.length;
      playlist.lastRefresh = DateTime.now();
      await database.isar.writeTxn(() => database.isar.playlists.put(playlist));

      onProgress?.call(1.0, 'Done.');
      debugPrint('[DataPipeline] Sync completed in: ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('Xtream sync error: $e');
      rethrow;
    }
  }

  db.StreamMetadata _mapXtreamMetadata(Map<String, dynamic> item) {
    return db.StreamMetadata()
      ..plot = item['plot']?.toString()
      ..rating = item['rating']?.toString()
      ..year = item['year']?.toString()
      ..director = item['director']?.toString()
      ..cast = item['cast']?.toString()
      ..genre = item['genre']?.toString()
      ..duration = item['duration']?.toString()
      ..releaseDate = item['releaseDate']?.toString()
      ..lastModified = item['last_modified']?.toString()
      ..extension = item['container_extension']?.toString();
  }

  Future<void> _incrementalUpsert(db.Playlist playlist, List<db.AppStream> incoming, List<db.StreamCategory> categories) async {
    await database.isar.writeTxn(() async {
      await database.isar.streamCategorys.filter().playlistIdEqualTo(playlist.id).deleteAll();
      await database.isar.streamCategorys.putAll(categories);

      final existing = await database.isar.appStreams.filter().playlistIdEqualTo(playlist.id).findAll();
      final Map<String, db.AppStream> existingMap = {for (var s in existing) s.businessKey: s};
      
      final List<db.AppStream> toPut = [];
      final Set<int> keptIds = {};

      for (var s in incoming) {
        final match = existingMap[s.businessKey];
        if (match != null) {
          s.id = match.id;
          s.isFavorite = match.isFavorite;
          keptIds.add(match.id);
        }
        toPut.add(s);
      }

      final toDelete = existing.where((e) => !keptIds.contains(e.id)).map((e) => e.id).toList();
      if (toDelete.isNotEmpty) await database.isar.appStreams.deleteAll(toDelete);
      
      const int batchSize = 500;
      for (var i = 0; i < toPut.length; i += batchSize) {
        final end = (i + batchSize < toPut.length) ? i + batchSize : toPut.length;
        await database.isar.appStreams.putAll(toPut.sublist(i, end));
      }
    });
  }

  Future<void> _syncM3uData(db.Playlist playlist, String content, {ProgressCallback? onProgress}) async {
    final sw = Stopwatch()..start();
    final List<db.AppStream> incoming = [];
    final Map<String, int> catCounts = {};

    onProgress?.call(0.2, 'Parsing M3U content...');
    int count = 0;
    await for (final entry in BackgroundParser.parseM3uString(content)) {
      final stream = db.AppStream()
        ..playlistId = playlist.id
        ..categoryName = entry.group ?? 'Uncategorized'
        ..name = entry.name
        ..streamType = entry.type == 'movie' ? db.StreamType.movie : (entry.type == 'series' ? db.StreamType.series : db.StreamType.live)
        ..businessKey = 'm3u_${playlist.id}_${entry.url}'
        ..data = (db.StreamData()
          ..streamUrl = _fixUrl(entry.url)
          ..logoUrl = entry.logo
          ..headersJson = entry.headers.isNotEmpty ? jsonEncode(entry.headers) : null);
      incoming.add(stream);
      catCounts[stream.categoryName] = (catCounts[stream.categoryName] ?? 0) + 1;
      
      count++;
      if (count % 500 == 0) {
        onProgress?.call(0.2 + (count / 20000).clamp(0.0, 0.6), 'Parsing ($count items)...');
      }
    }

    onProgress?.call(0.85, 'Grouping categories...');
    final List<db.StreamCategory> categories = catCounts.entries.map((e) {
      final match = incoming.firstWhere((s) => s.categoryName == e.key);
      return db.StreamCategory()..playlistId = playlist.id..name = e.key..categoryId = e.key..streamType = match.streamType..count = e.value;
    }).toList();

    onProgress?.call(0.9, 'Saving to database...');
    await _incrementalUpsert(playlist, incoming, categories);
    onProgress?.call(1.0, 'Done.');
    
    debugPrint('[DataPipeline] M3U Sync took: ${sw.elapsedMilliseconds}ms');
  }

  @override
  Future<Either<Failure, Unit>> deletePlaylist(int id) async {
    try {
      await database.deletePlaylist(id);
      sl<CategoryRepository>().clearCache();
      sl<StreamRepository>().clearCache();
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> refreshPlaylist(int id, {ProgressCallback? onProgress}) async {
    try {
      final playlist = await database.isar.playlists.get(id);
      if (playlist == null) return const Left(DatabaseFailure('Not found'));
      
      if (playlist.type == db.PlaylistType.xtream) {
        await _syncXtreamData(playlist, onProgress: onProgress);
      } else if (playlist.type == db.PlaylistType.m3uUrl && playlist.info.url != null) {
        final content = await remoteDataSource.fetchM3uContent(playlist.info.url!);
        await _syncM3uData(playlist, content, onProgress: onProgress);
      }
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> validateXtream(String url, String username, String password) async {
    try {
      return Right(await remoteDataSource.loginXtream(_fixUrl(url), username, password));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updatePlaylist({required int id, required String name, String? url, String? username, String? password}) async {
    return const Right(unit); 
  }

  @override
  Future<Either<Failure, Unit>> fetchEpg(int playlistId, String streamId) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> addM3uFilePlaylist(String name, String filePath, {ProgressCallback? onProgress}) async {
    final playlist = db.Playlist()..name = name..type = db.PlaylistType.m3uFile..info = (db.PlaylistInfo()..filePath = filePath);
    await database.isar.writeTxn(() => database.isar.playlists.put(playlist));
    final content = await File(filePath).readAsString();
    await _syncM3uData(playlist, content, onProgress: onProgress);
    return const Right(unit);
  }
}
