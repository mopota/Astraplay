import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/playlist.entity.dart';
import '../../domain/repositories/playlist_repository.dart';

part 'playlist_event.dart';
part 'playlist_state.dart';

class PlaylistBloc extends Bloc<PlaylistEvent, PlaylistState> {
  final PlaylistRepository repository;

  PlaylistBloc({required this.repository}) : super(const PlaylistState()) {
    on<GetPlaylistsEvent>(_onGetPlaylists);
    on<AddM3uPlaylistEvent>(_onAddM3uPlaylist);
    on<AddXtreamPlaylistEvent>(_onAddXtreamPlaylist);
    on<DeletePlaylistEvent>(_onDeletePlaylist);
    on<RefreshPlaylistEvent>(_onRefreshPlaylist);
    on<AddDirectStreamEvent>(_onAddDirectStream);
    on<AddM3uFilePlaylistEvent>(_onAddM3uFilePlaylist);
  }

  Future<void> _onGetPlaylists(GetPlaylistsEvent event, Emitter<PlaylistState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await repository.getPlaylists();
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (playlists) => emit(state.copyWith(isLoading: false, playlists: playlists)),
    );
  }

  Future<void> _onAddDirectStream(AddDirectStreamEvent event, Emitter<PlaylistState> emit) async {
    emit(state.copyWith(error: null));
    final result = await repository.addDirectStream(event.name, event.url);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (_) {
        emit(state.copyWith(isLoading: false, operationSuccess: true));
        add(GetPlaylistsEvent());
      },
    );
  }

  Future<void> _onAddM3uPlaylist(AddM3uPlaylistEvent event, Emitter<PlaylistState> emit) async {
    emit(state.copyWith(error: null));
    final result = await repository.addM3uPlaylist(event.name, event.url);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (_) {
        emit(state.copyWith(isLoading: false, operationSuccess: true));
        add(GetPlaylistsEvent());
      },
    );
  }

  Future<void> _onAddXtreamPlaylist(AddXtreamPlaylistEvent event, Emitter<PlaylistState> emit) async {
    emit(state.copyWith(error: null));
    final result = await repository.addXtreamPlaylist(
      name: event.name,
      url: event.url,
      username: event.username,
      password: event.password,
    );
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (_) {
        emit(state.copyWith(isLoading: false, operationSuccess: true));
        add(GetPlaylistsEvent());
      },
    );
  }

  Future<void> _onDeletePlaylist(DeletePlaylistEvent event, Emitter<PlaylistState> emit) async {
    emit(state.copyWith(error: null));
    final result = await repository.deletePlaylist(event.id);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (_) => add(GetPlaylistsEvent()),
    );
  }

  Future<void> _onRefreshPlaylist(RefreshPlaylistEvent event, Emitter<PlaylistState> emit) async {
    emit(state.copyWith(error: null));
    final result = await repository.refreshPlaylist(event.id);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (_) => add(GetPlaylistsEvent()),
    );
  }

  Future<void> _onAddM3uFilePlaylist(AddM3uFilePlaylistEvent event, Emitter<PlaylistState> emit) async {
    emit(state.copyWith(error: null));
    final result = await repository.addM3uFilePlaylist(event.name, event.filePath);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (_) {
        emit(state.copyWith(isLoading: false, operationSuccess: true));
        add(GetPlaylistsEvent());
      },
    );
  }
}
