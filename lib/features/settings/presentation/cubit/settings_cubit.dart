import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final AppSettings settings;
  final bool isLoading;

  SettingsState({required this.settings, this.isLoading = false});

  SettingsState copyWith({AppSettings? settings, bool? isLoading}) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  final AppDatabase _database;

  SettingsCubit(this._database) : super(SettingsState(settings: AppSettings(), isLoading: true));

  Future<void> loadSettings() async {
    final settings = await _database.isar.appSettings.where().findFirst();
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('active_playlist_id');

    if (settings != null) {
      settings.activePlaylistId = activeId;
      emit(SettingsState(settings: settings, isLoading: false));
    } else {
      final defaultSettings = AppSettings()..activePlaylistId = activeId;
      await _database.isar.writeTxn(() async {
        await _database.isar.appSettings.put(defaultSettings);
      });
      emit(SettingsState(settings: defaultSettings, isLoading: false));
    }
  }

  Future<void> updateSettings(Function(AppSettings) update) async {
    await _database.isar.writeTxn(() async {
      update(state.settings);
      await _database.isar.appSettings.put(state.settings);
    });
    
    emit(SettingsState(settings: state.settings, isLoading: false));
  }
  
  Future<void> setThemeMode(String mode) async {
    await updateSettings((s) => s.themeMode = mode);
  }

  Future<void> setActivePlaylist(int? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove('active_playlist_id');
    } else {
      await prefs.setInt('active_playlist_id', id);
    }
    
    // Also update memory state
    state.settings.activePlaylistId = id;
    emit(SettingsState(settings: state.settings, isLoading: false));
  }
}
