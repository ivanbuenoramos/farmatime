import 'package:farmatime/core/services/toast_service.dart';
import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:farmatime/presentation/widgets/chat/day_separator.dart';
import 'package:farmatime/presentation/widgets/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'chat_controller.dart';

class ChatPage extends GetView<ChatController> {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        title: Obx(() {
          final conv = controller.conversation.value;
          final name = controller.displayName.value?.isNotEmpty == true
              ? controller.displayName.value!
              : conv?.title.isNotEmpty == true
                  ? conv!.title
                  : 'Chat';
          final isGroup = conv?.isGroup ?? false;
          final memberCount = conv?.memberIds.length ?? 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _ChatAppBarAvatar(isGroup: isGroup, name: name, imageUrl: conv?.imageUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isGroup && memberCount > 0)
                        Text(
                          '$memberCount miembros',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Obx(() {
                    final list =
                        controller.messages.value ?? const <ChatMessage>[];
                    if (controller.messages.value == null) {
                      return Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    }
                    if (list.isEmpty) {
                      return _EmptyChatState(
                        isGroup: controller.conversation.value?.isGroup ?? false,
                      );
                    }

                    final items = _buildItemsWithSeparators(list);
                    final me = controller.currentUserId.value;
                    final isGroup =
                        controller.conversation.value?.isGroup ?? false;

                    return ListView.builder(
                      reverse: true,
                      controller: controller.scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        if (item is _DaySep) return DaySeparator(day: item.day);
                        final entry = item as _MsgEntry;
                        final msg = entry.message;
                        final isMine = msg.senderId == me;
                        return MessageBubble(
                          message: msg,
                          isMine: isMine,
                          senderName: isGroup && !isMine
                              ? controller.nameForUser(msg.senderId)
                              : null,
                          showAvatar: isGroup && entry.isLastInGroup,
                          isFirstInGroup: entry.isFirstInGroup,
                          isLastInGroup: entry.isLastInGroup,
                        );
                      },
                    );
                  }),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Obx(() {
                      if (!controller.showScrollToBottom.value) {
                        return const SizedBox.shrink();
                      }
                      return _ScrollToBottomButton(
                        onTap: controller.scrollToBottom,
                      );
                    }),
                  ),
                ],
              ),
            ),
            Obx(() {
              if (controller.isOtherUserDisabled) {
                return _DisabledBanner(reason: controller.disabledReason);
              }
              return _Composer(
                onSend: controller.send,
                isSending: controller.isSending,
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Object> _buildItemsWithSeparators(List<ChatMessage> desc) {
    // `desc` viene en orden descendente (más reciente primero)
    final out = <Object>[];
    DateTime? currentDay;

    for (var i = 0; i < desc.length; i++) {
      final m = desc[i];
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);

      // En lista reverse, el "anterior visualmente" (arriba) es el siguiente del array
      final prev = i + 1 < desc.length ? desc[i + 1] : null;
      final next = i - 1 >= 0 ? desc[i - 1] : null;

      // Cambio de día → insertar separador antes (en lista reverse, lo añadimos al `out` después
      // del último mensaje del día)
      if (currentDay != null && d != currentDay) {
        out.add(_DaySep(currentDay));
      }
      currentDay = d;

      // Agrupación: mismo remitente y dentro de un margen razonable de tiempo (≤ 5 min)
      const groupingWindow = Duration(minutes: 5);
      final isFirstInGroup = prev == null ||
          prev.senderId != m.senderId ||
          m.createdAt.difference(prev.createdAt).abs() > groupingWindow ||
          DateTime(prev.createdAt.year, prev.createdAt.month,
                  prev.createdAt.day) !=
              d;
      final isLastInGroup = next == null ||
          next.senderId != m.senderId ||
          next.createdAt.difference(m.createdAt).abs() > groupingWindow ||
          DateTime(next.createdAt.year, next.createdAt.month,
                  next.createdAt.day) !=
              d;

      out.add(_MsgEntry(
        message: m,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
      ));
    }

    if (currentDay != null) out.add(_DaySep(currentDay));
    return out;
  }
}

class _DaySep {
  final DateTime day;
  _DaySep(this.day);
}

class _MsgEntry {
  final ChatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  _MsgEntry({
    required this.message,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });
}

// ─────────────────────────────────────────────
// Avatar AppBar
// ─────────────────────────────────────────────

class _ChatAppBarAvatar extends StatelessWidget {
  final bool isGroup;
  final String name;
  final String? imageUrl;

  const _ChatAppBarAvatar({
    required this.isGroup,
    required this.name,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (isGroup) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: const Icon(
          Icons.group_rounded,
          color: Colors.white,
          size: 20,
        ),
      );
    }
    return ProfileAvatar(imageUrl: imageUrl, name: name, size: 36);
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────

class _EmptyChatState extends StatelessWidget {
  final bool isGroup;
  const _EmptyChatState({required this.isGroup});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGroup
                  ? Icons.forum_outlined
                  : Icons.chat_bubble_outline_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isGroup ? 'Inicia la conversación' : 'Aún no hay mensajes',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 16,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              isGroup
                  ? 'Sé el primero en escribir al equipo.'
                  : 'Envía un mensaje para empezar a conversar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Scroll to bottom
// ─────────────────────────────────────────────

class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScrollToBottomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Banner cuando el otro usuario no está operativo
// ─────────────────────────────────────────────

class _DisabledBanner extends StatelessWidget {
  final String reason;
  const _DisabledBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomInset),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_off_rounded,
              size: 18,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No puedes enviar mensajes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontSize: 12.5,
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

// ─────────────────────────────────────────────
// Composer
// ─────────────────────────────────────────────

class _Composer extends StatefulWidget {
  final Future<void> Function(String) onSend;
  final RxBool isSending;

  const _Composer({required this.onSend, required this.isSending});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      await widget.onSend(text);
      _ctrl.clear();
    } catch (_) {
      ToastService().show(
        title: 'Error',
        message: 'No se pudo enviar el mensaje',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff1F2937),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xffF1F3F7),
                      hintText: 'Escribe un mensaje…',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final sending = widget.isSending.value;
                final enabled = _hasText && !sending;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: enabled ? _handleSend : null,
                      child: Center(
                        child: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                size: 20,
                                color: enabled
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
  }
}
