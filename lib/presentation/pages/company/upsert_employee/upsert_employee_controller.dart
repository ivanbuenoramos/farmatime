// lib/presentation/pages/company/upsert_employee/upsert_employee_controller.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/core/utils/avatar_colors.dart';
import 'package:farmatime/data/models/employee_model.dart';
import 'package:farmatime/data/models/result.dart';
import 'package:farmatime/domain/repositories/employee_repository.dart';
import 'package:farmatime/domain/usecases/employee/create_employee_usecase.dart';
import 'package:farmatime/domain/usecases/employee/update_employee_usecase.dart';
import 'package:farmatime/domain/usecases/employee/check_employee_email_usecase.dart';
import 'package:farmatime/domain/usecases/firebase_storage/upload_file_usecase.dart';

/// Estado de la validación del correo mostrada en tiempo real bajo el campo.
enum EmailFieldStatus {
  /// Sin escribir / campo vacío. No se muestra nada.
  idle,

  /// Formato inválido (no es un correo).
  invalidFormat,

  /// Comprobando disponibilidad contra el servidor.
  checking,

  /// Formato correcto y disponible para usarse.
  available,

  /// Ya existe un usuario con ese correo.
  alreadyInUse,

  /// No se pudo comprobar (error de red / servidor).
  error,
}

class UpsertEmployeeController extends GetxController {
  final CreateEmployeeUseCase createEmployeeUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final CheckEmployeeEmailUseCase checkEmployeeEmailUseCase;
  final UploadFileUseCase uploadFileUseCase;

  UpsertEmployeeController({
    required this.createEmployeeUseCase,
    required this.updateEmployeeUseCase,
    required this.checkEmployeeEmailUseCase,
    required this.uploadFileUseCase,
  });

  final Brain brain = Get.find<Brain>();
  final ToastService toastService = ToastService();

  // Text controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final hourlyRateController = TextEditingController(text: '0');
  final vacationPer30Controller = TextEditingController(text: '2.5');
  final personalPerYearController = TextEditingController(text: '0');
  final roleOtherController = TextEditingController();

  // Estado
  final role = EmployeeRole.tecnico.obs;
  final workdayType = Rx<WorkdayType?>(null);
  final isLoading = false.obs;

  // Validación del correo en tiempo real
  final emailStatus = EmailFieldStatus.idle.obs;
  Timer? _emailDebounce;
  String _lastCheckedEmail = '';

  // Foto de perfil (solo edición)
  final RxString photoUrl = ''.obs;
  final RxBool isUploadingPhoto = false.obs;

  EmployeeModel? originalEmployee;
  bool get isEdit => originalEmployee != null;

  /// ¿El formulario tiene cambios respecto al estado inicial? Se usa para
  /// avisar al salir sin guardar.
  bool get hasChanges {
    final o = originalEmployee;
    String norm(String s) => s.trim();

    if (o == null) {
      // Creación: hay cambios si se escribió algo relevante.
      return norm(nameController.text).isNotEmpty ||
          norm(emailController.text).isNotEmpty ||
          norm(roleOtherController.text).isNotEmpty ||
          role.value != EmployeeRole.tecnico ||
          workdayType.value != null;
    }

    return norm(nameController.text) != norm(o.name) ||
        norm(emailController.text) != norm(o.email) ||
        _parseDouble(hourlyRateController) != o.hourlyRate ||
        _parseDouble(vacationPer30Controller, def: 2.5) !=
            o.vacationDaysPer30 ||
        _parseDouble(personalPerYearController) != o.personalDaysPerYear ||
        role.value != o.role ||
        (role.value == EmployeeRole.otro &&
            norm(roleOtherController.text) != norm(o.roleOther ?? '')) ||
        workdayType.value != o.workdayType ||
        (photoUrl.value.isEmpty ? null : photoUrl.value) != o.photoUrl;
  }

  @override
  void onInit() {
    super.onInit();

    final arg = Get.arguments;
    if (arg is EmployeeModel) {
      originalEmployee = arg;
      _loadFromEmployee(arg);
    } else {
      // modo creación, defaults ya puestos
    }

    // Validación del correo en tiempo real solo al crear: al editar, el
    // correo ya pertenece al propio empleado y no debe marcarse "en uso".
    if (!isEdit) {
      emailController.addListener(_onEmailChanged);
    }
  }

