import 'package:flutter/material.dart';

import 'package:farmatime/core/legal_links.dart';

/// Enlaces a términos de uso y política de privacidad.
///
/// Obligatorio mostrarlos junto a cualquier oferta de suscripción
/// (App Store guideline 3.1.2 / Google Play).
class LegalLinksRow extends StatelessWidget {
  final Color? color;
  final double fontSize;

  const LegalLinksRow({super.key, this.color, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final linkColor = color ?? Theme.of(context).colorScheme.primary;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        _LegalLink(
          label: 'Términos de uso',
          color: linkColor,
          fontSize: fontSize,
          onTap: LegalLinks.openTermsOfUse,
        ),
        Text(
          '·',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: fontSize,
            color: linkColor.withOpacity(0.6),
          ),
        ),
        _LegalLink(
          label: 'Política de privacidad',
          color: linkColor,
          fontSize: fontSize,
          onTap: LegalLinks.openPrivacyPolicy,
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final VoidCallback onTap;

  const _LegalLink({
    required this.label,
    required this.color,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}
