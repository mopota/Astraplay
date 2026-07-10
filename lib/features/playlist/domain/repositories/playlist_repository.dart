import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/playlist.entity.dart';

abstract class PlaylistRepository {
  Future<Either<Failure, List<PlaylistEntity>>> getPlaylists();
  Future<Either<Failure, Unit>> deletePlaylist(int id);
  Future<Either<Failure, Unit>> refreshPlaylist(int id);
  Future<Either<Failure, Unit>> updatePlaylist({
    required int id,
    required String name,
    String? url,
    String? username,
    String? password,
  });
  Future<Either<Failure, Unit>> fetchEpg(int playlistId, String streamId);

  // Direct Stream
  Future<Either<Failure, Unit>> addDirectStream(String name, String url);
  Future<Either<Failure, bool>> validateStreamUrl(String url);

  // M3U Playlist
  Future<Either<Failure, Unit>> addM3uPlaylist(String name, String url);
  
  // Xtream
  Future<Either<Failure, Unit>> addXtreamPlaylist({
    required String name,
    required String url,
    required String username,
    required String password,
  });
  Future<Either<Failure, Map<String, dynamic>>> validateXtream(String url, String username, String password);

  // Local File
  Future<Either<Failure, Unit>> addM3uFilePlaylist(String name, String filePath);
}
