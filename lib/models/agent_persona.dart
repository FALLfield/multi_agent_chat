class AgentPersona {
  final String id;
  final String name;
  final String systemInstruction;
  final String provider; // e.g., 'kimi', 'qwen', 'doubao', 'deepseek'
  final String modelName;

  const AgentPersona({
    required this.id,
    required this.name,
    required this.systemInstruction,
    required this.provider,
    required this.modelName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'systemInstruction': systemInstruction,
      'provider': provider,
      'modelName': modelName,
    };
  }

  factory AgentPersona.fromMap(Map<String, dynamic> map) {
    return AgentPersona(
      id: map['id'] as String,
      name: map['name'] as String,
      systemInstruction: map['systemInstruction'] as String,
      provider: map['provider'] as String,
      modelName: map['modelName'] as String,
    );
  }
}
