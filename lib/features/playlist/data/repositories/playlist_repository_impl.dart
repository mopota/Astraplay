import 'dart:io';
import 'dart:convert';
import 'dart:async';
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
    String trimmed = url.trim();
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

    try {
      // 1. Fetch Categories and Stream Lists to get counts
      final results = await Future.wait([
        remoteDataSource.getXtreamData(url, user, pass, 'get_live_categories'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_vod_categories'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_series_categories'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_live_streams'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_vod_streams'),
        remoteDataSource.getXtreamData(url, user, pass, 'get_series'),
      ]);

      final liveCats = results[0];
      final movieCats = results[1];
      final seriesCats = results[2];
      final liveStreams = results[3];
      final movieStreams = results[4];
      final seriesList = results[5];

      // 2. Prepare Categories with Counts (But DON'T save all streams yet)
      final List<db.StreamCategory> allCategories = [];
      
      void processCats(List<dynamic> cats, db.StreamType type, List<dynamic> streams) {
        for (var c in cats) {
          final cid = c['category_id']?.toString() ?? '0';
          final count = streams.where((s) => s['category_id']?.toString() == cid).length;
          
          allCategories.add(db.StreamCategory()
            ..playlistId = playlist.id
            ..name = c['category_name']?.toString() ?? 'Unknown'
            ..categoryId = cid
            ..streamType = type
            ..count = count);
        }
      }

      processCats(liveCats, db.StreamType.live, liveStreams);
      processCats(movieCats, db.StreamType.movie, movieStreams);
      processCats(seriesCats, db.StreamType.series, seriesList);

      // 3. Save Metadata Only (This keeps the app size tiny)
      await database.isar.writeTxn(() async {
        // Clear old categories
        await database.isar.streamCategorys.filter().playlistIdEqualTo(playlist.id).deleteAll();
        // Clear cached streams for this playlist (to force refresh metadata if needed)
        await database.isar.appStreams.filter().playlistIdEqualTo(playlist.id).deleteAll();
        
        await database.isar.streamCategorys.putAll(allCategories);
        
        playlist.info.channelCount = liveStreams.length;
        playlist.info.movieCount = movieStreams.length;
        playlist.info.seriesCount = seriesList.length;
        playlist.lastRefresh = DateTime.now();
        await database.isar.playlists.put(playlist);
      });

    } catch (e) {
      debugPrint('Xtream metadata sync error: $e');
      rethrow;
    }
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

  @override
  Future<Either<Failure, Unit>> updatePlaylist({
    required int id,
    required String name,
    String? url,
    String? username,
    String? password,
  }) async {
    try {
      final playlist = await database.isar.playlists.get(id);
      if (playlist == null) return const Left(DatabaseFailure('Playlist not found'));

      await database.isar.writeTxn(() async {
        playlist.name = name;
        if (url != null) {
          if (playlist.type == db.PlaylistType.xtream) {
            playlist.info.serverUrl = _fixUrl(url);
          } else {
            playlist.info.url = _fixUrl(url);
          }
        }
        if (username != null) playlist.info.username = username;
        if (password != null) playlist.info.password = password;
        
        await database.isar.playlists.put(playlist);
      });

      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> fetchEpg(int playlistId, String streamId) async {
    try {
      final playlist = await database.isar.playlists.get(playlistId);
      if (playlist == null || playlist.type != db.PlaylistType.xtream) {
        return const Right(unit);
      }

      final data = await remoteDataSource.getXtreamEpg(
        playlist.info.serverUrl!,
        playlist.info.username!,
        playlist.info.password!,
        streamId,
      );

      final epgList = data['epg_listings'] as List?;
      if (epgList != null) {
        final List<db.EpgProgram> programs = [];
        for (var item in epgList) {
          try {
            final start = DateTime.parse(item['start']);
            final end = DateTime.parse(item['end']);
            programs.add(db.EpgProgram()
              ..channelId = streamId
              ..playlistId = playlistId
              ..title = utf8.decode(base64.decode(item['title']))
              ..description = item['description'] != null 
                  ? utf8.decode(base64.decode(item['description'])) 
                  : null
              ..startTime = start
              ..endTime = end);
          } catch (_) {}
        }
        
        if (programs.isNotEmpty) {
          await database.saveEpgPrograms(programs);
        }
      }

      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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
    
    // Get existing streams - use efficient query
    final existingData = await database.isar.appStreams
        .filter()
        .playlistIdEqualTo(playlist.id)
        .findAll();
    
    final Map<String, db.AppStream> urlMap = {};
    final Map<String, db.AppStream> nameCatMap = {};

    for (var s in existingData) {
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
      
      await database.isar.playlists.put(playlist);

      // 2. Delete streams that no longer exist
      final idsToDelete = existingData
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
