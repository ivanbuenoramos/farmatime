// Regresión BUG-016: la pantalla de inicio desbordaba 28 px en pantallas
// cortas (emulador Android 1080x2400 @420dpi ≈ 857 dp de alto; peor con
// fuentes grandes). Debe renderizar sin overflow en alturas pequeñas.
import 'package:farmatime/presentation/pages/index/index_controller.dart';
import 'package:farmatime/presentation/pages/index/index_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  // (320x568 queda fuera: en tests la fuente de reserva Ahem hace cada glifo
  //  de 14 px de ancho y provoca un overflow horizontal artificial.)
  for (final size in const [Size(360, 640), Size(411, 731), Size(360, 780)]) {
    testWidgets('IndexPage no desborda en ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Get.put(IndexController());
      addTearDown(Get.reset);

      await tester.pumpWidget(GetMaterialApp(home: const IndexPage()));
      await tester.pump(const Duration(milliseconds: 300));

      // Cualquier overflow se reporta como excepción de layout en tests.
      expect(tester.takeException(), isNull);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
      expect(find.text('ACCESO PARA FARMACIAS'), findsOneWidget);
    });
  }
}
