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
class HistoryRecord {
  Id id = Isar.autoIncrement;

  late int streamId;
  int playlistId = 0;

  String? episodeMetadata; // JSON for Xtream episode info (url, title, etc)

  int lastPosition = 0;
  int totalDuration = 0;
  DateTime lastWatched = DateTime.now();
}

@Collection()
class AppSettings {
  Id id = Isar.autoIncrement;

  int? activePlaylistId;
  String themeMode = 'system';
  bool useNativePlayer = true;
  String language = 'en';
  bool hardwareAcceleration = true;
  int bufferMs = 5000;
  String? pinCode;
  bool biometricsEnabled = false;
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
        HistoryRecordSchema,
        AppSettingsSchema,
        SearchHistorySchema,
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

  Future<void> toggleFavorite(int streamId) async {
    final stream = await isar.appStreams.get(streamId);
    if (stream != null) {
      stream.isFavorite = !stream.isFavorite;
      await isar.writeTxn(() => isar.appStreams.put(stream));
    }
  }

  Future<List<AppStream>> getFavorites() {
    return isar.appStreams.filter().isFavoriteEqualTo(true).findAll();
  }

  Future<void> addToHistory(int streamId, {int position = 0, int duration = 0, String? episodeMetadata}) async {
    await isar.writeTxn(() async {
      final stream = await isar.appStreams.get(streamId);
      final pId = stream?.playlistId ?? 0;
      
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
}
