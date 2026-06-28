import 'package:dartz/dartz.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/search_repository.dart';
import 'package:isar_community/isar.dart';

class SearchRepositoryImpl implements SearchRepository {
  final AppDatabase database;

  SearchRepositoryImpl({required this.database});

  @override
  Future<Either<Failure, List<AppStream>>> search(String query, {int? playlistId}) async {
    try {
      if (query.isEmpty) return const Right([]);

      final queryBuilder = database.isar.appStreams
          .filter()
          .group((q) => q.nameContains(query, caseSensitive: false)
            .or()
            .categoryNameContains(query, caseSensitive: false));
      
      final results = playlistId != null 
          ? await queryBuilder.playlistIdEqualTo(playlistId).limit(100).findAll()
          : await queryBuilder.limit(100).findAll();

      return Right(results);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
