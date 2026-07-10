import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/database/app_database.dart';

abstract class StreamRepository {
  Stream<Either<Failure, List<AppStream>>> getStreams(int playlistId, String category, StreamType type);
  Future<Either<Failure, AppStream>> toggleFavorite(AppStream stream);
  Future<Either<Failure, bool>> isFavorite(int streamId);
  Future<Either<Failure, Unit>> addToHistory(AppStream stream, {int position, int duration, String? episodeMetadata});
  void clearCache();
}
