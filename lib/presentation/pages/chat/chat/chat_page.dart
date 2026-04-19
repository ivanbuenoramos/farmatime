import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:farmatime/presentation/widgets/chat/day_separator.dart';
import 'package:farmatime/presentation/widgets/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'chat_controller.dart';

class ChatPage extends GetView<ChatController> {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Obx(() {
          final conv = controller.conversation.value;
          final name = controller.displayName.value?.isNotEmpty == true
              ? controller.displayName.value!
              : conv?.title.isNotEmpty == true
                  ? conv!.title
                  : 'Chat';
          final isGroup = conv?.isGroup ?? false;

          return Row(
            children: [
              isGroup
                  ? CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.group_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    )
                  : ProfileAvatar(
                      imageUrl: conv?.imageUrl,
                      name: name,
                      size: 36,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final list =
                  controller.messages.value ?? const <ChatMessage>[];
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'Sin mensajes aún',
                    style: Get.theme.textTheme.bodyMedium?.copyWith(
                      color: Get.theme.colorScheme.outline,
                    ),
                  ),
                );
              }
              final items = _buildItemsWithSeparators(list);
              return ListView.builder(
                reverse: true,
                controller: controller.scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item is _DaySep) return DaySeparator(day: item.day);
                  final msg = item as ChatMessage;
                  return MessageBubble(
                    message: msg,
                    isMine: msg.senderId == controller.currentUserId.value,
                  );
                },
              );
            }),
          ),
          _Composer(
            onSend: controller.send,
            isSending: controller.isSending,
          ),
        ],
      ),
    );
  }

  List<Object> _buildItemsWithSeparators(List<ChatMessage> desc) {
    final out = <Object>[];
    DateTime? currentDay;

    for (final m in desc) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);

      if (currentDay == null) {
        currentDay = d;
      } else {
        final sameDay = d.year == currentDay.year &&
            d.month == currentDay.month &&
            d.day == currentDay.day;
        if (!sameDay) {
          out.add(_DaySep(currentDay));
          currentDay = d;
        }
      }
      out.add(m);
    }

    if (currentDay != null) out.add(_DaySep(currentDay));
    return out;
  }
}

class _DaySep {
  final DateTime day;
  _DaySep(this.day);
}

// ─────────────────────────────────────────────
// Composer (campo de texto + botón enviar)
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend(String v) async {
    final text = v.trim();
    if (text.isEmpty) return;
    await widget.onSend(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: _handleSend,
                    textInputAction: TextInputAction.newline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje…',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide:
                            BorderSide(color: theme.colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    minLines: 1,
                    maxLines: 6,
                  ),
                ),
              ),
            ),
            Obx(() {
              final sending = widget.isSending.value;
              return Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 8),
                child: GestureDetector(
                  onTap: sending ? null : () => _handleSend(_ctrl.text),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sending
                          ? theme.colorScheme.primary.withValues(alpha: 0.4)
                          : theme.colorScheme.primary,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: theme.colorScheme.onPrimary,
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
