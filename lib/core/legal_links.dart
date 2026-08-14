import 'package:url_launcher/url_launcher.dart';

import 'package:farmatime/core/services/toast_service.dart';

/// Enlaces legales públicos de Farmatime.
///
/// App Store exige que los términos de uso (EULA) y la política de privacidad
/// sean accesibles desde la propia app —no solo desde la ficha de la tienda—
/// en cualquier pantalla que ofrezca suscripciones auto-renovables
/// (guideline 3.1.2).
class LegalLinks {
  static const String privacyPolicy =
      'https://farmatime.net/politica-de-privacidad/';
  static const String termsOfUse = 'https://farmatime.net/terminos-de-uso/';

  static Future<void> openPrivacyPolicy() => _open(privacyPolicy);

  static Future<void> openTermsOfUse() => _open(termsOfUse);

  static Future<void> _open(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Sin navegador disponible: cae al toast de error.
    }
    ToastService().show(
      title: 'No se pudo abrir el enlace',
      message: 'Inténtalo de nuevo en unos instantes.',
      type: ToastType.error,
    );
  }
}
