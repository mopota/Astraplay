import 'package:dartz/dartz.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/search_repository.dart';
import 'package:isar_community/isar.dart';
import '../../../../features/playlist/data/datasources/playlist_remote_data_source.dart';

class SearchRepositoryImpl implements SearchRepository {
  final AppDatabase database;
  final PlaylistRemoteDataSource remoteDataSource;
  
  // In-Memory Global Search Index (Session based, Zero Space)
  static final Map<int, List<AppStream>> _searchIndexCache = {};

  SearchRepositoryImpl({
    required this.database,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, List<AppStream>>> search(String query, {int? playlistId}) async {
    try {
      if (query.isEmpty) return const Right([]);
      final q = query.toLowerCase();

      // 1. Get current active playlist
      final targetPlaylistId = playlistId;
      if (targetPlaylistId == null) return const Right([]);

      final playlist = await database.isar.playlists.get(targetPlaylistId);
      if (playlist == null) return const Right([]);

      List<AppStream> allStreams = [];

      // 2. Load or Build Search Index for this playlist
      if (playlist.type == PlaylistType.xtream) {
        if (!_searchIndexCache.containsKey(targetPlaylistId)) {
          final fetched = await _buildXtreamSearchIndex(playlist);
          _searchIndexCache[targetPlaylistId] = fetched;
        }
        allStreams = _searchIndexCache[targetPlaylistId]!;
      } else {
        // M3U search still uses DB
        allStreams = await database.isar.appStreams
            .filter()
            .playlistIdEqualTo(targetPlaylistId)
            .findAll();
      }

      // 3. Filter in memory for maximum speed
      final results = allStreams.where((s) {
        return s.name.toLowerCase().contains(q) || 
               s.categoryName.toLowerCase().contains(q);
      }).take(100).toList();

      return Right(results);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<List<AppStream>> _buildXtreamSearchIndex(Playlist playlist) async {
    final url = playlist.info.serverUrl!;
    final user = playlist.info.username!;
    final pass = playlist.info.password!;

    // Fetch categories to map names correctly
    final catsFromDb = await database.isar.streamCategorys
        .filter()
        .playlistIdEqualTo(playlist.id)
        .findAll();
        
    final catMap = {for (var c in catsFromDb) c.categoryId: c.name};

    // Fetch all saved streams for this playlist to link favorites/history
    final savedStreams = await database.isar.appStreams
        .filter()
        .playlistIdEqualTo(playlist.id)
        .findAll();
    final savedStreamsMap = {for (var s in savedStreams) s.data.xtreamId: s};

    // Fetch full lists (Names + IDs only)
    final results = await Future.wait([
      remoteDataSource.getXtreamData(url, user, pass, 'get_live_streams'),
      remoteDataSource.getXtreamData(url, user, pass, 'get_vod_streams'),
      remoteDataSource.getXtreamData(url, user, pass, 'get_series'),
    ]);

    final List<AppStream> index = [];

    void process(List<dynamic> data, StreamType type) {
      for (var s in data) {
        final cid = s['category_id']?.toString() ?? '0';
        final xtreamId = s['stream_id']?.toString() ?? s['series_id']?.toString();
        final stream = AppStream()
          ..playlistId = playlist.id
          ..name = s['name']?.toString() ?? 'Unknown'
          ..categoryName = catMap[cid] ?? 'Uncategorized'
          ..streamType = type
          ..data = (StreamData()
            ..logoUrl = s['stream_icon']?.toString() ?? s['cover']?.toString()
            ..xtreamId = xtreamId);
            
        // Construct basic URL for immediate play from search
        if (type == StreamType.live) {
          stream.data.streamUrl = '$url/live/$user/$pass/${s['stream_id']}.ts';
        } else if (type == StreamType.movie) {
          stream.data.streamUrl = '$url/movie/$user/$pass/${s['stream_id']}.${s['container_extension'] ?? 'mp4'}';
        }

        if (savedStreamsMap.containsKey(xtreamId)) {
          final saved = savedStreamsMap[xtreamId]!;
          stream.isFavorite = saved.isFavorite;
          stream.id = saved.id;
        }
        
        index.add(stream);
      }
    }

    process(results[0], StreamType.live);
    process(results[1], StreamType.movie);
    process(results[2], StreamType.series);

    return index;
  }
}
