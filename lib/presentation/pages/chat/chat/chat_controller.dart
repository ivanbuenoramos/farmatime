import 'dart:async';

import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/domain/repositories/chat_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class ChatController extends GetxController {
  final ChatRepository repo;

  ChatController({required this.repo});

  final Rx<String?> currentUserId = Rx<String?>(null);
  final Rx<String?> displayName = Rx<String?>(null);
  final Rx<Conversation?> conversation = Rx<Conversation?>(null);

  final messages = Rxn<List<ChatMessage>>();
  final isSending = false.obs;
  final showScrollToBottom = false.obs;

  /// userId → displayName (necesario para mostrar nombre en chats grupales)
  final RxMap<String, String> userNames = <String, String>{}.obs;

  /// userId → accountStatus para detectar empleados eliminados/no operativos.
  final RxMap<String, String> userStatuses = <String, String>{}.obs;

  final scrollController = ScrollController();

  String nameForUser(String userId) =>
      userNames[userId] ?? userId.substring(0, userId.length.clamp(0, 6));

  /// Estado del status para un userId. Devuelve null si es la farmacia o no se conoce.
  String? statusForUser(String userId) => userStatuses[userId];

  /// True si el otro participante de un DM no está operativo (eliminado/desactivado).
  /// Para grupos siempre devuelve false (el grupo sigue siendo escribible).
  bool get isOtherUserDisabled {
    final conv = conversation.value;
    if (conv == null || conv.isGroup) return false;
    final me = currentUserId.value;
    if (me == null) return false;
    final other = conv.memberIds.firstWhere(
      (id) => id != me,
      orElse: () => '',
    );
    if (other.isEmpty) return false;
    final s = userStatuses[other];
    if (s == null) return false;
    return s == 'deleted' || s == 'disabled' || s == 'inactive';
  }

  /// Mensaje legible para mostrar al usuario sobre por qué no puede escribir.
  String get disabledReason {
    final conv = conversation.value;
    if (conv == null || conv.isGroup) return '';
    final me = currentUserId.value;
    if (me == null) return '';
    final other = conv.memberIds.firstWhere(
      (id) => id != me,
      orElse: () => '',
    );
    final s = userStatuses[other];
    return switch (s) {
      'deleted' => 'Este empleado ya no forma parte de la empresa',
      'disabled' => 'Este empleado está deshabilitado',
      'inactive' => 'Este empleado está inactivo',
      _ => 'Este chat está deshabilitado',
    };
  }

  StreamSubscription<List<ChatMessage>>? _msgSub;

  bool get _isNearBottom =>
      !scrollController.hasClients ||
      scrollController.position.pixels <= 80;

  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final shouldShow = scrollController.position.pixels > 200;
    if (shouldShow != showScrollToBottom.value) {
      showScrollToBottom.value = shouldShow;
    }
  }

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments as Map?;
    if (args == null) {
      Get.back();
      return;
    }

    currentUserId.value = args['currentUserId'] as String?;
    conversation.value = args['conversation'] as Conversation?;
    displayName.value = args['displayName'] as String?;

    final names = args['userNames'];
    if (names is Map) {
      userNames.addAll(names.map((k, v) => MapEntry(k.toString(), v.toString())));
    }

    final statuses = args['userStatuses'];
    if (statuses is Map) {
      userStatuses.addAll(
        statuses.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }

    if (currentUserId.value == null || conversation.value == null) {
      Get.back();
      return;
    }

    scrollController.addListener(_onScroll);
    _markRead();

    _msgSub = repo
        .streamMessages(conversation.value!.id)
        .listen((list) {
          final previous = messages.value;
          messages.value = list;

          // Auto-scroll si el usuario está cerca del fondo o llega un mensaje propio
          final isNewMessage = list.isNotEmpty &&
              (previous == null || list.length > previous.length);
          if (isNewMessage) {
            final newest = list.first;
            final isMine = newest.senderId == currentUserId.value;
            if (isMine || _isNearBottom) {
              WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
            }
            // Si recibo un mensaje ajeno mientras estoy abierto, lo marco leído
            if (!isMine) _markRead();
          }
        });
  }

  Future<void> _markRead() async {
    final convId = conversation.value?.id;
    final uid = currentUserId.value;
    if (convId == null || uid == null) return;
    try {
      await repo.markConversationAsRead(
        conversationId: convId,
        userId: uid,
      );
    } catch (_) {}
  }

  @override
  void onClose() {
    _msgSub?.cancel();
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    if (isOtherUserDisabled) return;
    isSending.value = true;
    try {
      await repo.sendMessage(
        conversationId: conversation.value!.id,
        senderId: currentUserId.value!,
        text: text.trim(),
      );
    } finally {
      isSending.value = false;
    }
  }
}
