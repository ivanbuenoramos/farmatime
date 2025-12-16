import 'package:farmatime/domain/usecases/stripe/apply_seat_change_usecase.dart';
import 'package:farmatime/domain/usecases/stripe/preview_seat_change_usecase.dart';
import 'package:get/get.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'confirm_seat_change_controller.dart';

class ConfirmSeatChangeBinding extends Bindings {
  
  ConfirmSeatChangeBinding({
    required this.prepareSeatChangePaymentUseCase,
  });

  final PrepareSeatChangePaymentUseCase prepareSeatChangePaymentUseCase;
  final ApplySeatChangeUseCase applySeatChangeUseCase = Get.put(
    ApplySeatChangeUseCase(Get.find()),
  );
  final PreviewSeatChangeUseCase previewSeatChangeUseCase = Get.put(
    PreviewSeatChangeUseCase(Get.find()),
  );

  @override
  void dependencies() {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final int initialSeats = args['initialSeats'] as int? ?? 1;
    final int newSeats = args['newSeats'] as int? ?? 1;

    Get.put(
      ConfirmSeatChangeController(
        previewSeatChangeUseCase: Get.find(),
        applySeatChangeUseCase: Get.find(),
        initialSeats: initialSeats,
        newSeats: newSeats,
      ),
    );
  }
}