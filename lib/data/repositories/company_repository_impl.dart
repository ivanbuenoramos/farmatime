import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/domain/repositories/company_repository.dart';



class CompanyRepositoryImpl implements CompanyRepository {

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  @override
  Future<Result<CompanyModel?>> createCompany(CompanyModel company) async {
    try {
      final docRef = firestore.collection('companies').doc(company.id);
      final newCompany = company.copyWith(id: docRef.id);
      await docRef.set(newCompany.toJson());
      return Result(
        success: true,
        data: newCompany,
      );
    } catch (e) {
      return Result(
        success: false,
        data: null,
        errorCode: e.toString(),
      );
    }
  }

  @override
  Future<Result<CompanyModel?>> updateCompany(CompanyModel company) async {
    try {
      await firestore.collection('companies').doc(company.id).update(company.toJson());
      return Result(
        success: true,
        data: company,
      );
    } catch (e) {
      return Result(
        success: false,
        data: null,
        errorCode: e.toString(),
      );
    }
  }

  @override
  Future<Result<CompanyModel?>> getCompanyById(String companyId) async {
    try {
      final doc = await firestore.collection('companies').doc(companyId).get();
      if (!doc.exists) {
        return Result(
          success: false,
          data: null,
          errorCode: 'Company not found',
        );
      }
      return Result(
        success: true,
        data: CompanyModel.fromJson(doc.data()!),
      );
    } catch (e) {
      return Result(
        success: false,
        data: null,
        errorCode: e.toString(),
      );
    }
  }
}
