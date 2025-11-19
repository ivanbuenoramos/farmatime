import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 45,
  });

  bool get _hasImage =>
      imageUrl != null &&
      imageUrl!.trim().isNotEmpty;

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
    final textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: size * 0.4,
    );

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: _hasImage ? null : Theme.of(context).colorScheme.primary,
        child: _hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  // Si falla la imagen, mostramos las iniciales
                  return Center(child: Text(_initials, style: textStyle));
                },
              )
            : Center(
                child: Text(
                  _initials,
                  style: textStyle,
                ),
              ),
      ),
    );
  }
}