import 'package:get/get.dart';

import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/presentation/presentation.dart';



class AppRoutes {
  static List<GetPage<dynamic>> get pages {
    return [

      GetPage(
        name: Routes.splash,
        page: () => const SplashPage(),
        binding: SplashBinding(),
      ),

      GetPage(
        name: Routes.index,
        page: () => const IndexPage(),
        binding: IndexBinding(),
      ),

      GetPage(
        name: Routes.changePassword,
        page: () => const ChangePasswordPage(),
        binding: ChangePasswordBinding(),
      ),

      GetPage(
        name: Routes.employeeAuthSignIn,
        page: () => const EmployeeAuthSignInPage(),
        binding: EmployeeAuthSignInBinding(),
      ),

      GetPage(
        name: Routes.employeeMain,
        page: () => EmployeeMainPage(),
        binding: EmployeeMainBinding(),
      ),

      GetPage(
        name: Routes.companyAuthSignIn,
        page: () => const CompanyAuthSignInPage(),
        binding: CompanyAuthSignInBinding(),
      ),

      GetPage(
        name: Routes.companyAuthSignUp,
        page: () => const CompanyAuthSignUpPage(),
        binding: CompanyAuthSignUpBinding(),
      ),

      GetPage(
        name: Routes.chat,
        page: () => ChatPage(),
        binding: ChatBinding(),
      ),

      GetPage(
        name: Routes.companyMain,
        page: () => CompanyMainPage(),
        binding: CompanyMainBinding(),
      ),

      GetPage(
        name: Routes.companyCreateEmployee,
        page: () => const CreateEmployeePage(),
        binding: CreateEmployeeBinding(),
      ),

      GetPage(
        name: Routes.companyEmployeeDetail,
        page: () => const EmployeeDetailPage(),
        binding: EmployeeDetailBinding(),
      ),

      GetPage(
        name: Routes.companyEmployeeSchedule,
        page: () => EmployeeSchedulePage(),
        binding: EmployeeScheduleBinding(),
      ),

      GetPage(
        name: Routes.companyShiftTemplates,
        page: () => ShiftTemplatesPage(),
        binding: ShiftTemplatesBinding(),
      ),

      GetPage(
        name: Routes.companySubscription,
        page: () => const SubscriptionPage(),
        binding: SubscriptionBinding(),
      ),

      GetPage(
        name: Routes.companyProfile,
        page: () => const CompanyProfilePage(),
        binding: CompanyProfileBinding(),
      ),

      GetPage(
        name: Routes.companySubscriptionSeatCheckout,
        page: () => const SeatCheckoutPage(),
        binding: SeatCheckoutBinding(),
      ),

      GetPage(
        name: Routes.companyPaymentMethods,
        page: () => const PaymentMethodsPage(),
        binding: PaymentMethodsBinding(),
      ),

    ];
  }
}