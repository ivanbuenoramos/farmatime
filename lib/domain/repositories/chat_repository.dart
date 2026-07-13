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

  /// Devuelve un mapa userId → displayName con todos los miembros de la empresa.
  /// Incluye la farmacia (companyId → legalName) y todos los empleados.
  Future<Map<String, String>> getMemberNames(String companyId);

  /// Devuelve un mapa userId → accountStatus (string) con todos los empleados.
  /// Sólo incluye empleados (la farmacia no se incluye). Estados posibles:
  /// 'active' | 'pending' | 'inactive' | 'disabled' | 'deleted'.
  Future<Map<String, String>> getMemberStatuses(String companyId);

  Stream<List<Conversation>> streamInbox(String userId, String companyId);
  Stream<List<ChatMessage>> streamMessages(String conversationId);

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  });

  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  });
}