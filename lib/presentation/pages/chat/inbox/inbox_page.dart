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
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        title: const Text('Chat interno'),
        titleSpacing: 16,
        elevation: 0,
      ),
      floatingActionButton: Obx(() {
        final contacts = controller.contactList;
        if (contacts.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton(
          heroTag: 'inbox_fab',
          onPressed: () => _showNewChatSheet(context),
          child: const Icon(Icons.edit_rounded, size: 22),
        );
      }),
      body: Column(
        children: [
          _SearchBar(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Get.theme.colorScheme.primary,
                    ),
                  ),
                );
              }

              if (controller.error.value != null) {
                return _ErrorState(message: controller.error.value!);
              }

              final all = controller.conversations.value ?? const <Conversation>[];
              if (all.isEmpty) return const _EmptyInboxState();

              final list = controller.filteredConversations;
              if (list.isEmpty) return const _EmptySearchState();

              // Separar grupos de directos para mostrar grupos arriba
              final groups = list.where((c) => c.isGroup).toList();
              final dms = list.where((c) => !c.isGroup).toList();

              return RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(
                    const Duration(milliseconds: 300),
                  );
                },
                color: Get.theme.colorScheme.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  children: [
                    if (groups.isNotEmpty) ...[
                      const _SectionHeader(label: 'Grupos'),
                      ...groups.map(
                        (c) => _ConversationTile(
                          conversation: c,
                          controller: controller,
                        ),
                      ),
                    ],
                    if (dms.isNotEmpty) ...[
                      if (groups.isNotEmpty) const SizedBox(height: 8),
                      const _SectionHeader(label: 'Directos'),
                      ...dms.map(
                        (c) => _ConversationTile(
                          conversation: c,
                          controller: controller,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showNewChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChatSheet(controller: controller),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(dt.year, dt.month, dt.day);

    if (day == today) return DateFormat('HH:mm').format(dt);
    if (day == yesterday) return 'Ayer';
    if (now.year == dt.year) return DateFormat('dd MMM', 'es_ES').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }
}

// ─────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final InboxController controller;
  const _SearchBar({required this.controller});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: TextField(
        controller: _ctrl,
        onChanged: (v) => widget.controller.searchQuery.value = v,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xff1F2937),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: 'Buscar conversación…',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.tertiary,
            size: 20,
          ),
          suffixIcon: Obx(() {
            if (widget.controller.searchQuery.value.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: theme.colorScheme.tertiary,
              ),
              onPressed: () {
                _ctrl.clear();
                widget.controller.searchQuery.value = '';
              },
            );
          }),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.tertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Conversation tile
// ─────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final InboxController controller;

  const _ConversationTile({
    required this.conversation,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = conversation;
    final title = c.isGroup ? c.title : controller.dmTitle(c);
    final myId = controller.currentUserId.value ?? '';
    final unread = c.unreadFor(myId);
    final hasUnread = unread > 0;
    final isMine = c.lastMessageSenderId == myId;
    final lastTime = c.lastMessageAt ?? c.updatedAt;
    final otherId = controller.otherUserIdOf(c);
    final isDisabled = otherId != null && controller.isUserDisabled(otherId);
    final isDeleted = otherId != null && controller.isUserDeleted(otherId);

    final preview = c.lastMessageText;
    final previewText = preview == null || preview.isEmpty
        ? (c.isGroup
            ? 'Sin mensajes — saluda al equipo'
            : 'Inicia la conversación')
        : (isMine ? 'Tú: $preview' : preview);

    final titleColor = isDisabled
        ? theme.colorScheme.tertiary
        : theme.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => controller.openConversation(c),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasUnread && !isDisabled
                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                    : theme.colorScheme.outline,
                width: hasUnread && !isDisabled ? 1.2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: isDisabled ? 0.5 : 1,
                      child: _ConversationAvatar(
                        conversation: c,
                        title: title,
                      ),
                    ),
                    if (isDisabled)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            isDeleted
                                ? Icons.person_off_rounded
                                : Icons.block_rounded,
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                decoration: isDeleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor:
                                    theme.colorScheme.tertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            InboxPage._formatTime(lastTime),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: hasUnread && !isDisabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.tertiary,
                              fontWeight: hasUnread && !isDisabled
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isDisabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _DisabledChip(isDeleted: isDeleted),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                previewText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: hasUnread
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.tertiary,
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                constraints:
                                    const BoxConstraints(minWidth: 22),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Chip que indica que el otro usuario ya no está operativo.
class _DisabledChip extends StatelessWidget {
  final bool isDeleted;
  const _DisabledChip({required this.isDeleted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDeleted ? Icons.person_off_rounded : Icons.block_rounded,
            size: 11,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 5),
          Text(
            isDeleted ? 'Empleado eliminado' : 'No disponible',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Avatar de conversación
// ─────────────────────────────────────────────

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
      final theme = Theme.of(context);
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.group_rounded,
          color: Colors.white,
          size: 22,
        ),
      );
    }
    return ProfileAvatar(
      imageUrl: conversation.imageUrl,
      name: title,
      uid: Get.find<InboxController>().otherUserIdOf(conversation),
      size: 48,
    );
  }
}

// ─────────────────────────────────────────────
// Empty / error states
// ─────────────────────────────────────────────

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Aún no hay conversaciones',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 16,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Inicia un chat con tu equipo desde el botón “Nuevo”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 44,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin resultados',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(
              'Error al cargar el chat',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sheet: nuevo DM
// ─────────────────────────────────────────────

class _NewChatSheet extends StatelessWidget {
  final InboxController controller;
  const _NewChatSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = controller.contactList;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nueva conversación',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Elige con quién quieres hablar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          if (contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No hay contactos disponibles',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (_, i) {
                  final contact = contacts[i];
                  return ListTile(
                    leading: ProfileAvatar(
                      name: contact.name,
                      uid: contact.id,
                      size: 42,
                    ),
                    title: Text(
                      contact.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.tertiary,
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
