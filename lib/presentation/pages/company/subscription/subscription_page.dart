import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

import 'package:farmatime/core/iap/iap_plans.dart';
import 'package:farmatime/data/models/employee_model.dart';

import 'subscription_controller.dart';

const Color _kPrimary = Color(0xff1971FF);
const Color _kPrimaryDark = Color(0xff0B4FCC);
const Color _kInk = Color(0xff373737);
const Color _kMuted = Color(0xffA5A5A5);
const Color _kSubtle = Color(0xff737373);
const Color _kBorder = Color(0xffE5E5E5);
const Color _kSurface = Color(0xffFFFFFF);
const Color _kCanvas = Color(0xffF5F5F8);
const Color _kSuccess = Color(0xff22C55E);
const Color _kWarning = Color(0xffF59E0B);
const Color _kDanger = Color(0xffFF0004);

class SubscriptionPage extends GetView<SubscriptionController> {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Suscripción'),
        actions: [
          Obx(() {
            if (controller.isLoading.value) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Restaurar compras',
              onPressed: controller.restorePurchases,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const _LoadingState();
        }
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: controller.restorePurchases,
              color: _kPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _StatusHeroCard(controller: controller),
                  const SizedBox(height: 24),
                  _SectionHeader(controller: controller),
                  const SizedBox(height: 12),
                  Obx(() {
                    if (controller.isLoading.value) return const SizedBox.shrink();
                    if (controller.products.isNotEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StoreUnavailableBanner(
                        diagnostic: controller.loadDiagnostic.value,
                        onRetry: controller.reloadProducts,
                      ),
                    );
                  }),
                  _PlansList(controller: controller),
                  const SizedBox(height: 18),
                  Obx(() {
                    final s = controller.billingStatus.value;
                    final canManage = s == 'active' ||
                        s == 'in_grace_period' ||
                        s == 'in_billing_retry' ||
                        s == 'on_hold' ||
                        s == 'paused';
                    if (!canManage) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _ManageTile(
                        onPressed: controller.openStoreSubscriptionManagement,
                      ),
                    );
                  }),
                  const _LegalNote(),
                ],
              ),
            ),
            Obx(() {
              if (!controller.isBuying.value) return const SizedBox.shrink();
              return const _BuyingOverlay();
            }),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero status card
// ─────────────────────────────────────────────────────────────────────────────

class _StatusHeroCard extends StatelessWidget {
  final SubscriptionController controller;
  const _StatusHeroCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final status = controller.billingStatus.value;
    final seats = controller.contractedSeats.value;
    final used = controller.brain.companyEmployees.length;
    final expires = controller.expiresAt.value;
    final autoRenew = controller.autoRenewing.value;
    final productId = controller.currentProductId.value;

    final hasActive = status == 'active' ||
        status == 'in_grace_period' ||
        status == 'in_billing_retry';

