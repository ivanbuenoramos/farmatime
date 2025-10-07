import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:farmatime/domain/repositories/shift_template_repository.dart';

class ListShiftTemplatesUseCase {
  final ShiftTemplateRepository repo;
  ListShiftTemplatesUseCase(this.repo);

  Future<Result<List<ShiftTemplate>>> call(String companyId) =>
      repo.listByCompany(companyId);
}