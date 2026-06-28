import 'package:equatable/equatable.dart';

class PlaylistEntity extends Equatable {
  final int id;
  final String name;
  final String type;
  final String? url;
  final DateTime? lastRefresh;
  final int channelCount;
  final int movieCount;
  final int seriesCount;

  const PlaylistEntity({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.lastRefresh,
    this.channelCount = 0,
    this.movieCount = 0,
    this.seriesCount = 0,
  });

  @override
  List<Object?> get props => [id, name, type, url, lastRefresh, channelCount, movieCount, seriesCount];
}
