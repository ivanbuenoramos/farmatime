import 'dart:io';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';


import 'package:farmatime/domain/usecases/firebase_storage/upload_file_usecase.dart';

class EmployeeProfileController extends GetxController {
  
  final Brain brain = Get.find<Brain>();

  final UploadFileUseCase uploadFileUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final LogOutUseCase logOutUseCase;

  EmployeeProfileController({
    required this.uploadFileUseCase,
    required this.updateEmployeeUseCase,
    required this.logOutUseCase,
  });

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final cifController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final provinceController = TextEditingController();
  final postalCodeController = TextEditingController();

  final RxString photoUrl = ''.obs;
  final RxBool isUploadingLogo = false.obs;
  final RxBool isSaving = false.obs;

  late EmployeeModel originalEmployee;

  @override
  void onInit() {
    super.onInit();
    final employee = brain.employee.value!;
    originalEmployee = employee;

    nameController.text = employee.name;
    emailController.text = employee.email;
    photoUrl.value = employee.photoUrl ?? '';
  }

  Future<void> pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    isUploadingLogo.value = true;

    final fileUrl = await uploadFileUseCase.call(
      file: file,
      path: 'employees/${originalEmployee.uid}',
      fileName: 'photo.jpg',
    );
    if (fileUrl == null) {
      ToastService().show(title: 'Error', message: 'No se pudo subir la imagen', type: ToastType.error);
      isUploadingLogo.value = false;
      return;
    } else {
      photoUrl.value = fileUrl;
    }

    // Persistimos la nueva foto inmediatamente.
    await _persist(silent: false);

    isUploadingLogo.value = false;
  }

  String? _validate() {
    if (nameController.text.trim().isEmpty) {
      return 'El nombre no puede estar vacío.';
    }
    return null;
  }

  Future<void> saveChanges() async {
    final error = _validate();
    if (error != null) {
      ToastService().show(title: 'Revisa los datos', message: error, type: ToastType.warning);
      return;
    }
    if (isSaving.value) return;
    isSaving.value = true;
    await _persist(silent: false);
    isSaving.value = false;
  }

  Future<void> _persist({required bool silent}) async {
    final updatedEmployee = originalEmployee.copyWith(
      name: nameController.text.trim(),
      photoUrl: photoUrl.value,
      updatedAt: DateTime.now(),
    );

    final Result<EmployeeModel?> result =
        await updateEmployeeUseCase.call(updatedEmployee);
    if (!result.success || result.data == null) {
      ToastService().show(title: 'Error', message: 'No se pudieron actualizar tus datos', type: ToastType.error);
      return;
    }

    brain.employee.value = result.data;
    originalEmployee = result.data!;
    if (!silent) {
      ToastService().show(title: 'Listo', message: 'Tus datos se han actualizado correctamente', type: ToastType.success);
    }
  }

  void logOut() async {
    await logOutUseCase.call();
    Get.offAllNamed(Routes.index);
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    cifController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    provinceController.dispose();
    postalCodeController.dispose();
    super.onClose();
  }
}
