import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/presentation/pages/company/profile/company_profile_controller.dart';
import 'package:farmatime/presentation/widgets/card/base_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CompanyProfilePage extends GetView<CompanyProfileController> {
  const CompanyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de farmacia'),
        titleSpacing: 16,
      ),
      bottomNavigationBar: const _SaveBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            const _LogoHeader(),
            const SizedBox(height: 20),
            _AddressCard(controller: controller),
            const SizedBox(height: 12),
            _CompanyDataCard(controller: controller),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// CABECERA: LOGO + NOMBRE
// =====================================================================

class _LogoHeader extends GetView<CompanyProfileController> {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final hasLogo = controller.logoUrl.value.isNotEmpty;

      return Column(
        children: [
          Stack(
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  border: Border.all(color: theme.colorScheme.outline, width: 2),
                  image: hasLogo
                      ? DecorationImage(
                          image: NetworkImage(controller.logoUrl.value),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasLogo
                    ? Icon(
                        Icons.local_pharmacy_rounded,
                        size: 44,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              if (controller.isUploadingLogo.value)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.35),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: controller.isUploadingLogo.value
                      ? null
                      : controller.pickLogo,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            controller.nameController.text.isEmpty
                ? 'Tu farmacia'
                : controller.nameController.text,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            controller.emailController.text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
      );
    });
  }
}

// =====================================================================
// TARJETA: DIRECCIÓN
// =====================================================================

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.controller});
  final CompanyProfileController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseCard(
      children: [
        const _CardHeader(
          icon: Icons.location_on_outlined,
          title: 'Dirección de la empresa',
        ),
        Text(
          'Asegúrate de que la dirección es correcta para que los empleados puedan encontrar tu farmacia.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Dirección',
          controller: controller.addressController,
          icon: Icons.signpost_outlined,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Ciudad',
                controller: controller.cityController,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LabeledField(
                label: 'Código Postal',
                controller: controller.postalCodeController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Provincia',
                controller: controller.provinceController,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _LabeledField(
                label: 'País',
                hintText: 'España',
                enabled: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =====================================================================
// TARJETA: DATOS DE LA EMPRESA
// =====================================================================

class _CompanyDataCard extends StatelessWidget {
  const _CompanyDataCard({required this.controller});
  final CompanyProfileController controller;

  @override
  Widget build(BuildContext context) {
    final verifiedEmail =
        controller.brain.company.value?.verifiedEmail ?? false;

    return BaseCard(
      children: [
        const _CardHeader(
          icon: Icons.storefront_outlined,
          title: 'Datos de la empresa',
        ),
        _LabeledField(
          label: 'Nombre de la empresa',
          controller: controller.nameController,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 14),
        _LabeledField(
          label: 'CIF',
          controller: controller.cifController,
          icon: Icons.tag_rounded,
        ),
        const SizedBox(height: 14),
        _LabeledField(
          label: 'Email',
          controller: controller.emailController,
          icon: Icons.mail_outline_rounded,
          enabled: false,
          trailing: _EmailStatusChip(
            verified: verifiedEmail,
            onVerify: () => Get.toNamed(Routes.companyAuthVerifyEmail),
          ),
        ),
        const SizedBox(height: 14),
        _LabeledField(
          label: 'Teléfono',
          controller: controller.phoneController,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}

// =====================================================================
// WIDGETS COMPARTIDOS
// =====================================================================

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Campo de texto con etiqueta encima (estilo limpio), opcionalmente con
/// icono inicial y un widget a la derecha (p. ej. chip de estado).
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    this.controller,
    this.icon,
    this.trailing,
    this.hintText,
    this.enabled = true,
    this.keyboardType,
  });

  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final Widget? trailing;
  final String? hintText;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.secondary,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            fillColor: enabled
                ? theme.colorScheme.surface
                : theme.colorScheme.outline.withOpacity(0.25),
            prefixIcon: icon != null
                ? Icon(icon, size: 19, color: theme.colorScheme.tertiary)
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmailStatusChip extends StatelessWidget {
  const _EmailStatusChip({required this.verified, required this.onVerify});
  final bool verified;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        verified ? const Color(0xff16A34A) : const Color(0xffF59E0B);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified
                ? Icons.verified_rounded
                : Icons.error_outline_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verificado' : 'Verificar',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (verified) return chip;
    return GestureDetector(onTap: onVerify, child: chip);
  }
}

// =====================================================================
// BARRA INFERIOR: GUARDAR
// =====================================================================

class _SaveBar extends GetView<CompanyProfileController> {
  const _SaveBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        child: Obx(
          () => FilledButton(
            onPressed: controller.isLoading.value ? null : controller.saveChanges,
            child: controller.isLoading.value
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator.adaptive(),
                  )
                : const Text('Guardar cambios'),
          ),
        ),
      ),
    );
  }
}
