import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/stream_repository.dart';
import '../../../../features/playlist/data/datasources/playlist_remote_data_source.dart';

class StreamRepositoryImpl implements StreamRepository {
  final AppDatabase database;
  final PlaylistRemoteDataSource remoteDataSource;
  
  // Professional In-Memory Cache (Prevents DB growth)
  final Map<String, List<AppStream>> _cache = {};

  StreamRepositoryImpl({
    required this.database,
    required this.remoteDataSource,
  });

  @override
  Stream<Either<Failure, List<AppStream>>> getStreams(int playlistId, String category, StreamType type) async* {
    final cacheKey = '${playlistId}_${category}_${type.name}';
    
    // 1. Send from Memory Cache first if available (Instant)
    if (_cache.containsKey(cacheKey)) {
      yield Right(_cache[cacheKey]!);
    }

    try {
      final playlist = await database.isar.playlists.get(playlistId);
      if (playlist == null) {
        yield Left(DatabaseFailure('Playlist not found'));
        return;
      }

      List<AppStream> streams = [];

      if (playlist.type == PlaylistType.xtream) {
        // 2. FETCH FROM SERVER & EMIT IN CHUNKS
        final url = playlist.info.serverUrl ?? '';
        final user = playlist.info.username ?? '';
        final pass = playlist.info.password ?? '';
        
        // Find category ID
        final cat = await database.isar.streamCategorys
            .filter()
            .playlistIdEqualTo(playlist.id)
            .nameEqualTo(category)
            .streamTypeEqualTo(type)
            .findFirst();
        
        if (cat == null) {
          yield const Right([]);
          return;
        }

        String action = type == StreamType.live ? 'get_live_streams' : (type == StreamType.movie ? 'get_vod_streams' : 'get_series');
        final rawData = await remoteDataSource.getXtreamData(url, user, pass, action);
        
        // Fetch all saved streams for this playlist and type (favorites and history items)
        final savedStreams = await database.isar.appStreams
            .filter()
            .playlistIdEqualTo(playlistId)
            .streamTypeEqualTo(type)
            .findAll();
        final savedStreamsMap = {for (var s in savedStreams) s.data.xtreamId: s};

        int processedCount = 0;
        for (var s in rawData) {
          if (s['category_id']?.toString() == cat.categoryId) {
            final xtreamId = s['stream_id']?.toString() ?? s['series_id']?.toString();
            final stream = AppStream()
              ..playlistId = playlist.id
              ..categoryName = category
              ..name = s['name']?.toString() ?? 'Unknown'
              ..streamType = type
              ..data = (StreamData()
                ..logoUrl = s['stream_icon']?.toString() ?? s['cover']?.toString()
                ..xtreamId = xtreamId);
                
            if (type == StreamType.live) stream.data.streamUrl = '$url/live/$user/$pass/${s['stream_id']}.ts';
            else if (type == StreamType.movie) {
              stream.data.streamUrl = '$url/movie/$user/$pass/${s['stream_id']}.${s['container_extension'] ?? 'mp4'}';
              stream.data.metadata = jsonEncode(s);
            } else stream.data.metadata = jsonEncode(s);

            if (savedStreamsMap.containsKey(xtreamId)) {
              final saved = savedStreamsMap[xtreamId]!;
              stream.isFavorite = saved.isFavorite;
              stream.id = saved.id;
            }

            streams.add(stream);
            processedCount++;

            // Yield first 20 items immediately for instant UI
            if (processedCount == 20) {
              yield Right(List.from(streams));
            }
          }
        }
      } else {
        streams = await database.getStreamsByCategory(playlistId, category, type);
      }

      _cache[cacheKey] = streams;
      yield Right(streams);
    } catch (e) {
      yield Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppStream>> toggleFavorite(AppStream stream) async {
    try {
      final updated = await database.toggleFavorite(stream);
      // Update cache if necessary
      _updateStreamInCache(updated);
      return Right(updated);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  void _updateStreamInCache(AppStream updated) {
    _cache.forEach((key, list) {
      for (var i = 0; i < list.length; i++) {
        final s = list[i];
        if (updated.data.xtreamId != null && s.data.xtreamId == updated.data.xtreamId) {
          list[i] = updated;
        } else if (s.id == updated.id && updated.id != 0) {
          list[i] = updated;
        }
      }
    });
  }

  @override
  Future<Either<Failure, bool>> isFavorite(int streamId) async {
    try {
      final stream = await database.isar.appStreams.get(streamId);
      return Right(stream?.isFavorite ?? false);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> addToHistory(AppStream stream, {int position = 0, int duration = 0, String? episodeMetadata}) async {
    try {
      await database.addToHistory(stream, position: position, duration: duration, episodeMetadata: episodeMetadata);
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  void clearCache() {
    _cache.clear();
  }
}
