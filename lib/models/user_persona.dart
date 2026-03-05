class UserPersona {
  final String id;
  final String name;

  const UserPersona({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPersona &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  factory UserPersona.fromMap(Map<String, dynamic> map) {
    return UserPersona(id: map['id'] as String, name: map['name'] as String);
  }
}
