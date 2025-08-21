import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/domain/repositories/company_repository.dart';

class UpdateCompanyUsecase {
  final CompanyRepository repository;

  UpdateCompanyUsecase(this.repository);

  Future<Result<CompanyModel?>> call(CompanyModel company) {
    return repository.updateCompany(company);
  }
}
