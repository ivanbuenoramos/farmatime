import 'dart:io';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/address.dart';
import 'package:farmatime/domain/usecases/firebase_auth/log_out_usecase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:farmatime/data/models/company_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/usecases/company/update_company_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_storage/upload_file_usecase.dart';

class CompanyAccountController extends GetxController {
  
  final Brain brain = Get.find<Brain>();

  final UploadFileUseCase uploadFileUseCase;
  final UpdateCompanyUsecase updateCompanyUseCase;
  final LogOutUseCase logOutUseCase;

  CompanyAccountController({
    required this.uploadFileUseCase,
    required this.updateCompanyUseCase,
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

  late final CompanyModel originalCompany;

  @override
  void onInit() {
    super.onInit();
    final company = brain.company.value!;
    originalCompany = company;

    nameController.text = company.legalName;
    emailController.text = company.email;
    cifController.text = company.vatNumber ?? '';
    // phoneController.text = company.phone ?? '';
    addressController.text = company.address?.address ?? '';
    cityController.text = company.address?.city ?? '';
    provinceController.text = company.address?.state ?? '';
    postalCodeController.text = company.address?.zipCode ?? '';
    logoUrl.value = company.logoUrl ?? '';
  }

  Future<void> pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    isUploadingLogo.value = true;

    final fileUrl = await uploadFileUseCase.call(
      file: file,
      path: 'companies/${originalCompany.id}',
      fileName: 'logo.jpg',
    );
    if (fileUrl == null) {
      ToastService().show(title: 'Error', message: 'No se pudo subir la imagen', type: ToastType.error);
      isUploadingLogo.value = false;
      return;
    } else {
      logoUrl.value = fileUrl;
    }
    
    isUploadingLogo.value = false;
  }

  Future<void> saveChanges() async {

    final Address updatedAddress = Address(
      address: addressController.text.trim(),
      city: cityController.text.trim(),
      state: provinceController.text.trim(),
      zipCode: postalCodeController.text.trim(),
      country: 'España',
    );

    final updatedCompany = originalCompany.copyWith(
      legalName: nameController.text.trim(),
      email: emailController.text.trim(),
      vatNumber: cifController.text.trim(),
      // phoneNumber: phoneController.text.trim(),
      address: updatedAddress,
      logoUrl: logoUrl.value,
      updatedAt: DateTime.now(),
    );

    final Result<CompanyModel?> result = await updateCompanyUseCase.call(updatedCompany);
    if (!result.success || result.data == null) {
      ToastService().show(title: 'Error', message: 'No se pudo actualizar la empresa', type: ToastType.error);
      return;
    }

    brain.company.value = result.data;
    ToastService().show(title: 'Éxito', message: 'Datos actualizados correctamente', type: ToastType.success);
  }

  void logOut() async {
    Get.offNamed(Routes.index);
    await logOutUseCase.call();
    brain.clearSession();
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

  void redirectToProfile() {
    Get.toNamed(Routes.companyProfile);
  }

  void redirectToSubscription() {
    Get.toNamed(Routes.companySubscription);
  }

  void redirectToClockReports() {
    Get.toNamed(Routes.companyClockReports);
  }

  void redirectToChangePassword() {
    Get.toNamed(Routes.changePassword);
  }

  void redirectToSettings() {
    Get.toNamed(Routes.companySettings);
  }
}
