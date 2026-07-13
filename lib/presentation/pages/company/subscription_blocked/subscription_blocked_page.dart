import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:farmatime/core/iap/iap_plans.dart';
import 'package:farmatime/presentation/pages/company/subscription/subscription_controller.dart';

import 'subscription_blocked_controller.dart';

const Color _kPrimary = Color(0xff1971FF);
const Color _kPrimaryDark = Color(0xff0B4FCC);
const Color _kInk = Color(0xff373737);
const Color _kMuted = Color(0xffA5A5A5);
const Color _kSubtle = Color(0xff737373);
const Color _kBorder = Color(0xffE5E5E5);
const Color _kSurface = Color(0xffFFFFFF);
const Color _kCanvas = Color(0xffF5F5F8);
const Color _kDanger = Color(0xffFF0004);

/// Pantalla bloqueante para cuentas de farmacia con la suscripción
/// cancelada/expirada/revocada. No deja navegar al resto de la app:
/// solo permite renovar o cerrar sesión. Cuando el listener detecta que
/// la suscripción vuelve a estar activa, [SubscriptionBlockedController]
/// redirige automáticamente a la app principal.
class SubscriptionBlockedPage extends StatelessWidget {
  const SubscriptionBlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SubscriptionBlockedController blocked =
        Get.find<SubscriptionBlockedController>();
    final SubscriptionController sub = Get.find<SubscriptionController>();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _kCanvas,
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const _BlockedHero(),
                  const SizedBox(height: 22),
                  Obx(() {
                    if (sub.isLoading.value) {
                      return const _PlansSkeleton();
                    }
                    return _PlansList(controller: sub);
                  }),
                  const SizedBox(height: 18),
                  _LogoutTile(onTap: blocked.logOut),
                  const SizedBox(height: 16),
                  const _LegalNote(),
                ],
              ),
              Obx(() {
                if (!sub.isBuying.value) return const SizedBox.shrink();
                return const _BuyingOverlay();
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedHero extends StatelessWidget {
  const _BlockedHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimary, _kPrimaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withAlpha(60),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tu suscripción no está activa',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Para volver a usar farmatime, renueva tu suscripción. Tus datos '
            'y los de tus empleados están a salvo.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(220),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlansList extends StatelessWidget {
  final SubscriptionController controller;
  const _PlansList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Renueva eligiendo un plan',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kInk,
              letterSpacing: -0.3,
            ),
          ),
        ),
        for (int i = 0; i < IapPlans.all.length; i++) ...[
          _PlanTile(plan: IapPlans.all[i], controller: controller),
          if (i < IapPlans.all.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  final IapPlan plan;
  final SubscriptionController controller;
  const _PlanTile({required this.plan, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ProductDetails? product =
          controller.iapRepository.findProduct(plan.productId);
      final isBuying = controller.isBuying.value;
      final price = product?.price ?? '—';
      final priceAvailable = product != null;

      return Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: (isBuying || !priceAvailable)
                ? null
                : () => controller.buyPlan(plan.productId),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  _SeatBadge(seats: plan.totalSeats),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${plan.totalSeats} ${plan.totalSeats == 1 ? 'plaza' : 'plazas'}',
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
                  SizedBox(
                    height: 38,
                    child: FilledButton(
                      onPressed: (isBuying || !priceAvailable)
                          ? null
                          : () => controller.buyPlan(plan.productId),
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
                      child: const Text(
                        'Renovar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
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
  const _SeatBadge({required this.seats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimary.withAlpha(28), _kPrimary.withAlpha(14)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$seats',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _kPrimary,
          letterSpacing: -0.6,
          height: 1,
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kDanger.withAlpha(20),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 19,
                  color: _kDanger,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _kMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'El pago se procesa a través de tu cuenta de la App Store o '
        'Google Play. Las suscripciones se renuevan automáticamente.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: _kSubtle,
          height: 1.5,
        ),
      ),
    );
  }
}

class _PlansSkeleton extends StatelessWidget {
  const _PlansSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < 4; i++) ...[
          Container(
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xffEDEDF2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          if (i < 3) const SizedBox(height: 10),
        ],
      ],
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
