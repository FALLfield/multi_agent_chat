class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final String? summary; // Condensed memory of past discussion rounds

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    this.summary,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'summary': summary,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.parse(map['createdAt']),
      summary: map['summary'] as String?,
    );
  }
}
