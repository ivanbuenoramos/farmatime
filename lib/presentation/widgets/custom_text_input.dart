import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Un TextField altamente personalizable con label/sublabel, iconos SVG,
/// estados de error, contador opcional y estilos de borde configurables.
class CustomTextInput extends StatefulWidget {
  // Core
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final int? maxLines; // si > 1, se ignora [height]
  final int? minLines;
  final int? maxLength;
  final bool showCounter; // si false, oculta el contador

  // Layout & style
  final double? height; // útil para 1 línea
  final EdgeInsetsGeometry? contentPadding;
  final double borderWidth;
  final double focusedBorderWidth;
  final double borderRadius;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? textColor;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final TextStyle? labelStyle;
  final TextStyle? sublabelStyle;

  // Labels
  final String? label;
  final String? sublabel;
  final String? hintText;
  final String? errorText;

  // Icons (elige path SVG o widget)
  final String? prefixSvgAsset;
  final String? suffixSvgAsset;
  final Widget? prefix;
  final Widget? suffix;

  // Callbacks
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  const CustomTextInput({
    Key? key,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter = true,
    this.height = 48,
    this.contentPadding,
    this.borderWidth = 0.5,
    this.focusedBorderWidth = 1.0,
    this.borderRadius = 10,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.textColor,
    this.textStyle,
    this.hintStyle,
    this.labelStyle,
    this.sublabelStyle,
    this.label,
    this.sublabel,
    this.hintText,
    this.errorText,
    this.prefixSvgAsset,
    this.suffixSvgAsset,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  }) : super(key: key);

  @override
  State<CustomTextInput> createState() => _CustomTextInputState();
}

class _CustomTextInputState extends State<CustomTextInput> {
  // Nota: NO se dispone [focusNode] pasado desde fuera. El owner externo
  // es responsable de su ciclo de vida. Aquí no lo tocamos en dispose().

  OutlineInputBorder _border({required Color color, required double width}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget? _buildPrefix(ThemeData theme) {
    if (widget.prefix != null) return widget.prefix;
    if (widget.prefixSvgAsset != null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: SvgPicture.asset(
          widget.prefixSvgAsset!,
          colorFilter: ColorFilter.mode(
            (widget.borderColor ?? theme.colorScheme.tertiary),
            BlendMode.srcIn,
          ),
          width: 20,
          height: 20,
        ),
      );
    }
    return null;
  }

  Widget? _buildSuffix(ThemeData theme) {
    if (widget.suffix != null) return widget.suffix;
    if (widget.suffixSvgAsset != null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: SvgPicture.asset(
          widget.suffixSvgAsset!,
          colorFilter: ColorFilter.mode(
            (widget.borderColor ?? theme.colorScheme.tertiary),
            BlendMode.srcIn,
          ),
          width: 20,
          height: 20,
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color effectiveBorder = widget.borderColor ?? theme.colorScheme.tertiary;
    final Color effectiveFocused =
        widget.focusedBorderColor ?? theme.colorScheme.primary;
    final Color effectiveFill = widget.fillColor ?? theme.colorScheme.surface;
    final TextStyle effectiveTextStyle = (widget.textStyle ?? theme.textTheme.bodyMedium!)
        .copyWith(color: widget.textColor);

    final bool isMultiline = (widget.maxLines ?? 1) > 1;

    final input = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      selectionHeightStyle: BoxHeightStyle.includeLineSpacingMiddle,
      style: effectiveTextStyle,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: effectiveFill,
        hintText: widget.hintText,
        hintStyle: widget.hintStyle ?? theme.textTheme.bodyMedium,
        errorText: widget.errorText,
        counterText: widget.showCounter ? null : '',
        contentPadding: widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: _buildPrefix(theme),
        suffixIcon: _buildSuffix(theme),
        enabledBorder: _border(color: effectiveBorder, width: widget.borderWidth),
        border: _border(color: effectiveBorder, width: widget.borderWidth),
        focusedBorder: _border(color: effectiveFocused, width: widget.focusedBorderWidth),
        disabledBorder: _border(color: effectiveBorder.withOpacity(0.4), width: widget.borderWidth),
        errorBorder: _border(color: theme.colorScheme.error, width: widget.focusedBorderWidth),
        focusedErrorBorder: _border(color: theme.colorScheme.error, width: widget.focusedBorderWidth),
      ),
    );

    final label = (widget.label == null)
        ? null
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.label!,
                style: widget.labelStyle ?? theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              if (widget.sublabel != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.sublabel!,
                  style: widget.sublabelStyle ?? theme.textTheme.bodySmall,
                ),
              ]
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          label,
          const SizedBox(height: 6),
        ],
        if (isMultiline || widget.height == null)
          input
        else
          SizedBox(height: widget.height, child: Center(child: input)),
      ],
    );
  }
}
