import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/database/app_database.dart';

class CategoryEntity {
  final String name;
  final int count;
  final StreamType type;

  CategoryEntity({required this.name, required this.count, required this.type});
}

abstract class CategoryRepository {
  Future<Either<Failure, List<CategoryEntity>>> getCategories(int playlistId, StreamType type);
}
