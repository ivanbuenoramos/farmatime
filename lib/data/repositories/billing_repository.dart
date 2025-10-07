import 'package:farmatime/data/models/billing/billing_models.dart';
import 'package:farmatime/data/models/result.dart';

abstract class BillingRepository {

  Future<Result<CompanyBilling?>> getCompanyBilling(String companyId);

  Stream<CompanyBilling?> watchCompanyBilling(String companyId);
 
  Future<Result<void>> updateOccupiedSeats(String companyId, int occupiedSeats);
  
}