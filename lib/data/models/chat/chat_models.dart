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
  final String id; // doc id
  final String companyId;
  final bool isGroup;
  final String title; // para grupo o el nombre del otro en 1:1
  final List<String> memberIds; // [userId1, userId2, ...]
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.companyId,
    required this.isGroup,
    required this.title,
    required this.memberIds,
    required this.updatedAt,
    this.lastMessageAt,
    this.lastMessageText,
  });

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'isGroup': isGroup,
        'title': title,
        'memberIds': memberIds,
        'lastMessageText': lastMessageText,
        'updatedAt': Timestamp.fromDate(updatedAt),
        if (lastMessageAt != null) 'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      };

  factory Conversation.fromSnapshot(DocumentSnapshot snap) {
    final m = snap.data() as Map<String, dynamic>;
    return Conversation(
      id: snap.id,
      companyId: m['companyId'] as String,
      isGroup: (m['isGroup'] as bool?) ?? false,
      title: m['title'] as String? ?? '',
      memberIds: (m['memberIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      lastMessageText: m['lastMessageText'] as String?,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (m['lastMessageAt'] as Timestamp?)?.toDate(),
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