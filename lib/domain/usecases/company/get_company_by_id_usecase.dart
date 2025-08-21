import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/domain/repositories/company_repository.dart';

class GetCompanyByIdUseCase {
  final CompanyRepository repository;

  GetCompanyByIdUseCase(this.repository);

  Future<Result<CompanyModel?>> call(String companyId) {
    return repository.getCompanyById(companyId);
  }
}
