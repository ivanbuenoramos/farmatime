import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/shift_template_model.dart';
import 'package:farmatime/domain/repositories/shift_template_repository.dart';

class UpsertShiftTemplateUseCase {
  final ShiftTemplateRepository repo;
  UpsertShiftTemplateUseCase(this.repo);

  Future<Result<String>> call(ShiftTemplate t) => repo.upsert(t);
}