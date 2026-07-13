import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  /// Mostrar el nombre del remitente sobre la burbuja (grupos, primer mensaje del bloque)
  final String? senderName;

  /// Mostrar el avatar a la izquierda (último mensaje del bloque del otro)
  final bool showAvatar;

  /// El primer mensaje de un bloque consecutivo del mismo remitente
  final bool isFirstInGroup;

  /// El último mensaje del bloque (define la "cola" del bubble y la hora)
  final bool isLastInGroup;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.senderName,
    this.showAvatar = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat('HH:mm').format(message.createdAt);

    final bgColor = isMine
        ? theme.colorScheme.primary
        : Colors.white;
    final textColor = isMine
        ? theme.colorScheme.onPrimary
        : const Color(0xff1F2937);

    const radiusLarge = Radius.circular(18);
    const radiusSmall = Radius.circular(6);

    final borderRadius = BorderRadius.only(
      topLeft: !isMine && !isFirstInGroup ? radiusSmall : radiusLarge,
      topRight: isMine && !isFirstInGroup ? radiusSmall : radiusLarge,
      bottomLeft: !isMine && isLastInGroup ? radiusSmall : radiusLarge,
      bottomRight: isMine && isLastInGroup ? radiusSmall : radiusLarge,
    );

    final bubble = Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: isMine
            ? null
            : Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.6),
              ),
        boxShadow: isMine
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (senderName != null && !isMine && isFirstInGroup) ...[
            Text(
              senderName!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          if (isLastInGroup) ...[
            const SizedBox(height: 2),
            Text(
              time,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.85)
                    : theme.colorScheme.tertiary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    final avatarSlot = SizedBox(
      width: 32,
      child: showAvatar && !isMine
          ? ProfileAvatar(
              name: senderName ?? '?',
              uid: message.senderId,
              size: 28,
            )
          : null,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 56 : 8,
        right: isMine ? 8 : 56,
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 4 : 0,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[avatarSlot, const SizedBox(width: 6)],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
