import 'package:dartz/dartz.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase database;

  CategoryRepositoryImpl({required this.database});

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories(int playlistId, StreamType type) async {
    try {
      final streams = await database.isar.appStreams
          .filter()
          .playlistIdEqualTo(playlistId)
          .streamTypeEqualTo(type)
          .findAll();

      final categoryMap = <String, int>{};
      for (var s in streams) {
        categoryMap[s.categoryName] = (categoryMap[s.categoryName] ?? 0) + 1;
      }

      final categories = categoryMap.entries.map((e) => CategoryEntity(
        name: e.key,
        count: e.value,
        type: type,
      )).toList();

      return Right(categories);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
