import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/presentation/widgets/card/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'inbox_controller.dart';

class InboxPage extends GetView<InboxController> {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat interno'),
        titleSpacing: 16,
      ),
      floatingActionButton: Obx(() {
        final contacts = controller.contactList;
        if (contacts.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton(
          heroTag: 'inbox_fab',
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          onPressed: () => _showNewChatSheet(context),
          child: const Icon(Icons.edit_outlined),
        );
      }),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error al cargar el chat: ${controller.error.value}',
                style: Get.theme.textTheme.bodySmall?.copyWith(
                  color: Get.theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final list = controller.conversations.value ?? const <Conversation>[];

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 56,
                  color: Get.theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin conversaciones aún',
                  style: Get.theme.textTheme.bodyMedium?.copyWith(
                    color: Get.theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: list.length,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = list[i];
            final title = c.isGroup ? c.title : controller.dmTitle(c);
            final subtitle = c.lastMessageText ?? '—';

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => controller.openConversation(c),
              child: Ink(
                decoration: BoxDecoration(
                  color: Get.theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Get.theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ConversationAvatar(conversation: c, title: title),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: Get.theme.textTheme.bodyMedium?.copyWith(
                                color: Get.theme.colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: Get.theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(c.updatedAt),
                        style: Get.theme.textTheme.bodySmall?.copyWith(
                          color: Get.theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // ─────────────────────────────────────────────
  // Bottom sheet: nueva conversación
  // ─────────────────────────────────────────────

  void _showNewChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChatSheet(controller: controller),
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(dt.year, dt.month, dt.day);

    if (day == today) return DateFormat('HH:mm').format(dt);
    if (day == yesterday) return 'Ayer';
    if (now.year == dt.year) return DateFormat('dd/MM').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }
}

// ─────────────────────────────────────────────────────────
// Avatar de conversación
// ─────────────────────────────────────────────────────────

class _ConversationAvatar extends StatelessWidget {
  final Conversation conversation;
  final String title;

  const _ConversationAvatar({
    required this.conversation,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (conversation.isGroup) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.group_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      );
    }
    return ProfileAvatar(
      imageUrl: conversation.imageUrl,
      name: title,
      size: 44,
    );
  }
}

// ─────────────────────────────────────────────────────────
// Sheet: seleccionar contacto para nuevo DM
// ─────────────────────────────────────────────────────────

class _NewChatSheet extends StatelessWidget {
  final InboxController controller;

  const _NewChatSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = controller.contactList;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Nueva conversación',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          if (contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No hay contactos disponibles',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: contacts.length,
                itemBuilder: (_, i) {
                  final contact = contacts[i];
                  return ListTile(
                    leading: ProfileAvatar(
                      name: contact.name,
                      size: 42,
                    ),
                    title: Text(
                      contact.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Get.back();
                      controller.openDirectConversation(contact.id);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
