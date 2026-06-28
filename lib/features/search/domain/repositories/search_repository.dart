import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/database/app_database.dart';

abstract class SearchRepository {
  Future<Either<Failure, List<AppStream>>> search(String query, {int? playlistId});
}
