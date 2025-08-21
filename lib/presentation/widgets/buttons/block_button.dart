import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:smooth_corner/smooth_corner.dart';

// ignore: must_be_immutable
class BlockButton extends StatelessWidget {

  final Function()? onPressed;
  final String label;
  final Color? color;
  final double? borderRadius;
  final String? assetPath;
  final BorderSide side;
  final TextStyle? textStyle;
  final bool enabled;
  bool loading;
  final String? loadingLabel;
  final double? height;

  BlockButton({
    required this.onPressed,
    required this.label,
    this.color,
    this.borderRadius,
    this.assetPath,
    this.textStyle,
    this.enabled = true,
    this.loading = false,
    this.loadingLabel,
    this.side = BorderSide.none,
    this.height,
    super.key
  });

  @override
  Widget build(BuildContext context) {

    double opacity = enabled && onPressed != null ? 1 : 0.5;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(borderRadius ?? 10),
          child: Ink(
            height: height ?? 45,
            width: double.infinity,
            decoration: ShapeDecoration(
              color: color ?? Get.theme.colorScheme.primary,
              shape: SmoothRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 10),
                side: side,
                smoothness: 1,
              )
            ),
            child: loading
              ? const Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (assetPath != null)...[
                    SvgPicture.asset(
                      assetPath!,
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: textStyle ?? const TextStyle(
                      color: Colors.white,
                      letterSpacing: -0.3,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          ),
        ),
      ),
    );
  }
}