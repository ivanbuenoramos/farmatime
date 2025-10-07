import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'inbox_controller.dart';


class InboxPage extends GetView<InboxController> {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat interno')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = controller.conversations.value ?? const <Conversation>[];
        if (list.isEmpty) return const Center(child: Text('Sin conversaciones'));

        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = list[i];
            return ListTile(
              leading: const CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(
                  'https://randomuser.me/api/portraits/men/32.jpg',
                ),
              ),
              title: Text(
                c.title.isEmpty ? _titleFromMembers(c, controller.currentUserId.value!) : c.title,
                style: Get.theme.textTheme.bodyMedium?.copyWith(
                  color: Get.theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600
                )
              ),
              subtitle: Text(
                c.lastMessageText ?? '—',
                style: Get.theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                formatLastMessageTime(c.updatedAt),
                style: Get.theme.textTheme.bodySmall,
              ), 
              onTap: () {
                Get.toNamed(
                  Routes.chat,
                  arguments: {
                    'conversation': c,
                    'currentUserId': controller.currentUserId.value,
                  }
                );
              }
            );
          },
        );
      }),
    );
  }

  String _titleFromMembers(Conversation c, String me) {
    // Si 1:1 y title vacío, muestra el otro userId (reemplazar por nombre real si lo resuelves)
    if (!c.isGroup && c.memberIds.length == 2) {
      return c.memberIds.first == me ? c.memberIds.last : c.memberIds.first;
    }
    return c.title;
  }

  static String formatLastMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final msgDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (msgDay == today) {
      // Hoy → muestra solo la hora
      return DateFormat('HH:mm').format(dateTime);
    } else if (msgDay == yesterday) {
      // Ayer → literal
      return 'Ayer';
    } else if (now.year == dateTime.year) {
      // Este año → muestra solo día y mes
      return DateFormat('dd/MM').format(dateTime);
    } else {
      // Otro año → muestra día/mes/año
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }
}