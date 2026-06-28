part of 'playlist_bloc.dart';

class PlaylistState extends Equatable {
  final List<PlaylistEntity> playlists;
  final bool isLoading;
  final String? error;
  final bool operationSuccess;

  const PlaylistState({
    this.playlists = const [],
    this.isLoading = false,
    this.error,
    this.operationSuccess = false,
  });

  PlaylistState copyWith({
    List<PlaylistEntity>? playlists,
    bool? isLoading,
    String? error,
    bool? operationSuccess,
  }) {
    return PlaylistState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      operationSuccess: operationSuccess ?? false,
    );
  }

  @override
  List<Object?> get props => [playlists, isLoading, error, operationSuccess];
}
