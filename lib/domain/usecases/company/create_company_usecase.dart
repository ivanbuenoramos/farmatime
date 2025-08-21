import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/domain/repositories/company_repository.dart';

class CreateCompanyUseCase {
  final CompanyRepository repository;

  CreateCompanyUseCase(this.repository);

  Future<Result<CompanyModel?>> call(CompanyModel company) {
    return repository.createCompany(company);
  }
}
