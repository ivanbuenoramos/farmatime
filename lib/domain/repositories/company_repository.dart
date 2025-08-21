import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';

abstract class CompanyRepository {
  Future<Result<CompanyModel?>> createCompany(CompanyModel company);
  Future<Result<CompanyModel?>> updateCompany(CompanyModel company);
  Future<Result<CompanyModel?>> getCompanyById(String companyId);
}
