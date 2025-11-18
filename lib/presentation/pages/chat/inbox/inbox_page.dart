import 'package:farmatime/core/routes/routes.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'inbox_controller.dart';
import 'package:farmatime/data/models/chat/chat_models.dart';



class InboxPage extends GetView<InboxController> {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat interno'),
        titleSpacing: 16,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = controller.conversations.value ?? const <Conversation>[];
        if (list.isEmpty) return const Center(child: Text('Sin conversaciones'));

        return ListView.separated(
          itemCount: list.length,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final c = list[i];
            return InkWell(
              onTap: () {
                Get.toNamed(
                  Routes.chat,
                  arguments: {
                    'conversation': c,
                    'currentUserId': controller.currentUserId.value,
                  }
                );
              },
              child: Ink(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ProfileAvatar(
                          imageUrl: c.imageUrl,
                          name: c.title,
                          size: 45,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.title.isEmpty ? _titleFromMembers(c, controller.currentUserId.value!) : c.title,
                                style: Get.theme.textTheme.bodyMedium?.copyWith(
                                  color: Get.theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w600
                                )
                              ),
                              Text(
                                c.lastMessageText ?? '—',
                                style: Get.theme.textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatLastMessageTime(c.updatedAt),
                          style: Get.theme.textTheme.bodySmall,
                        ), 
                      ],
                    ),
                  ),
                ),
              ),
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