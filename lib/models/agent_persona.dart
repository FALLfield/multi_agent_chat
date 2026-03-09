class AgentPersona {
  final String id;
  final String name;
  final String systemInstruction;
  final String provider; // e.g., 'kimi', 'qwen', 'doubao', 'deepseek'
  final String modelName;
  final String groupId;
  final String apiKey;       // per-agent API key
  final String doubaoEndpoint; // only used when provider == 'doubao'

  const AgentPersona({
    required this.id,
    required this.name,
    required this.systemInstruction,
    required this.provider,
    required this.modelName,
    required this.groupId,
    this.apiKey = '',
    this.doubaoEndpoint = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'systemInstruction': systemInstruction,
      'provider': provider,
      'modelName': modelName,
      'groupId': groupId,
      'apiKey': apiKey,
      'doubaoEndpoint': doubaoEndpoint,
    };
  }

  factory AgentPersona.fromMap(Map<String, dynamic> map) {
    return AgentPersona(
      id: map['id'] as String,
      name: map['name'] as String,
      systemInstruction: map['systemInstruction'] as String,
      provider: map['provider'] as String,
      modelName: map['modelName'] as String,
      groupId: map['groupId'] as String? ?? '',
      apiKey: map['apiKey'] as String? ?? '',
      doubaoEndpoint: map['doubaoEndpoint'] as String? ?? '',
    );
  }
}