  void _onEmailChanged() {
    final email = emailController.text.trim();

    _emailDebounce?.cancel();

    if (email.isEmpty) {
      emailStatus.value = EmailFieldStatus.idle;
      _lastCheckedEmail = '';
      return;
    }

    if (!GetUtils.isEmail(email)) {
      emailStatus.value = EmailFieldStatus.invalidFormat;
      _lastCheckedEmail = '';
      return;
    }

    // Formato correcto: esperamos a que deje de escribir antes de consultar.
    _emailDebounce = Timer(const Duration(milliseconds: 600), () {
      _checkEmailAvailability(email);
    });
  }

  Future<void> _checkEmailAvailability(String email) async {
    // Evita relanzar la misma comprobación si el texto no cambió.
    if (email == _lastCheckedEmail &&
        emailStatus.value == EmailFieldStatus.available) {
      return;
    }

    emailStatus.value = EmailFieldStatus.checking;

    final result = await checkEmployeeEmailUseCase.call(email);

    // El usuario pudo seguir escribiendo mientras consultábamos.
    if (emailController.text.trim() != email) return;

    _lastCheckedEmail = email;

    switch (result) {
      case EmailAvailability.available:
        emailStatus.value = EmailFieldStatus.available;
        break;
      case EmailAvailability.alreadyInUse:
        emailStatus.value = EmailFieldStatus.alreadyInUse;
        break;
      case EmailAvailability.invalidFormat:
        emailStatus.value = EmailFieldStatus.invalidFormat;
        break;
      case EmailAvailability.unknown:
        emailStatus.value = EmailFieldStatus.error;
        break;
    }
  }

  void _loadFromEmployee(EmployeeModel employee) {
    nameController.text = employee.name;
    emailController.text = employee.email;
    hourlyRateController.text = employee.hourlyRate.toString().replaceAll(
      '.',
      ',',
    );
    vacationPer30Controller.text = employee.vacationDaysPer30
        .toString()
        .replaceAll('.', ',');
    personalPerYearController.text = employee.personalDaysPerYear
        .toString()
        .replaceAll('.', ',');

    role.value = employee.role;
    roleOtherController.text = employee.roleOther ?? '';
    workdayType.value = employee.workdayType;

    photoUrl.value = employee.photoUrl ?? '';
  }

  double _parseDouble(TextEditingController c, {double def = 0}) {
    final s = c.text.trim().replaceAll(',', '.');
    return double.tryParse(s) ?? def;
  }

  Future<void> pickPhoto() async {
    if (!isEdit) return; // solo permitimos foto cuando ya existe el empleado

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    isUploadingPhoto.value = true;

    try {
      final employee = originalEmployee!;
      final String path = 'employees/${employee.uid}';
      final String fileName = 'profile.jpg';

      final String? url = await uploadFileUseCase.call(
        file: file,
        path: path,
        fileName: fileName,
      );

      if (url == null) {
        toastService.show(
          title: 'Error',
          message: 'No se pudo subir la imagen.',
          type: ToastType.error,
        );
        return;
      }

      photoUrl.value = url;
    } catch (_) {
      toastService.show(
        title: 'Error',
        message: 'No se pudo subir la imagen.',
        type: ToastType.error,
      );
    } finally {
      isUploadingPhoto.value = false;
    }
  }

