class Group {
  final String id;
  final String name;
  final String leaderUid;
  final String inviteCode;
  final Map<String, String> apiKeys; // provider -> key
  final String doubaoEndpoint;
  final List<String> memberUids;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.leaderUid,
    required this.inviteCode,
    required this.apiKeys,
    required this.doubaoEndpoint,
    required this.memberUids,
    required this.createdAt,
  });

  bool isLeader(String uid) => leaderUid == uid;

  factory Group.fromMap(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      name: map['name'] as String? ?? 'Unnamed Group',
      leaderUid: map['leaderUid'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      apiKeys: Map<String, String>.from(map['apiKeys'] as Map? ?? {}),
      doubaoEndpoint: map['doubaoEndpoint'] as String? ?? '',
      memberUids: List<String>.from(map['memberUids'] as List? ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'leaderUid': leaderUid,
      'inviteCode': inviteCode,
      'apiKeys': apiKeys,
      'doubaoEndpoint': doubaoEndpoint,
      'memberUids': memberUids,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
