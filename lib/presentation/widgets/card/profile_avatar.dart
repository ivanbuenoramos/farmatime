import 'package:farmatime/core/app/brain.dart';
import 'package:farmatime/core/utils/avatar_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  /// Color base (ARGB) asignado al empleado. Si es null, se intenta resolver
  /// por [uid] desde Brain; si tampoco, se usa el color primario del tema
  /// (empleados antiguos sin color asignado).
  final int? colorValue;

  /// uid del empleado, para resolver su color desde Brain cuando no se pasa
  /// [colorValue] explícito. Permite que cualquier avatar refleje el color.
  final String? uid;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 45,
    this.colorValue,
    this.uid,
  });

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  /// Color efectivo: el explícito o el resuelto por uid desde Brain.
  int? get _effectiveColor =>
      colorValue ?? Get.find<Brain>().avatarColorForUid(uid);

  String get _initials {
    if (name.trim().isEmpty) return '?';

    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }

    final first = parts.first[0].toUpperCase();
    final last = parts.last[0].toUpperCase();
    return '$first$last';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // Con color asignado: ese tono pastel.
    // Sin color: pastel claro derivado del color primario de la app.
    // Las iniciales son el mismo matiz del fondo pero más oscuro y saturado.
    final int? effectiveColor = _effectiveColor;
    final Color bgColor = effectiveColor != null
        ? Color(effectiveColor)
        : AvatarColors.pastelOf(primary);
    final Color initialsColor = AvatarColors.initialsColorFor(bgColor);

    final textStyle = TextStyle(
      color: initialsColor,
      fontWeight: FontWeight.w700,
      fontSize: size * 0.38,
      letterSpacing: 0.2,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: size * 0.02,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: _hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) =>
                  Center(child: Text(_initials, style: textStyle)),
            )
          : Text(_initials, style: textStyle),
    );
  }
}