    final visual = _statusVisual(status);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: hasActive
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kPrimary, _kPrimaryDark],
              )
            : null,
        color: hasActive ? null : _kSurface,
        border: hasActive ? null : Border.all(color: _kBorder, width: 1),
        boxShadow: hasActive
            ? [
                BoxShadow(
                  color: _kPrimary.withAlpha(60),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Stack(
        children: [
          if (hasActive) const Positioned.fill(child: _HeroGlow()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeroLabel(
                      label: hasActive ? 'TU SUSCRIPCIÓN' : 'PLAN GRATUITO',
                      onDark: hasActive,
                    ),
                    const Spacer(),
                    _StatusChip(
                      label: visual.label,
                      color: visual.color,
                      onDark: hasActive,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$seats',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        height: 0.95,
                        color: hasActive ? Colors.white : _kInk,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Text(
                        seats == 1 ? 'plaza' : 'plazas',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: hasActive
                              ? Colors.white.withAlpha(225)
                              : _kInk,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hasActive
                      ? 'Empleados que puedes registrar'
                      : 'Tienes 1 empleado gratis. Suscríbete para añadir más.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: hasActive
                        ? Colors.white.withAlpha(195)
                        : _kMuted,
                  ),
                ),
                const SizedBox(height: 18),
                _UsageBar(
                  used: used,
                  total: seats,
                  onDark: hasActive,
                ),
                const SizedBox(height: 18),
                _HeroDivider(onDark: hasActive),
                const SizedBox(height: 14),
                if (hasActive && productId.isNotEmpty)
                  _HeroRow(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Plan',
                    value: _planTitleFor(productId),
                    onDark: hasActive,
                  ),
                if (expires != null) ...[
                  if (hasActive && productId.isNotEmpty)
                    const SizedBox(height: 10),
                  _HeroRow(
                    icon: autoRenew
                        ? Icons.event_repeat_outlined
                        : Icons.event_busy_outlined,
                    label: autoRenew ? 'Próxima renovación' : 'Finaliza el',
                    value: DateFormat("d 'de' MMMM y", 'es').format(expires),
                    onDark: hasActive,
                  ),
                ],
                if (status == 'in_grace_period')
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _AlertBanner(
                      icon: Icons.warning_amber_rounded,
                      text:
                          'Hay un problema con tu método de pago. Estamos reintentando el cobro.',
                      onDark: hasActive,
                      tone: _AlertTone.warning,
                    ),
                  ),
                if (status == 'in_billing_retry')
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _AlertBanner(
                      icon: Icons.autorenew_rounded,
                      text:
                          'Reintentando cobro. Comprueba que tu método de pago esté al día.',
                      onDark: hasActive,
                      tone: _AlertTone.warning,
                    ),
                  ),
                if (status == 'on_hold')
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _AlertBanner(
                      icon: Icons.pause_circle_outline_rounded,
                      text:
                          'Tu suscripción está retenida por la tienda. Actualiza tu pago para reactivarla.',
                      onDark: hasActive,
                      tone: _AlertTone.warning,
                    ),
                  ),
                if (status == 'paused')
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _AlertBanner(
                      icon: Icons.pause_circle_outline_rounded,
                      text: 'Tu suscripción está pausada.',
                      onDark: hasActive,
                      tone: _AlertTone.neutral,
                    ),
                  ),
                if (status == 'revoked' || status == 'expired')
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _AlertBanner(
                      icon: Icons.error_outline_rounded,
                      text: status == 'expired'
                          ? 'Tu suscripción ha caducado. Vuelve a suscribirte para recuperar tus plazas.'
                          : 'Tu suscripción fue revocada. Contacta soporte si crees que es un error.',
                      onDark: hasActive,
                      tone: _AlertTone.danger,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow();
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(22),
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: 20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLabel extends StatelessWidget {
  final String label;
  final bool onDark;
  const _HeroLabel({required this.label, required this.onDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            onDark ? Colors.white.withAlpha(45) : _kPrimary.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: onDark ? Colors.white : _kPrimary,
        ),
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  final bool onDark;
  const _HeroDivider({required this.onDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: onDark ? Colors.white.withAlpha(45) : _kBorder,
    );
  }
}

class _HeroRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool onDark;
  const _HeroRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color labelColor =
        onDark ? Colors.white.withAlpha(190) : _kMuted;
    final Color valueColor = onDark ? Colors.white : _kInk;
    return Row(
      children: [
        Icon(icon, size: 17, color: labelColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _UsageBar extends StatelessWidget {
  final int used;
  final int total;
  final bool onDark;
  const _UsageBar({
    required this.used,
    required this.total,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    final clampedTotal = total <= 0 ? 1 : total;
    final clampedUsed = used.clamp(0, clampedTotal);
    final progress = clampedUsed / clampedTotal;
    final isFull = clampedUsed >= clampedTotal;

    final Color trackColor =
        onDark ? Colors.white.withAlpha(45) : _kBorder;
    final Color fillColor = onDark
        ? Colors.white
        : (isFull ? _kWarning : _kPrimary);
    final Color labelColor =
        onDark ? Colors.white.withAlpha(195) : _kMuted;
    final Color valueColor = onDark ? Colors.white : _kInk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Plazas en uso',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: labelColor,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
                children: [
                  TextSpan(text: '$clampedUsed'),
                  TextSpan(
                    text: ' / $clampedTotal',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(height: 8, color: trackColor),
              FractionallySizedBox(
                widthFactor: progress.isNaN ? 0 : progress.clamp(0.0, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header (above the plans list)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final SubscriptionController controller;
  const _SectionHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = controller.billingStatus.value;
    final isActive = s == 'active' ||
        s == 'in_grace_period' ||
        s == 'in_billing_retry';
    final title = isActive ? 'Cambiar de plan' : 'Elige tu plan';
    final subtitle = isActive
        ? 'Sube o baja de plan en cualquier momento. La facturación se ajusta en la tienda.'
        : 'Paga solo por las plazas adicionales que necesites. Cancela cuando quieras.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kInk,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _kMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plans list
// ─────────────────────────────────────────────────────────────────────────────

class _PlansList extends StatelessWidget {
  final SubscriptionController controller;
  const _PlansList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < IapPlans.all.length; i++) ...[
          _PlanTile(plan: IapPlans.all[i]),
          if (i < IapPlans.all.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  final IapPlan plan;
  const _PlanTile({required this.plan});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SubscriptionController>();
    return Obx(() {
      final ProductDetails? product =
          controller.iapRepository.findProduct(plan.productId);
      final status = controller.billingStatus.value;
      final isCurrent = controller.currentProductId.value == plan.productId &&
          (status == 'active' ||
              status == 'in_grace_period' ||
              status == 'in_billing_retry');
      final hasActive = status == 'active' ||
          status == 'in_grace_period' ||
          status == 'in_billing_retry';
      final isBuying = controller.isBuying.value;
      final price = product?.price ?? '—';
      final priceAvailable = product != null;

      final Color borderColor = isCurrent ? _kPrimary : _kBorder;

      final seatsToFree = controller.seatsToFreeFor(plan);

      Future<void> handleTap() => _onPlanTapped(
            context: context,
            controller: controller,
            plan: plan,
            seatsToFree: seatsToFree,
          );

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isCurrent ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? _kPrimary.withAlpha(20)
                  : Colors.black.withAlpha(5),
              blurRadius: isCurrent ? 18 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: (isCurrent || isBuying || !priceAvailable)
                ? null
                : handleTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SeatBadge(seats: plan.totalSeats, isCurrent: isCurrent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _planTitleForSeats(plan.totalSeats),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: _kInk,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  price,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '/ mes',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: _kMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PlanAction(
                        isCurrent: isCurrent,
                        hasActive: hasActive,
                        disabled: isBuying || !priceAvailable,
                        onTap: handleTap,
                      ),
                    ],
                  ),
                  if (!isCurrent && seatsToFree > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _DowngradeWarning(
                        seatsToFree: seatsToFree,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _SeatBadge extends StatelessWidget {
  final int seats;
  final bool isCurrent;
  const _SeatBadge({required this.seats, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: isCurrent
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kPrimary, _kPrimaryDark],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kPrimary.withAlpha(28),
                  _kPrimary.withAlpha(14),
                ],
              ),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$seats',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isCurrent ? Colors.white : _kPrimary,
          letterSpacing: -0.6,
          height: 1,
        ),
      ),
    );
  }
}

class _PlanAction extends StatelessWidget {
  final bool isCurrent;
  final bool hasActive;
  final bool disabled;
  final VoidCallback onTap;

  const _PlanAction({
    required this.isCurrent,
    required this.hasActive,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: _kSuccess.withAlpha(25),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_rounded, size: 14, color: _kSuccess),
            SizedBox(width: 5),
            Text(
              'Activo',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kSuccess,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: FilledButton(
        onPressed: disabled ? null : onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: _kPrimary,
          disabledBackgroundColor: _kMuted.withAlpha(80),
        ),
        child: Text(
          hasActive ? 'Cambiar' : 'Suscribirse',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manage tile
// ─────────────────────────────────────────────────────────────────────────────

class _ManageTile extends StatelessWidget {
  final VoidCallback onPressed;
  const _ManageTile({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kPrimary.withAlpha(22),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 19,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gestionar suscripción',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cancelar, cambiar método de pago o ver historial',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _kMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: _kMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status chip + visuals
// ─────────────────────────────────────────────────────────────────────────────

class _StatusVisual {
  final String label;
  final Color color;
  const _StatusVisual(this.label, this.color);
}

_StatusVisual _statusVisual(String status) {
  switch (status) {
    case 'active':
      return const _StatusVisual('Activa', _kSuccess);
    case 'in_grace_period':
      return const _StatusVisual('Periodo de gracia', _kWarning);
    case 'in_billing_retry':
      return const _StatusVisual('Reintentando', _kWarning);
    case 'on_hold':
      return const _StatusVisual('Retenida', _kWarning);
    case 'paused':
      return const _StatusVisual('Pausada', _kMuted);
    case 'expired':
      return const _StatusVisual('Caducada', _kDanger);
    case 'revoked':
      return const _StatusVisual('Revocada', _kDanger);
    case 'canceled':
      return const _StatusVisual('Cancelada', _kMuted);
    default:
      return const _StatusVisual('Sin plan', _kMuted);
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool onDark;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withAlpha(45) : color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: onDark ? Colors.white : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: onDark ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert banner
// ─────────────────────────────────────────────────────────────────────────────

enum _AlertTone { warning, danger, neutral }

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool onDark;
  final _AlertTone tone;

  const _AlertBanner({
    required this.icon,
    required this.text,
    required this.onDark,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    Color baseColor;
    switch (tone) {
      case _AlertTone.warning:
        baseColor = _kWarning;
        break;
      case _AlertTone.danger:
        baseColor = _kDanger;
        break;
      case _AlertTone.neutral:
        baseColor = _kSubtle;
        break;
    }

    final Color bg = onDark
        ? Colors.white.withAlpha(38)
        : baseColor.withAlpha(22);
    final Color fg = onDark ? Colors.white : baseColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legal footer
// ─────────────────────────────────────────────────────────────────────────────

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: _kSubtle,
            ),
            const SizedBox(width: 6),
            Text(
              'Pago seguro a través de tu cuenta',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kSubtle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Las suscripciones se renuevan automáticamente. Puedes cancelarlas '
            'cuando quieras desde los Ajustes de tu dispositivo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _kMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading & buying overlays
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _Skeleton(height: 220, radius: 20),
        const SizedBox(height: 24),
        _Skeleton(height: 22, width: 160, radius: 6),
        const SizedBox(height: 8),
        _Skeleton(height: 14, width: 240, radius: 6),
        const SizedBox(height: 16),
        for (int i = 0; i < 4; i++) ...[
          _Skeleton(height: 84, radius: 16),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const _Skeleton({
    required this.height,
    this.width,
    required this.radius,
  });

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final color =
            Color.lerp(const Color(0xffEDEDF2), const Color(0xffE2E2EA), t)!;
        return Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class _BuyingOverlay extends StatelessWidget {
  const _BuyingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withAlpha(80),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(_kPrimary),
                  ),
                ),
                SizedBox(width: 14),
                Text(
                  'Procesando compra…',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _planTitleFor(String productId) {
  final plan = IapPlans.byId(productId);
  if (plan == null) return '—';
  return _planTitleForSeats(plan.totalSeats);
}

String _planTitleForSeats(int seats) {
  return '$seats ${seats == 1 ? 'plaza' : 'plazas'}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan tap → confirma y, si baja de plazas, abre modal de selección
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _onPlanTapped({
  required BuildContext context,
  required SubscriptionController controller,
  required IapPlan plan,
  required int seatsToFree,
}) async {
  if (seatsToFree <= 0) {
    await controller.buyPlan(plan.productId);
    return;
  }

  final selected = await showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SelectEmployeesToDisableSheet(
      plan: plan,
      seatsToFree: seatsToFree,
      controller: controller,
    ),
  );

  if (selected == null || selected.length != seatsToFree) return;

  await controller.downgradeAndBuy(
    productId: plan.productId,
    employeeUidsToDisable: selected,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Aviso de downgrade dentro del plan card
// ─────────────────────────────────────────────────────────────────────────────

class _DowngradeWarning extends StatelessWidget {
  final int seatsToFree;
  const _DowngradeWarning({required this.seatsToFree});

  @override
  Widget build(BuildContext context) {
    final word = seatsToFree == 1 ? 'empleado' : 'empleados';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kWarning.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xffB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tendrás que desactivar $seatsToFree $word para cambiar a este plan.',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xffB45309),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet: selecciona empleados a deshabilitar
// ─────────────────────────────────────────────────────────────────────────────

class _SelectEmployeesToDisableSheet extends StatefulWidget {
  final IapPlan plan;
  final int seatsToFree;
  final SubscriptionController controller;

  const _SelectEmployeesToDisableSheet({
    required this.plan,
    required this.seatsToFree,
    required this.controller,
  });

  @override
  State<_SelectEmployeesToDisableSheet> createState() =>
      _SelectEmployeesToDisableSheetState();
}

class _SelectEmployeesToDisableSheetState
    extends State<_SelectEmployeesToDisableSheet> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final list = widget.controller.billableEmployees
        .where((e) => e.accountStatus != EmployeeAccountStatus.disabled)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final n = widget.seatsToFree;
    final canConfirm = _selected.length == n;
    final word = n == 1 ? 'empleado' : 'empleados';

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecciona $n $word a desactivar',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'El plan ${_planTitleForSeats(widget.plan.totalSeats)} '
                    'no cubre a todos tus empleados actuales. '
                    'Los seleccionados se desactivarán y podrás reactivarlos '
                    'cuando vuelvas a un plan mayor.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _kBorder),
                itemBuilder: (_, i) {
                  final emp = list[i];
                  final isSelected = _selected.contains(emp.uid);
                  final disabled = !isSelected && _selected.length >= n;
                  return _EmployeeRow(
                    employee: emp,
                    isSelected: isSelected,
                    disabled: disabled,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(emp.uid);
                        } else if (_selected.length < n) {
                          _selected.add(emp.uid);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${_selected.length} de $n seleccionados',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kSubtle,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: _kSubtle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canConfirm
                          ? () =>
                              Navigator.of(context).pop(_selected.toList())
                          : null,
                      child: const Text('Continuar y suscribirme'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final EmployeeModel employee;
  final bool isSelected;
  final bool disabled;
  final VoidCallback onTap;

  const _EmployeeRow({
    required this.employee,
    required this.isSelected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = employee.accountStatus == EmployeeAccountStatus.inactive;
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _kPrimary.withAlpha(25),
                backgroundImage: (employee.photoUrl != null &&
                        employee.photoUrl!.isNotEmpty)
                    ? NetworkImage(employee.photoUrl!)
                    : null,
                child: (employee.photoUrl == null ||
                        employee.photoUrl!.isEmpty)
                    ? Text(
                        employee.name.isNotEmpty
                            ? employee.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inactive ? 'Inactivo' : employee.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: inactive ? _kWarning : _kMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SelectionDot(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  final bool isSelected;
  const _SelectionDot({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected ? _kPrimary : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? _kPrimary : _kBorder,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }
}

class _StoreUnavailableBanner extends StatelessWidget {
  final String diagnostic;
  final Future<void> Function() onRetry;

  const _StoreUnavailableBanner({
    required this.diagnostic,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: _kWarning.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kWarning.withAlpha(60), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: Color(0xffB45309),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'No se han podido cargar los planes',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xffB45309),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Comprueba tu conexión y vuelve a intentarlo. '
                      'Si el problema persiste, contacta con soporte.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xffB45309),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (diagnostic.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(140),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                diagnostic,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 11,
                  color: _kInk,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffB45309),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
