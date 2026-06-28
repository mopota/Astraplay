part of 'playlist_bloc.dart';

abstract class PlaylistEvent extends Equatable {
  const PlaylistEvent();

  @override
  List<Object> get props => [];
}

class GetPlaylistsEvent extends PlaylistEvent {}

class AddM3uPlaylistEvent extends PlaylistEvent {
  final String name;
  final String url;

  const AddM3uPlaylistEvent({required this.name, required this.url});

  @override
  List<Object> get props => [name, url];
}

class AddXtreamPlaylistEvent extends PlaylistEvent {
  final String name;
  final String url;
  final String username;
  final String password;

  const AddXtreamPlaylistEvent({
    required this.name,
    required this.url,
    required this.username,
    required this.password,
  });

  @override
  List<Object> get props => [name, url, username, password];
}

class DeletePlaylistEvent extends PlaylistEvent {
  final int id;

  const DeletePlaylistEvent({required this.id});

  @override
  List<Object> get props => [id];
}

class RefreshPlaylistEvent extends PlaylistEvent {
  final int id;

  const RefreshPlaylistEvent({required this.id});

  @override
  List<Object> get props => [id];
}

class AddDirectStreamEvent extends PlaylistEvent {
  final String name;
  final String url;

  const AddDirectStreamEvent({required this.name, required this.url});

  @override
  List<Object> get props => [name, url];
}

class AddM3uFilePlaylistEvent extends PlaylistEvent {
  final String name;
  final String filePath;

  const AddM3uFilePlaylistEvent({required this.name, required this.filePath});

  @override
  List<Object> get props => [name, filePath];
}
