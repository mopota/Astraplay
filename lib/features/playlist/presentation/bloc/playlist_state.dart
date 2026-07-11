part of 'playlist_bloc.dart';

class PlaylistState extends Equatable {
  final List<PlaylistEntity> playlists;
  final bool isLoading;
  final String? error;
  final bool operationSuccess;
  final double progress;
  final String? statusMessage;

  const PlaylistState({
    this.playlists = const [],
    this.isLoading = false,
    this.error,
    this.operationSuccess = false,
    this.progress = 0,
    this.statusMessage,
  });

  PlaylistState copyWith({
    List<PlaylistEntity>? playlists,
    bool? isLoading,
    String? error,
    bool? operationSuccess,
    double? progress,
    String? statusMessage,
  }) {
    return PlaylistState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      operationSuccess: operationSuccess ?? false,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  @override
  List<Object?> get props => [playlists, isLoading, error, operationSuccess, progress, statusMessage];
}
