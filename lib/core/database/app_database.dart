import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

enum PlaylistType {
  m3uUrl,
  m3uFile,
  xtream,
  directStream,
}

enum StreamType {
  live,
  movie,
  series,
}

@Collection()
class StreamCategory {
  Id id = Isar.autoIncrement;

  @Index()
  int playlistId = 0;

  @Index()
  late String name;

  @Index()
  late String categoryId; // ID from provider (Xtream)

  @Enumerated(EnumType.name)
  late StreamType streamType;

  int count = 0;
}

@Collection()
class Playlist {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  @Enumerated(EnumType.name)
  late PlaylistType type;

  late PlaylistInfo info;

  DateTime? lastRefresh;
}

@Embedded()
class PlaylistInfo {
  String? url;
  String? filePath;
  String? serverUrl;
  String? username;
  String? password;
  int channelCount = 0;
  int movieCount = 0;
  int seriesCount = 0;
}

@Collection()
class AppStream {
  Id id = Isar.autoIncrement;

  @Index()
  int playlistId = 0;

  @Index()
  late String categoryName;

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  @Enumerated(EnumType.name)
  late StreamType streamType;
  
  late StreamData data;

  @Index()
  bool isFavorite = false;

  @Index()
  int? favoriteFolderId;
}

@Embedded()
class StreamData {
  late String streamUrl;
  String? logoUrl;
  String? xtreamId;
  String? metadata; // JSON metadata
  String? headersJson; // Headers as JSON string
}

@Collection()
class FavoriteFolder {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  late String iconName;
}

@Collection()
class EpgProgram {
  Id id = Isar.autoIncrement;

  @Index()
  late String channelId;

  @Index()
  late String title;

  String? description;

  @Index()
  late DateTime startTime;

  @Index()
  late DateTime endTime;

  @Index()
  int playlistId = 0;
}

@Collection()
class HistoryRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late int streamId;
  
  @Index()
  int playlistId = 0;

  String? episodeMetadata; // JSON for Xtream episode info (url, title, etc)

  int lastPosition = 0;
  int totalDuration = 0;
  
  @Index()
  DateTime lastWatched = DateTime.now();
}

@Collection()
class AppSettings {
  Id id = Isar.autoIncrement;

  int? activePlaylistId;
  String themeMode = 'system';
  bool useNativePlayer = true;
  String language = 'ar'; // Default to Arabic as requested
  bool hardwareAcceleration = true;
  int bufferMs = 5000;
  String? pinCode;
  bool biometricsEnabled = false;
  bool autoRefreshPlaylists = false;
}

@Collection()
class SearchHistory {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String query;

  DateTime timestamp = DateTime.now();
}

class AppDatabase {
  late Isar isar;

