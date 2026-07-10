import 'package:dartz/dartz.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase database;
  
  // Simple Memory Cache
  final Map<String, List<CategoryEntity>> _cache = {};

  CategoryRepositoryImpl({required this.database});

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories(int playlistId, StreamType type) async {
    final cacheKey = '${playlistId}_${type.name}';
    if (_cache.containsKey(cacheKey)) {
      return Right(_cache[cacheKey]!);
    }

    try {
      // Professional approach: Fetch categories from dedicated collection
      final categoriesFromDb = await database.isar.streamCategorys
          .where()
          .playlistIdEqualTo(playlistId)
          .filter()
          .streamTypeEqualTo(type)
          .findAll();

      if (categoriesFromDb.isNotEmpty) {
        final categories = categoriesFromDb.map((c) => CategoryEntity(
          name: c.name,
          count: c.count,
          type: type,
        )).toList();
        
        categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        
        // Cache only if we have counts, or don't cache at all to allow background updates to reflect
        if (categories.any((c) => c.count > 0)) {
          _cache[cacheKey] = categories;
        }
        return Right(categories);
      }

      // Fallback for M3U playlists which might not have separate categories yet
      final categoryNames = await database.getCategoryNames(playlistId, type);
      final categoryMap = <String, int>{};
      for (var name in categoryNames) {
        categoryMap[name] = (categoryMap[name] ?? 0) + 1;
      }

      final categories = categoryMap.entries.map((e) => CategoryEntity(
        name: e.key,
        count: e.value,
        type: type,
      )).toList();
      
      categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _cache[cacheKey] = categories;
      return Right(categories);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  void clearCache() {
    _cache.clear();
  }
}
