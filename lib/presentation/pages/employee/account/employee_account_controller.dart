import 'dart:io';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/firebase_storage/upload_file_usecase.dart';

class EmployeeAccountController extends GetxController {
  
  final Brain brain = Get.find<Brain>();

  final UploadFileUseCase uploadFileUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final LogOutUseCase logOutUseCase;

  EmployeeAccountController({
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

  final RxString logoUrl = ''.obs;
  final RxBool isUploadingLogo = false.obs;

  late final EmployeeModel originalEmployee;

  @override
  void onInit() {
    super.onInit();
    final employee = brain.employee.value!;
    originalEmployee = employee;

    nameController.text = employee.name;
    emailController.text = employee.email;
    logoUrl.value = employee.photoUrl ?? '';
  }

  Future<void> pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    isUploadingLogo.value = true;

    final fileUrl = await uploadFileUseCase.call(
      file: file,
      path: 'companies/${originalEmployee.uid}',
      fileName: 'logo.jpg',
    );
    if (fileUrl == null) {
      Get.snackbar('Error', 'No se pudo subir la imagen');
      isUploadingLogo.value = false;
      return;
    } else {
      logoUrl.value = fileUrl;
    }
    
    isUploadingLogo.value = false;
  }

  Future<void> saveChanges() async {

    final updatedEmployee = originalEmployee.copyWith(
      name: nameController.text.trim(),
      photoUrl: logoUrl.value,
      updatedAt: DateTime.now(),
    );

    final Result<EmployeeModel?> result = await updateEmployeeUseCase.call(updatedEmployee);
    if (!result.success || result.data == null) {
      Get.snackbar('Error', 'No se pudo actualizar la empresa');
      return;
    }

    brain.employee.value = result.data;
    Get.snackbar('Éxito', 'Datos actualizados correctamente');
  }

  void logOut() async {
    print('1');
    brain.clearSession();
    print('2');
    await logOutUseCase.call();
    print('3');
    Get.offAllNamed(Routes.index);
    print('Logged out');
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

  void redirectToPaymentMethods() {
    Get.toNamed(Routes.companyPaymentMethods);
  }

  void redirectToProfile() {
    Get.toNamed(Routes.employeeProfile);
  }

  void redirectToSubscription() {
    Get.toNamed(Routes.companySubscription);
  }

  void redirectToChangePassword() {
    Get.toNamed(Routes.changePassword);
  }
}
