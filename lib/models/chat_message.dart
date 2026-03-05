import 'agent_persona.dart';

class ChatMessage {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool isUser;
  final AgentPersona? agent; // Empty if it's user message
  final String? sessionId;
  final bool isConclusion;
  final String? senderName; // Name of the user who sent this message
  final String? replyTo; // "@Name" - who this message is replying to

  const ChatMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.isUser,
    this.agent,
    this.sessionId,
    this.isConclusion = false,
    this.senderName,
    this.replyTo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'isUser': isUser ? 1 : 0,
      'agentId': agent?.id,
      'sessionId': sessionId,
      'isConclusion': isConclusion ? 1 : 0,
      'senderName': senderName,
      'replyTo': replyTo,
    };
  }

  // Note: agent field needs to be populated separately after retrieving from DB
  factory ChatMessage.fromMap(Map<String, dynamic> map, {AgentPersona? agent}) {
    return ChatMessage(
      id: map['id'],
      text: map['text'],
      createdAt: DateTime.parse(map['createdAt']),
      isUser: map['isUser'] == 1,
      agent: agent,
      sessionId: map['sessionId'],
      isConclusion: (map['isConclusion'] ?? 0) == 1,
      senderName: map['senderName'] as String?,
      replyTo: map['replyTo'] as String?,
    );
  }
}
