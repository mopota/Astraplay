import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/database/app_database.dart';

abstract class StreamRepository {
  Future<Either<Failure, List<AppStream>>> getStreams(int playlistId, String category, StreamType type);
  Future<Either<Failure, Unit>> toggleFavorite(int streamId);
  Future<Either<Failure, bool>> isFavorite(int streamId);
  Future<Either<Failure, Unit>> addToHistory(int streamId, int position);
}
