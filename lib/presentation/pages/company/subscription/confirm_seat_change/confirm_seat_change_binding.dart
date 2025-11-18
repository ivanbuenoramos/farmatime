import 'package:get/get.dart';
import 'package:farmatime/domain/usecases/stripe/prepare_seat_change_payment_usecase.dart';
import 'confirm_seat_change_controller.dart';

class ConfirmSeatChangeBinding extends Bindings {
  ConfirmSeatChangeBinding({
    required this.prepareSeatChangePaymentUseCase,
  });

  final PrepareSeatChangePaymentUseCase prepareSeatChangePaymentUseCase;

  @override
  void dependencies() {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final int initialSeats = args['initialSeats'] as int? ?? 1;
    final int newSeats = args['newSeats'] as int? ?? 1;

    Get.put(
      ConfirmSeatChangeController(
        prepareSeatChangePaymentUseCase: prepareSeatChangePaymentUseCase,
        initialSeats: initialSeats,
        newSeats: newSeats,
      ),
    );
  }
}