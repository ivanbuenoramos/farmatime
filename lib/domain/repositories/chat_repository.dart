import 'package:farmatime/data/models/chat/chat_models.dart';



abstract class ChatRepository {
  Future<Conversation> ensureDefaultGroup({
    required String companyId,
    required String pharmacyUserId,
    required List<String> allMemberIds,
  });

  Future<Conversation> ensureDirectConversation({
    required String companyId,
    required String userA,
    required String userB,
    String? titleOverride,
  });

  Stream<List<Conversation>> streamInbox(String userId, String companyId);
  Stream<List<ChatMessage>> streamMessages(String conversationId);

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  });
}