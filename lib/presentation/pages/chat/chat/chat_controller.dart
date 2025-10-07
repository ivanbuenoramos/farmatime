import 'package:farmatime/data/models/chat/chat_models.dart';
import 'package:farmatime/domain/repositories/chat_repository.dart';
import 'package:get/get.dart';

class ChatController extends GetxController {
  final ChatRepository repo;
  final Rx<String?> currentUserId = Rx<String?>(null);
  final Rx<Conversation?> conversation = Rx<Conversation?>(null);

  ChatController({
    required this.repo,
    // required this.currentUserId,
    // required this.conversation,
  });

  final messages = Rxn<List<ChatMessage>>(); // orden DESC en stream
  final isSending = false.obs;

  @override
  void onInit() {
    super.onInit();
    
    currentUserId.value = Get.arguments['currentUserId'];
    conversation.value = Get.arguments['conversation'] as Conversation;

    if (currentUserId.value == null || conversation.value == null) {
      return Get.back();
    }

    repo.streamMessages(conversation.value!.id).listen((list) {
      messages.value = list; // viene desc; la UI invertirá el ListView
    });
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
