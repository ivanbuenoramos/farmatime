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

  final scrollController = ScrollController();

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

    if (currentUserId.value == null || conversation.value == null) {
      Get.back();
      return;
    }

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
          }
        });
  }

  @override
  void onClose() {
    _msgSub?.cancel();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
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
