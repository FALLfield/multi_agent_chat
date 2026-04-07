class Group {
  final String id;
  final String name;
  final String leaderUid;
  final String inviteCode;
  final Map<String, String> apiKeys; // provider -> key
  final String doubaoEndpoint;
  final List<String> memberUids;
  final Map<String, String> memberNames;
  final DateTime createdAt;
  final int discussionRounds;
  final String discussionMode; // 'sequential' | 'concurrent'
  final String outputLengthLimit; // 'concise' | 'medium' | 'detailed' | 'unlimited'

  Group({
    required this.id,
    required this.name,
    required this.leaderUid,
    required this.inviteCode,
    required this.apiKeys,
    required this.doubaoEndpoint,
    required this.memberUids,
    required this.memberNames,
    required this.createdAt,
    this.discussionRounds = 1,
    this.discussionMode = 'sequential',
    this.outputLengthLimit = 'unlimited',
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
      memberNames: Map<String, String>.from(map['memberNames'] as Map? ?? {}),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      discussionRounds: (map['discussionRounds'] as num?)?.toInt() ?? 1,
      discussionMode: map['discussionMode'] as String? ?? 'sequential',
      outputLengthLimit: map['outputLengthLimit'] as String? ?? 'unlimited',
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
      'memberNames': memberNames,
      'createdAt': createdAt.toIso8601String(),
      'discussionRounds': discussionRounds,
      'discussionMode': discussionMode,
      'outputLengthLimit': outputLengthLimit,
    };
  }
}
