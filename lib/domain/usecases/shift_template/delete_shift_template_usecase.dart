import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/shift_template_repository.dart';

class DeleteShiftTemplateUseCase {
  final ShiftTemplateRepository repo;
  DeleteShiftTemplateUseCase(this.repo);

  Future<Result<bool>> call(String id) => repo.delete(id);
}