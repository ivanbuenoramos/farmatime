import 'dart:math';

import 'package:flutter/material.dart';

/// Paleta de tonos pastel claros para las imágenes de perfil (avatares).
///
/// El fondo del avatar usa el tono pastel; las iniciales se pintan con un
/// negro semitransparente por encima, lo que produce el efecto de "el mismo
/// tono pero más oscuro" sobre cada pastel, manteniendo buena legibilidad.
class AvatarColors {
  AvatarColors._();

  /// Tonos pastel claros disponibles (valores ARGB).
  static const List<Color> palette = [
    Color(0xFFDCE3FF), // azul lavanda
    Color(0xFFE7DCFF), // lila
    Color(0xFFFFE0E6), // rosa
    Color(0xFFFFE6D2), // melocotón
    Color(0xFFFDEFC8), // amarillo crema
    Color(0xFFD8F3DC), // verde menta
    Color(0xFFCDEDF6), // azul cielo
    Color(0xFFF6D8E8), // rosa malva
    Color(0xFFE3EEDA), // verde salvia
    Color(0xFFFFDFD3), // coral suave
    Color(0xFFD9F0F2), // aguamarina
    Color(0xFFEDE3D4), // beige
  ];

  /// Color de las iniciales derivado del fondo pastel: el mismo matiz pero
  /// notablemente más oscuro y saturado, para el efecto de "mismo tono, más
  /// oscuro" (como en el diseño de referencia).
  static Color initialsColorFor(Color background) {
    final hsl = HSLColor.fromColor(background);
    return hsl
        // Si el pastel está casi desaturado (beige/gris), sube algo el color
        // para que las iniciales tengan matiz; si ya tiene, lo intensifica.
        .withSaturation((hsl.saturation < 0.15 ? 0.25 : hsl.saturation * 1.0)
            .clamp(0.0, 1.0))
        .withLightness(0.34) // suficientemente oscuro para contrastar
        .toColor();
  }

  /// Versión pastel clara de un color (p. ej. el primario de la app), usada
  /// como fallback cuando el empleado no tiene color asignado.
  /// Reduce saturación y sube luminosidad manteniendo el matiz.
  static Color pastelOf(Color color, {double lightness = 0.85}) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + lightness).clamp(0.0, 0.92))
        .toColor();
  }

  /// Devuelve un color aleatorio de la paleta (para asignar al crear).
  static int randomColorValue() {
    final i = Random().nextInt(palette.length);
    return palette[i].toARGB32();
  }

  /// Color estable derivado de una semilla (p. ej. uid o email), como
  /// respaldo determinista cuando no hay color asignado pero sí queremos
  /// variedad. No se usa por defecto (el fallback pedido es el primario).
  static Color fromSeed(String seed) {
    if (seed.isEmpty) return palette.first;
    final hash = seed.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return palette[hash % palette.length];
  }
}
