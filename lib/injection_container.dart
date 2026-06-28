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

final sl = GetIt.instance;

Future<void> init() async {
  //! Features
  
  // Blocs
  sl.registerFactory(() => PlaylistBloc(repository: sl()));
  sl.registerLazySingleton(() => SettingsCubit(sl()));

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
    () => StreamRepositoryImpl(database: sl()),
  );
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(database: sl()),
  );

  // Data sources
  sl.registerLazySingleton<PlaylistRemoteDataSource>(
    () => PlaylistRemoteDataSourceImpl(dio: sl()),
  );

  //! Core
  sl.registerLazySingleton(() => AppDatabase());
  
  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => Dio());
}
