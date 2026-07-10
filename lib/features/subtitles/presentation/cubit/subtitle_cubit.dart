import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/services/subtitle_service.dart';
import '../../data/models/subtitle_model.dart';

abstract class SubtitleState extends Equatable {
  const SubtitleState();
  @override
  List<Object?> get props => [];
}

class SubtitleInitial extends SubtitleState {}
class SubtitleLoading extends SubtitleState {}
class SubtitleSearchSuccess extends SubtitleState {
  final List<SubtitleSearchResult> results;
  const SubtitleSearchSuccess(this.results);
  @override
  List<Object?> get props => [results];
}
class SubtitleDownloadSuccess extends SubtitleState {
  final String path;
  const SubtitleDownloadSuccess(this.path);
  @override
  List<Object?> get props => [path];
}
class SubtitleError extends SubtitleState {
  final String message;
  const SubtitleError(this.message);
  @override
  List<Object?> get props => [message];
}

class SubtitleCubit extends Cubit<SubtitleState> {
  final SubtitleService _service;

  SubtitleCubit(this._service) : super(SubtitleInitial());

  Future<void> search(String query, {String languages = 'ar,en'}) async {
    emit(SubtitleLoading());
    try {
      final results = await _service.searchSubtitles(query: query, languages: languages);
      emit(SubtitleSearchSuccess(results));
    } catch (e) {
      emit(SubtitleError(e.toString()));
    }
  }

  Future<void> download(SubtitleSearchResult sub) async {
    emit(SubtitleLoading());
    try {
      final path = await _service.downloadSubtitle(sub);
      if (path != null) {
        emit(SubtitleDownloadSuccess(path));
      } else {
        emit(const SubtitleError('Failed to download subtitle'));
      }
    } catch (e) {
      emit(SubtitleError(e.toString()));
    }
  }
  
  void reset() {
    emit(SubtitleInitial());
  }
}
