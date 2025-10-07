import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmatime/data/models/chat/chat_models.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  CollectionReference get _conversations => firestore.collection('conversations');
  CollectionReference _messages(String conversationId) =>
      _conversations.doc(conversationId).collection('messages');

  @override
  Future<Conversation> ensureDefaultGroup({
    required String companyId,
    required String pharmacyUserId,
    required List<String> allMemberIds,
  }) async {
    final q = await _conversations
        .where('companyId', isEqualTo: companyId)
        .where('isGroup', isEqualTo: true)
        .where('title', isEqualTo: 'Todos')
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) return Conversation.fromSnapshot(q.docs.first);

    final doc = await _conversations.add({
      'companyId': companyId,
      'isGroup': true,
      'title': 'Todos',
      'memberIds': allMemberIds,
      'lastMessageText': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await doc.get();
    return Conversation.fromSnapshot(snap);
  }

  @override
  Future<Conversation> ensureDirectConversation({
    required String companyId,
    required String userA,
    required String userB,
    String? titleOverride,
  }) async {
    final members = [userA, userB]..sort();
    final q = await _conversations
        .where('companyId', isEqualTo: companyId)
        .where('isGroup', isEqualTo: false)
        .where('memberIds', arrayContains: members.first)
        .get();

    for (final d in q.docs) {
      final conv = Conversation.fromSnapshot(d);
      final sorted = [...conv.memberIds]..sort();
      if (sorted.length == 2 && sorted[0] == members[0] && sorted[1] == members[1]) {
        return conv;
      }
    }

    final doc = await _conversations.add({
      'companyId': companyId,
      'isGroup': false,
      'title': titleOverride ?? '',
      'memberIds': members,
      'lastMessageText': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await doc.get();
    return Conversation.fromSnapshot(snap);
  }

  @override
  Stream<List<Conversation>> streamInbox(String userId, String companyId) {
    return _conversations
        .where('companyId', isEqualTo: companyId)
        .where('memberIds', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Conversation.fromSnapshot).toList());
  }

  @override
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromSnapshot).toList());
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final now = FieldValue.serverTimestamp();
    final batch = firestore.batch();

    final msgRef = _messages(conversationId).doc();
    batch.set(msgRef, {
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text,
      'createdAt': now,
    });

    final convRef = _conversations.doc(conversationId);
    batch.update(convRef, {
      'lastMessageText': text,
      'updatedAt': now,
    });

    await batch.commit();
  }
}