  Future<void> onSubmit() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty || !GetUtils.isEmail(email)) {
      toastService.show(
        title: 'Error',
        message: 'Por favor, introduce un nombre y correo válidos.',
        type: ToastType.error,
      );
      return;
    }

    // Al crear, asegúrate de que el correo no esté ya en uso. Si la
    // comprobación en tiempo real aún no terminó, la forzamos aquí.
    if (!isEdit) {
      _emailDebounce?.cancel();

      if (emailStatus.value != EmailFieldStatus.available) {
        await _checkEmailAvailability(email);
      }

      if (emailStatus.value == EmailFieldStatus.alreadyInUse) {
        toastService.show(
          title: 'Correo en uso',
          message: 'Ya existe una cuenta con ese correo electrónico.',
          type: ToastType.error,
        );
        return;
      }

      if (emailStatus.value != EmailFieldStatus.available) {
        toastService.show(
          title: 'Error',
          message: 'No se pudo verificar el correo. Inténtalo de nuevo.',
          type: ToastType.error,
        );
        return;
      }
    }

    final rate = _parseDouble(hourlyRateController);
    final vac30 = _parseDouble(vacationPer30Controller, def: 2.5);
    final personal = _parseDouble(personalPerYearController);

    if (rate < 0) {
      toastService.show(
        title: 'Error',
        message: 'El precio por hora no puede ser negativo.',
        type: ToastType.error,
      );
      return;
    }
    if (vac30 < 0) {
      toastService.show(
        title: 'Error',
        message: 'Los días de vacaciones/30 días no pueden ser negativos.',
        type: ToastType.error,
      );
      return;
    }
    if (personal < 0) {
      toastService.show(
        title: 'Error',
        message: 'Los días de asuntos propios/año no pueden ser negativos.',
        type: ToastType.error,
      );
      return;
    }
    if (role.value == EmployeeRole.otro &&
        roleOtherController.text.trim().isEmpty) {
      toastService.show(
        title: 'Error',
        message: 'Indica el cargo en "Otro (especificar)".',
        type: ToastType.error,
      );
      return;
    }

    isLoading.value = true;

    try {
      if (isEdit) {
        await _updateEmployee(
          name: name,
          email: email,
          rate: rate,
          vac30: vac30,
          personal: personal,
        );
      } else {
        await _createEmployee(
          name: name,
          email: email,
          rate: rate,
          vac30: vac30,
          personal: personal,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _createEmployee({
    required String name,
    required String email,
    required double rate,
    required double vac30,
    required double personal,
  }) async {
    final companyId = brain.company.value!.id;
    final now = DateTime.now();

    final newEmployee = EmployeeModel(
      uid: '',
      companyId: companyId,
      name: name,
      email: email,
      hasTempPassword: true, // backend genera la temp y la guarda privada
      photoUrl: null,
      avatarColor: AvatarColors.randomColorValue(),
      position: null,
      accountStatus: EmployeeAccountStatus.pending,
      hireDate: now,
      createdAt: now,
      updatedAt: now,
      hourlyRate: rate,
      role: role.value,
      roleOther: role.value == EmployeeRole.otro
          ? roleOtherController.text.trim()
          : null,
      workdayType: workdayType.value,
      vacationDaysPer30: vac30,
      personalDaysPerYear: personal,
    );

    final Result<EmployeeModel?> result = await createEmployeeUseCase.call(
      newEmployee,
    );

    if (!result.success || result.data == null) {
      toastService.showParsedErrorCode(
        result.errorCode,
        defaultMessage: 'No se pudo crear el empleado. Inténtalo de nuevo.',
      );
      return;
    }

    toastService.show(
      title: 'Empleado creado',
      message: 'El empleado ha sido creado correctamente.',
      type: ToastType.success,
    );

    // Limpia y vuelve atrás devolviendo el empleado creado
    _resetForm();
    Get.back(result: result.data);
  }

  Future<void> _updateEmployee({
    required String name,
    required String email,
    required double rate,
    required double vac30,
    required double personal,
  }) async {
    final original = originalEmployee!;
    final now = DateTime.now();

    final updated = original.copyWith(
      name: name,
      email: email,
      hourlyRate: rate,
      role: role.value,
      roleOther: role.value == EmployeeRole.otro
          ? roleOtherController.text.trim()
          : null,
      workdayType: workdayType.value,
      vacationDaysPer30: vac30,
      personalDaysPerYear: personal,
      photoUrl: photoUrl.value.isEmpty ? null : photoUrl.value,
      updatedAt: now,
    );

    final Result<EmployeeModel?> result = await updateEmployeeUseCase.call(
      updated,
    );

    if (!result.success || result.data == null) {
      toastService.showParsedErrorCode(
        result.errorCode,
        defaultMessage: 'No se pudo actualizar el empleado. Inténtalo de nuevo.',
      );
      return;
    }

    toastService.show(
      title: 'Cambios guardados',
      message: 'Los datos del empleado se han actualizado correctamente.',
      type: ToastType.success,
    );

    originalEmployee = result.data;
    Get.back(result: result.data);
  }

  void _resetForm() {
    nameController.clear();
    emailController.clear();
    hourlyRateController.text = '0';
    vacationPer30Controller.text = '2.5';
    personalPerYearController.text = '0';
    role.value = EmployeeRole.tecnico;
    roleOtherController.clear();
    workdayType.value = null;
    photoUrl.value = '';
    emailStatus.value = EmailFieldStatus.idle;
    _lastCheckedEmail = '';
  }

  @override
  void onClose() {
    _emailDebounce?.cancel();
    emailController.removeListener(_onEmailChanged);
    nameController.dispose();
    emailController.dispose();
    hourlyRateController.dispose();
    vacationPer30Controller.dispose();
    personalPerYearController.dispose();
    roleOtherController.dispose();
    super.onClose();
  }
}
