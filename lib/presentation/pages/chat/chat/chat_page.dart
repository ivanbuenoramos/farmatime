import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/presentation/widgets/chat/day_separator.dart';
import 'package:farmatime/presentation/widgets/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'chat_controller.dart';

class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChatController>(
      builder: (controller) {
        final conv = controller.conversation.value;
        final title = (conv?.title.isNotEmpty ?? false) ? conv!.title : 'Chat';

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    'https://randomuser.me/api/portraits/men/32.jpg',
                  ),
                ),
                const SizedBox(width: 10),
                Text(title),
              ],
            )
          ),
          body: Column(
            children: [
              Expanded(
                child: Obx(() {
                  final list = controller.messages.value ?? const <ChatMessage>[];
                  if (list.isEmpty) {
                    return const Center(child: Text('Sin mensajes'));
                  }
                  final items = _itemsWithSeparators(list);
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      if (item is _DaySep) {
                        return DaySeparator(day: item.day);
                      }
                      final msg = item as ChatMessage;
                      final myId = controller.currentUserId.value;
                      return MessageBubble(
                        message: msg,
                        isMine: msg.senderId == myId, // <-- clave
                      );
                    },
                  );
                }),
              ),
              _Composer(onSend: controller.send, isSending: controller.isSending),
            ],
          ),
        );
      },
    );
  }

  List<Object> _itemsWithSeparators(List<ChatMessage> desc) {
    final out = <Object>[];
    DateTime? currentDay; // día "abierto" cuyas burbujas estamos acumulando

    for (final m in desc) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);

      if (currentDay == null) {
        currentDay = d;
      } else {
        final sameDay = d.year == currentDay.year &&
            d.month == currentDay.month &&
            d.day == currentDay.day;
        if (!sameDay) {
          // Cerramos el día anterior insertando su separador
          out.add(_DaySep(currentDay));
          currentDay = d;
        }
      }

      out.add(m); // añadimos el mensaje
    }

    // Cierra el último día pendiente
    if (currentDay != null) {
      out.add(_DaySep(currentDay));
    }

    return out;
  }
}

class _DaySep {
  final DateTime day;
  _DaySep(this.day);
}

// Resto del _Composer igual que lo tenías

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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                constraints: BoxConstraints(
                  maxHeight: 200,

                ),
                child: TextField(
                  scrollPadding: EdgeInsets.zero,
                  controller: _ctrl,
                  // onSubmitted: _handleSend,
                  style: Get.theme.textTheme.bodyMedium?.copyWith(
                    color: Get.theme.colorScheme.secondary
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje…',
                    hintStyle: Get.theme.textTheme.bodyMedium,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Get.theme.colorScheme.outline,
                      )
                    ),
                  ),
                  minLines: 1,
                  maxLines: 100,
                ),
              ),
            ),
            Obx(() => GestureDetector(
              onTap: widget.isSending.value
                ? null
                : () => _handleSend(_ctrl.text),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Get.theme.colorScheme.primary,
                ),
                child: Icon(
                  Icons.send_rounded, 
                  color: Get.theme.colorScheme.onPrimary
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _handleSend(String v) async {
    final text = v.trim();
    if (text.isEmpty) return;
    await widget.onSend(text);
    _ctrl.clear();
  }
}
