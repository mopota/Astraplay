import 'package:dartz/dartz.dart';
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
      
      // Sort categories by name
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
