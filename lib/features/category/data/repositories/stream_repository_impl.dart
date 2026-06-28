import 'package:dartz/dartz.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/stream_repository.dart';

class StreamRepositoryImpl implements StreamRepository {
  final AppDatabase database;

  StreamRepositoryImpl({required this.database});

  @override
  Future<Either<Failure, List<AppStream>>> getStreams(int playlistId, String category, StreamType type) async {
    try {
      final streams = await database.getStreamsByCategory(playlistId, category, type);
      return Right(streams);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleFavorite(int streamId) async {
    try {
      await database.toggleFavorite(streamId);
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
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
  Future<Either<Failure, Unit>> addToHistory(int streamId, int position) async {
    try {
      await database.isar.writeTxn(() async {
        var record = await database.isar.historyRecords.filter().streamIdEqualTo(streamId).findFirst();
        
        record ??= HistoryRecord()..streamId = streamId;
        
        record.lastPosition = position;
        record.lastWatched = DateTime.now();
        
        await database.isar.historyRecords.put(record);
      });
      return const Right(unit);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
