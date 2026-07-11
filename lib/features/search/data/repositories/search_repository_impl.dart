import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/search_repository.dart';
import 'package:isar_community/isar.dart';

class SearchRepositoryImpl implements SearchRepository {
  final AppDatabase database;

  SearchRepositoryImpl({
    required this.database,
  });

  @override
  Future<Either<Failure, List<AppStream>>> search(String query, {int? playlistId}) async {
    final sw = Stopwatch()..start();
    try {
      if (query.trim().isEmpty) return const Right([]);
      final q = query.trim().toLowerCase();

      final results = await database.isar.appStreams
          .filter()
          .optional(playlistId != null, (qF) => qF.playlistIdEqualTo(playlistId!))
          .and()
          .group((qFilter) => qFilter
            .nameContains(q, caseSensitive: false)
            .or()
            .categoryNameContains(q, caseSensitive: false))
          .limit(50) // Limit to 50 for performance
          .findAll();
          
      debugPrint('[DataPipeline] Search took: ${sw.elapsedMilliseconds}ms');
      return Right(results);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
