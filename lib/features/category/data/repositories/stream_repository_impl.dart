import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
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
    final stopwatch = Stopwatch()..start();
    final cacheKey = '${playlistId}_${category}_${type.name}';
    
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[Profiling] getStreams Cache Hit: ${stopwatch.elapsedMilliseconds}ms');
      yield Right(_cache[cacheKey]!);
    }

    try {
      final playlist = await database.isar.playlists.get(playlistId);
      if (playlist == null) {
        yield const Left(DatabaseFailure('Playlist not found'));
        return;
      }
      debugPrint('[Profiling] getStreams Playlist Fetch: ${stopwatch.elapsedMilliseconds}ms');

      final List<AppStream> streams = await database.getStreamsByCategory(playlistId, category, type);
      debugPrint('[Profiling] getStreams DB Fetch (${streams.length} items): ${stopwatch.elapsedMilliseconds}ms');

      _cache[cacheKey] = streams;
      yield Right(streams);
      debugPrint('[Profiling] getStreams Total: ${stopwatch.elapsedMilliseconds}ms');
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
