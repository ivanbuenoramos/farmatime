import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUserRef {
  final String id; // puede ser empleado o farmacia
  final String name;
  final String? avatarUrl;

  ChatUserRef({required this.id, required this.name, this.avatarUrl});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };

  factory ChatUserRef.fromMap(Map<String, dynamic> map) => ChatUserRef(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        avatarUrl: map['avatarUrl'] as String?,
      );
}

class Conversation {
  final String id;
  final String companyId;
  final bool isGroup;
  final String title;
  final String? imageUrl;
  final List<String> memberIds;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime updatedAt;
  final Map<String, int> unreadCounts;

  Conversation({
    required this.id,
    required this.companyId,
    required this.isGroup,
    required this.title,
    this.imageUrl,
    required this.memberIds,
    required this.updatedAt,
    this.lastMessageAt,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.unreadCounts = const {},
  });

  int unreadFor(String userId) => unreadCounts[userId] ?? 0;

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'isGroup': isGroup,
        'title': title,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'memberIds': memberIds,
        'lastMessageText': lastMessageText,
        'lastMessageSenderId': lastMessageSenderId,
        'updatedAt': Timestamp.fromDate(updatedAt),
        if (lastMessageAt != null) 'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
        'unreadCounts': unreadCounts,
      };

  factory Conversation.fromSnapshot(DocumentSnapshot snap) {
    final m = snap.data() as Map<String, dynamic>;
    final rawUnread = m['unreadCounts'];
    final unreadCounts = <String, int>{};
    if (rawUnread is Map) {
      rawUnread.forEach((k, v) {
        if (v is int) unreadCounts[k.toString()] = v;
      });
    }
    return Conversation(
      id: snap.id,
      companyId: m['companyId'] as String,
      isGroup: (m['isGroup'] as bool?) ?? false,
      title: m['title'] as String? ?? '',
      imageUrl: m['imageUrl'] as String?,
      memberIds: (m['memberIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      lastMessageText: m['lastMessageText'] as String?,
      lastMessageSenderId: m['lastMessageSenderId'] as String?,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (m['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCounts: unreadCounts,
    );
  }
}

class ChatMessage {
  final String id; // doc id
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ChatMessage.fromSnapshot(DocumentSnapshot snap) {
    final m = snap.data() as Map<String, dynamic>;
    return ChatMessage(
      id: snap.id,
      conversationId: m['conversationId'] as String,
      senderId: m['senderId'] as String,
      text: m['text'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}