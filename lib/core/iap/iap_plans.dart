import 'dart:io';

/// Catálogo de productos IAP.
///
/// El total de plazas INCLUYE la plaza gratuita.
///
/// **Importante:** cada plan es un producto de suscripción PROPIO en ambas
/// tiendas (no un base plan dentro de una suscripción única). Los product IDs
/// de Google Play solo admiten minúsculas, dígitos, `_` y `.` (los guiones
/// solo son válidos en base plan IDs), así que usamos el mismo ID con `_`
/// en las dos plataformas.
class IapPlan {
  final String iosProductId;
  final String androidProductId;
  final int totalSeats;

  const IapPlan({
    required this.iosProductId,
    required this.androidProductId,
    required this.totalSeats,
  });

  /// ID que debe usarse en la plataforma actual.
  String get productId =>
      Platform.isIOS ? iosProductId : androidProductId;

  /// Comprueba si un ID dado pertenece a este plan (en cualquier plataforma).
  bool matches(String productId) =>
      productId == iosProductId || productId == androidProductId;
}

class IapPlans {
  const IapPlans._();

  static const List<IapPlan> all = [
    IapPlan(
      iosProductId: 'plan_5_employees',
      androidProductId: 'plan_5_employees',
      totalSeats: 5,
    ),
    IapPlan(
      iosProductId: 'plan_10_employees',
      androidProductId: 'plan_10_employees',
      totalSeats: 10,
    ),
    IapPlan(
      iosProductId: 'plan_20_employees',
      androidProductId: 'plan_20_employees',
      totalSeats: 20,
    ),
  ];

  /// IDs a consultar en la plataforma actual.
  static Set<String> get productIds => {for (final p in all) p.productId};

  /// Busca un plan por su ID (probando ambas plataformas).
  static IapPlan? byId(String productId) {
    for (final p in all) {
      if (p.matches(productId)) return p;
    }
    return null;
  }

  /// Plan mínimo que cubre [seats] empleados (redondea hacia arriba).
  static IapPlan? smallestCovering(int seats) {
    for (final p in all) {
      if (p.totalSeats >= seats) return p;
    }
    return null;
  }
}
