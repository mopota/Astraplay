import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'core/database/app_database.dart';
import 'features/playlist/data/datasources/playlist_remote_data_source.dart';
import 'features/playlist/data/repositories/playlist_repository_impl.dart';
import 'features/playlist/domain/repositories/playlist_repository.dart';
import 'features/playlist/presentation/bloc/playlist_bloc.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/category/domain/repositories/category_repository.dart';
import 'features/category/data/repositories/category_repository_impl.dart';
import 'features/category/domain/repositories/stream_repository.dart';
import 'features/category/data/repositories/stream_repository_impl.dart';
import 'features/search/domain/repositories/search_repository.dart';
import 'features/search/data/repositories/search_repository_impl.dart';
import 'features/subtitles/domain/services/subtitle_service.dart';
import 'features/subtitles/presentation/cubit/subtitle_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Features
  
  // Blocs
  sl.registerFactory(() => PlaylistBloc(repository: sl()));
  sl.registerLazySingleton(() => SettingsCubit(sl()));
  sl.registerFactory(() => SubtitleCubit(sl()));

  // Repositories
  sl.registerLazySingleton<PlaylistRepository>(
    () => PlaylistRepositoryImpl(
      database: sl(),
      remoteDataSource: sl(),
      dio: sl(),
    ),
  );
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(database: sl()),
  );
  sl.registerLazySingleton<StreamRepository>(
    () => StreamRepositoryImpl(
      database: sl(),
      remoteDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(
      database: sl(),
    ),
  );

  // Services
  sl.registerLazySingleton(() => SubtitleService());

  // Data sources
  sl.registerLazySingleton<PlaylistRemoteDataSource>(
    () => PlaylistRemoteDataSourceImpl(dio: sl()),
  );

  //! Core
  sl.registerLazySingleton(() => AppDatabase());
  
  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  sl.registerLazySingleton(() => dio);
}
