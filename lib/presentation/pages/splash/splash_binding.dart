import 'package:farmatime/data/repositories/company_repository_impl.dart';
import 'package:farmatime/domain/repositories/company_repository.dart';
import 'package:farmatime/domain/usecases/company/get_company_by_id_usecase.dart';
import 'package:get/get.dart';

import 'package:farmatime/presentation/presentation.dart';



class SplashBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<CompanyRepository>(() => CompanyRepositoryImpl());

    Get.lazyPut<GetCompanyByIdUseCase>(
      () => GetCompanyByIdUseCase(Get.find<CompanyRepository>()),
    );

    Get.lazyPut(() => SplashController(
      getCompanyByIdUseCase: Get.find<GetCompanyByIdUseCase>(),
    ));
  }
}