  Future<void> init() async {
    if (Isar.instanceNames.isNotEmpty) {
      isar = Isar.getInstance()!;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        PlaylistSchema,
        AppStreamSchema,
        StreamCategorySchema,
        HistoryRecordSchema,
        AppSettingsSchema,
        SearchHistorySchema,
        FavoriteFolderSchema,
        EpgProgramSchema,
      ],
      directory: dir.path,
      inspector: false,
    );
  }

  // Helper methods
  Future<List<Playlist>> getAllPlaylists() => isar.playlists.where().findAll();

  Future<void> savePlaylist(Playlist playlist) async {
    await isar.writeTxn(() => isar.playlists.put(playlist));
  }

  Future<void> deletePlaylist(int id) async {
    await isar.writeTxn(() async {
      // Get all stream IDs for this playlist to delete their history
      final streamIds = await isar.appStreams
          .filter()
          .playlistIdEqualTo(id)
          .idProperty()
          .findAll();

      if (streamIds.isNotEmpty) {
        await isar.historyRecords
            .filter()
            .anyOf(streamIds, (q, int sid) => q.streamIdEqualTo(sid))
            .deleteAll();
      }

      await isar.playlists.delete(id);
      await isar.appStreams.filter().playlistIdEqualTo(id).deleteAll();
      await isar.streamCategorys.filter().playlistIdEqualTo(id).deleteAll();
      await isar.epgPrograms.filter().playlistIdEqualTo(id).deleteAll();
    });
  }

  Future<void> saveEpgPrograms(List<EpgProgram> programs) async {
    await isar.writeTxn(() async {
      await isar.epgPrograms.putAll(programs);
    });
  }

  Future<List<AppStream>> getStreamsByCategory(
      int playlistId, String category, StreamType type) {
    return isar.appStreams
        .filter()
        .playlistIdEqualTo(playlistId)
        .categoryNameEqualTo(category)
        .streamTypeEqualTo(type)
        .findAll();
  }

  Future<List<AppStream>> getFavoritesByPlaylist(int pId) {
    return isar.appStreams.filter().playlistIdEqualTo(pId).isFavoriteEqualTo(true).findAll();
  }

  Future<List<HistoryRecord>> getHistoryByPlaylist(int pId) {
    return isar.historyRecords
        .filter()
        .playlistIdEqualTo(pId)
        .sortByLastWatchedDesc()
        .findAll();
  }

  Future<List<String>> getCategoryNames(int pId, StreamType type) {
    return isar.appStreams
        .filter()
        .playlistIdEqualTo(pId)
        .streamTypeEqualTo(type)
        .categoryNameProperty()
        .findAll();
  }

  Future<AppStream> _ensureStreamInDb(AppStream stream) async {
    if (stream.id != 0) {
      final existing = await isar.appStreams.get(stream.id);
      if (existing != null) return existing;
    }
    
    // If not found by ID, try finding by xtreamId if applicable
    if (stream.data.xtreamId != null) {
      final existing = await isar.appStreams.filter()
          .playlistIdEqualTo(stream.playlistId)
          .data((q) => q.xtreamIdEqualTo(stream.data.xtreamId))
          .findFirst();
      if (existing != null) return existing;
    } else {
      // Try by name and category (for M3U if somehow not found by ID)
      final existing = await isar.appStreams.filter()
          .playlistIdEqualTo(stream.playlistId)
          .nameEqualTo(stream.name)
          .categoryNameEqualTo(stream.categoryName)
          .findFirst();
      if (existing != null) return existing;
    }

    // Save it if not found
    final id = await isar.appStreams.put(stream);
    stream.id = id;
    return stream;
  }

  Future<AppStream> toggleFavorite(AppStream stream) async {
    return await isar.writeTxn(() async {
      final dbStream = await _ensureStreamInDb(stream);
      dbStream.isFavorite = !dbStream.isFavorite;
      await isar.appStreams.put(dbStream);
      return dbStream;
    });
  }

  Future<List<AppStream>> getFavorites() {
    return isar.appStreams.filter().isFavoriteEqualTo(true).findAll();
  }

  Future<void> addToHistory(AppStream stream, {int position = 0, int duration = 0, String? episodeMetadata}) async {
    await isar.writeTxn(() async {
      final dbStream = await _ensureStreamInDb(stream);
      final streamId = dbStream.id;
      final pId = dbStream.playlistId;
      
      final query = isar.historyRecords.filter().streamIdEqualTo(streamId);
      final existing = episodeMetadata != null 
          ? await query.episodeMetadataEqualTo(episodeMetadata).findFirst()
          : await query.findFirst();

      if (existing != null) {
        existing.lastWatched = DateTime.now();
        existing.playlistId = pId;
        if (position > 0) existing.lastPosition = position;
        if (duration > 0) existing.totalDuration = duration;
        await isar.historyRecords.put(existing);
      } else {
        final record = HistoryRecord()
          ..streamId = streamId
          ..playlistId = pId
          ..episodeMetadata = episodeMetadata
          ..lastPosition = position
          ..totalDuration = duration
          ..lastWatched = DateTime.now();
        await isar.historyRecords.put(record);
      }
    });
  }

  Future<int> getLastPosition(int streamId, {String? episodeMetadata}) async {
    final query = isar.historyRecords.filter().streamIdEqualTo(streamId);
    final record = episodeMetadata != null 
        ? await query.episodeMetadataEqualTo(episodeMetadata).findFirst()
        : await query.findFirst();
    return record?.lastPosition ?? 0;
  }

  // EPG methods
  Future<EpgProgram?> getCurrentProgram(int pId, String channelId) async {
    final now = DateTime.now();
    return await isar.epgPrograms
        .filter()
        .playlistIdEqualTo(pId)
        .channelIdEqualTo(channelId)
        .startTimeLessThan(now)
        .endTimeGreaterThan(now)
        .findFirst();
  }
}
