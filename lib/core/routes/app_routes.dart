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
        name: Routes.recoverPassword,
        page: () => const ForgotPasswordPage(),
        binding: ForgotPasswordBinding(),
      ),

      GetPage(
        name: Routes.employeeAuthSignIn,
        page: () => const EmployeeAuthSignInPage(),
        binding: EmployeeAuthSignInBinding(),
      ),

      GetPage(
        name: Routes.employeeSetPassword,
        page: () => const EmployeeSetPasswordPage(),
        binding: EmployeeSetPasswordBinding(),
      ),

      GetPage(
        name: Routes.employeeSubscriptionCanceled,
        page: () => const EmployeeSubscriptionCanceledPage(),
        binding: EmployeeSubscriptionCanceledBinding(),
      ),

      GetPage(
        name: Routes.employeeMain,
        page: () => EmployeeMainPage(),
        binding: EmployeeMainBinding(),
      ),

      GetPage(
        name: Routes.employeeCalendar,
        page: () => EmployeeCalendarPage(),
        binding: EmployeeCalendarBinding(),
      ),

      GetPage(
        name: Routes.employeeRequestLeave,
        page: () => RequestLeavePage(),
        binding: RequestLeaveBinding(),
      ),

      GetPage(
        name: Routes.employeeAccount,
        page: () => EmployeeAccountPage(),
        binding: EmployeeAccountBinding(),
      ),

      GetPage(
        name: Routes.employeeProfile,
        page: () => const EmployeeProfilePage(),
        binding: EmployeeProfileBinding(),
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
        name: Routes.companyAuthVerifyEmail,
        page: () => const VerifyEmailPage(),
        binding: VerifyEmailBinding(),
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
        name: Routes.companyClockReports,
        page: () => const ClockReportsPage(),
        binding: ClockReportsBinding(),
      ),

      GetPage(
        name: Routes.companyUpsertEmployee,
        page: () => const UpsertEmployeePage(),
        binding: UpsertEmployeeBinding(),
      ),

      GetPage(
        name: Routes.companyEmployeeDetail,
        page: () => const EmployeeDetailPage(),
        binding: EmployeeDetailBinding(),
      ),

      GetPage(
        name: Routes.companyDeleteEmployee,
        page: () => const DeleteEmployeePage(),
        binding: DeleteEmployeeBinding(),
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
        name: Routes.companySubscriptionSelectEmployeesToRemove,
        page: () => const SelectEmployeeToRemovePage(),
        binding: SelectEmployeeToRemoveBinding(),
      ),

      GetPage(
        name: Routes.companySubscriptionIncompletePayment,
        page: () => const IncompletePaymentPage(),
        binding: IncompletePaymentBinding(),
      ),
      
      GetPage(
        name: Routes.companyPaymentMethods,
        page: () => const PaymentMethodsPage(),
        binding: PaymentMethodsBinding(),
      ),

      GetPage(
        name: Routes.companySettings,
        page: () => const SettingsPage(),
        binding: SettingsBinding(),
      ),

    ];
  }
}