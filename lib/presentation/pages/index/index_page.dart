// 📄 lib/presentation/pages/index/index_page.dart
import 'package:farmatime/presentation/widgets/buttons/block_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'index_controller.dart';

class IndexPage extends GetView<IndexController> {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // En pantallas cortas (p. ej. 360x640 dp, Android con fuentes grandes)
      // la columna con la ilustración de 200 px desbordaba: se hace
      // desplazable conservando los Spacer en pantallas altas.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'farmatime',
                      style: Get.theme.textTheme.headlineLarge?.copyWith(
                        color: Get.theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 50),
                    SvgPicture.asset(
                      'assets/svg/farmatime_clock.svg',
                      height: 200,
                    ),
                    const SizedBox(height: 32),
                    Text('¡Hola!', style: Get.theme.textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    Text(
                      'Controla el horario laboral, gestiona turnos y vacaciones con cumplimiento normativo, reduciendo al mínimo el trabajo administrativo.',
                      textAlign: TextAlign.center,
                      style: Get.theme.textTheme.bodyMedium,
                    ),
                    Spacer(),
                    BlockButton(
                      onPressed: controller.goToLogin,
                      label: 'INICIAR SESIÓN',
                    ),
                    const SizedBox(height: 12),
                    BlockButton(
                      onPressed: controller.goToPharmacyAccess,
                      label: 'ACCESO PARA FARMACIAS',
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Get.theme.colorScheme.primary,
                      ),
                      color: Colors.transparent,
                      side: BorderSide(
                        color: Get.theme.colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'v1.0.0',
                      style: Get.theme.textTheme.labelMedium?.copyWith(
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
