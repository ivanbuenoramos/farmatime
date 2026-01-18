import 'package:farmatime/data/models/employee_shift_model.dart';

class Result<T> {
  bool success;
  T data;
  String? errorCode;

  Result({
    required this.success,
    required this.data,
    this.errorCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data,
      'errorCode': errorCode,
    };
  }

  ExpectedShiftModel? operator [](String other) {}
}
