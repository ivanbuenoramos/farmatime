import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/shift_template_model.dart';

abstract class ShiftTemplateRepository {
  /// Lista de turnos activos de la empresa
  Future<Result<List<ShiftTemplate>>> listByCompany(String companyId);

  /// Crea o actualiza un turno. Devuelve el id del doc.
  Future<Result<String>> upsert(ShiftTemplate template);

  /// Elimina un turno por id
  Future<Result<bool>> delete(String templateId);
}