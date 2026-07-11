import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase database;
  
  final Map<String, List<CategoryEntity>> _cache = {};

  CategoryRepositoryImpl({required this.database});

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories(int playlistId, StreamType type) async {
    final sw = Stopwatch()..start();
    final cacheKey = '${playlistId}_${type.name}';
    if (_cache.containsKey(cacheKey)) return Right(_cache[cacheKey]!);

    try {
      // Use the composite index (playlistId, streamType, name)
      final cats = await database.isar.streamCategorys
          .filter()
          .playlistIdEqualTo(playlistId)
          .streamTypeEqualTo(type)
          .findAll();
      
      final result = cats.map((c) => CategoryEntity(
        name: c.name,
        count: c.count,
        type: type,
      )).toList();
      
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      
      if (result.isNotEmpty) _cache[cacheKey] = result;
      
      debugPrint('[DataPipeline] getCategories took: ${sw.elapsedMilliseconds}ms');
      return Right(result);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  void clearCache() {
    _cache.clear();
  }
}
