import 'package:cloud_firestore/cloud_firestore.dart';

import 'address.dart';
import 'phone_number.dart';

enum AuthMethod {
  emailPassword,
  google,
  apple,
}

class CompanyModel {
  final String id;
  final String email;
  final String? logoUrl;

  final String legalName;
  final String? vatNumber;
  final Address? address;
  final PhoneNumber? phoneNumber;
  final AuthMethod? authMethod;

  /// Plazas confirmadas (billadas) incluyendo la gratuita.
  /// 1 = sin suscripción (solo la plaza gratis).
  /// 2+ = suscripción IAP activa.
  final int? contractedSeats;

  /// Estado unificado (ver BillingStatus).
  final String? billingStatus;

  /// Fin del periodo actual (expiresAt del receipt).
  final DateTime? currentPeriodEnd;

  /// Fecha en que la suscripción pasó a un estado no pagado
  /// (canceled / expired / revoked / on_hold / paused).
  /// Null mientras la suscripción esté activa o en grace period del store.
  /// La usamos para calcular el periodo de gracia in-app de 30 días
  /// durante el que la farmacia ve la pantalla de renovar pero los
  /// empleados siguen operativos.
  final DateTime? canceledAt;

  final bool verifiedEmail;
  final bool verifiedPhone;

  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyModel({
    required this.id,
    required this.email,
    this.logoUrl,
    required this.legalName,
    this.vatNumber,
    this.address,
    this.phoneNumber,
    this.authMethod = AuthMethod.emailPassword,
    this.contractedSeats,
    this.billingStatus,
    this.currentPeriodEnd,
    this.canceledAt,
    this.verifiedEmail = false,
    this.verifiedPhone = false,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalSeats {
    final cs = contractedSeats ?? 1;
    return cs < 1 ? 1 : cs;
  }

  int get paidSeats => (totalSeats - 1).clamp(0, 999999);

  bool get hasActiveSubscription {
    final s = billingStatus ?? 'none';
    return s == 'active' || s == 'in_grace_period' || s == 'in_billing_retry';
  }

  /// Estados del store que indican impago / cancelación. Una vez aquí,
  /// arrancamos la ventana de gracia in-app de 30 días desde [canceledAt].
  static const _canceledStatuses = {
    'canceled',
    'expired',
    'revoked',
    'on_hold',
    'paused',
  };

  /// Días de gracia in-app tras la cancelación durante los que los empleados
  /// siguen operativos. Debe coincidir con GRACE_DAYS en el backend
  /// (functions/src/helpers/billingEmployees.js).
  static const int gracePeriodDays = 30;

  /// La suscripción está en periodo de gracia oficial del store
  /// (Apple/Google reintentando el cobro). Sirve para mostrar el banner
  /// "fallo en el pago" a la farmacia. Los empleados no se enteran.
  bool get isInGracePeriod => billingStatus == 'in_grace_period';

  /// Días transcurridos desde la cancelación. 0 si no hay [canceledAt].
  int get daysSinceCanceled {
    final c = canceledAt;
    if (c == null) return 0;
    return DateTime.now().difference(c).inDays;
  }

  /// La cuenta de farmacia debe ver la pantalla de renovación: la suscripción
  /// está cancelada/expirada/revocada (cualquier antigüedad). Aunque también
  /// se aplica fuera de la ventana de gracia, el cliente no necesita
  /// distinguir: lo importante es que NO puede usar la app.
  bool get isPharmacyBlocked {
    final s = billingStatus ?? 'none';
    return _canceledStatuses.contains(s);
  }

  /// Suscripción cancelada y se ha agotado la ventana de gracia in-app:
  /// también los empleados pierden acceso. El backend habrá puesto sus
  /// accountStatus a 'disabled' vía cron, pero contemplamos el caso edge en
  /// el cliente por si entra antes de que corra el cron.
  bool get isFullyBlocked {
    if (!isPharmacyBlocked) return false;
    final c = canceledAt;
    if (c == null) return true; // sin fecha → tratamos como ya expirado
    return DateTime.now().difference(c).inDays >= gracePeriodDays;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    final rawContracted = json['contractedSeats'];
    int? contracted;
    if (rawContracted is num) {
      contracted = rawContracted.toInt();
    } else if (rawContracted is String) {
      contracted = int.tryParse(rawContracted);
    }
    if (contracted == null || contracted < 1) contracted = 1;

    return CompanyModel(
      id: json['id'],
      email: json['email'],
      logoUrl: json['logoUrl'],
      legalName: json['legalName'],
      vatNumber: json['vatNumber'],
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
      phoneNumber: json['phoneNumber'] != null ? PhoneNumber.fromJson(json['phoneNumber']) : null,
      authMethod: json['authMethod'] != null
          ? AuthMethod.values.firstWhere(
              (e) => e.toString() == 'AuthMethod.${json['authMethod']}',
              orElse: () => AuthMethod.emailPassword,
            )
          : AuthMethod.emailPassword,
      contractedSeats: contracted,
      billingStatus: json['billingStatus'],
      currentPeriodEnd: _parseDate(json['currentPeriodEnd']),
      canceledAt: _parseDate(
        (json['subscription'] is Map ? (json['subscription'] as Map)['canceledAt'] : null) ??
            json['canceledAt'],
      ),
      verifiedEmail: json['verifiedEmail'] ?? false,
      verifiedPhone: json['verifiedPhone'] ?? false,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'logoUrl': logoUrl,
        'legalName': legalName,
        'vatNumber': vatNumber,
        'address': address?.toJson(),
        'phoneNumber': phoneNumber?.toJson(),
        'authMethod': authMethod?.toString().split('.').last,
        'contractedSeats': contractedSeats,
        'billingStatus': billingStatus,
        'currentPeriodEnd': currentPeriodEnd?.toIso8601String(),
        // Persistimos como campo top-level en el almacenamiento local
        // (Brain/GetStorage) para que se pueda releer en el siguiente arranque.
        // En Firestore vive bajo subscription.canceledAt y lo gestiona el backend.
        'canceledAt': canceledAt?.toIso8601String(),
        'verifiedEmail': verifiedEmail,
        'verifiedPhone': verifiedPhone,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'email': email,
        'logoUrl': logoUrl,
        'legalName': legalName,
        'vatNumber': vatNumber,
        'address': address?.toJson(),
        'phoneNumber': phoneNumber?.toJson(),
        'authMethod': authMethod?.toString().split('.').last,
        'contractedSeats': contractedSeats,
        'billingStatus': billingStatus,
        'currentPeriodEnd': currentPeriodEnd,
        'verifiedEmail': verifiedEmail,
        'verifiedPhone': verifiedPhone,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  CompanyModel copyWith({
    String? id,
    String? email,
    String? logoUrl,
    String? legalName,
    String? vatNumber,
    Address? address,
    PhoneNumber? phoneNumber,
    AuthMethod? authMethod,
    int? contractedSeats,
    String? billingStatus,
    DateTime? currentPeriodEnd,
    DateTime? canceledAt,
    bool? verifiedEmail,
    bool? verifiedPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      legalName: legalName ?? this.legalName,
      vatNumber: vatNumber ?? this.vatNumber,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      authMethod: authMethod ?? this.authMethod,
      contractedSeats: contractedSeats ?? this.contractedSeats,
      billingStatus: billingStatus ?? this.billingStatus,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      canceledAt: canceledAt ?? this.canceledAt,
      verifiedEmail: verifiedEmail ?? this.verifiedEmail,
      verifiedPhone: verifiedPhone ?? this.verifiedPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
