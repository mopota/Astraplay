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
  final bool isDownloading;

  const SubtitleSearchSuccess(this.results, {this.isDownloading = false});

  @override
  List<Object?> get props => [results, isDownloading];
}

class SubtitleDownloadSuccess extends SubtitleState {
  final String path;
  final List<SubtitleSearchResult> results;

  const SubtitleDownloadSuccess(this.path, this.results);

  @override
  List<Object?> get props => [path, results];
}

class SubtitleError extends SubtitleState {
  final String message;
  final List<SubtitleSearchResult> results;

  const SubtitleError(this.message, {this.results = const []});

  @override
  List<Object?> get props => [message, results];
}

class SubtitleCubit extends Cubit<SubtitleState> {
  final SubtitleService _service;

  SubtitleCubit(this._service) : super(SubtitleInitial());

  List<SubtitleSearchResult> _lastResults = [];

  Future<void> search(String query, {String languages = 'ar,en'}) async {
    emit(SubtitleLoading());
    try {
      final results = await _service.searchSubtitles(query: query, languages: languages);
      _lastResults = results;
      emit(SubtitleSearchSuccess(results));
    } catch (e) {
      emit(SubtitleError(e.toString(), results: _lastResults));
    }
  }

  Future<void> download(SubtitleSearchResult sub) async {
    emit(SubtitleSearchSuccess(_lastResults, isDownloading: true));
    try {
      final path = await _service.downloadSubtitle(sub);
      if (path != null) {
        emit(SubtitleDownloadSuccess(path, _lastResults));
      } else {
        emit(SubtitleError('Failed to download subtitle', results: _lastResults));
      }
    } catch (e) {
      emit(SubtitleError(e.toString(), results: _lastResults));
    }
  }
  
  void reset() {
    emit(SubtitleInitial());
  }
}
