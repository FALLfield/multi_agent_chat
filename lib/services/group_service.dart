import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/group.dart';

class GroupService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Group> _myGroups = [];
  List<Group> get myGroups => _myGroups;

  Group? _activeGroup;
  Group? get activeGroup => _activeGroup;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setActiveGroup(Group g) {
    _activeGroup = g;
    notifyListeners();
  }

  /// Generates a random 6-character alphanumeric invite code
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Returns a unique invite code (checks Firestore for collision)
  Future<String> _uniqueInviteCode() async {
    while (true) {
      final code = _generateInviteCode();
      final snap = await _db
          .collection('groups')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return code;
    }
  }

  /// Load the groups the current user belongs to
  Future<void> loadMyGroups() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final displayName =
        user.displayName ?? user.email?.split('@').first ?? 'User';

    _isLoading = true;
    notifyListeners();
    try {
      final snap = await _db
          .collection('groups')
          .where('memberUids', arrayContains: uid)
          .get();
      _myGroups = snap.docs.map((d) => Group.fromMap(d.id, d.data())).toList();
      _myGroups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Backfill: register current user's display name in every group's
      // memberNames map (covers groups created before this field existed)
      for (final doc in snap.docs) {
        final existing = doc.data()['memberNames'];
        final currentName = (existing is Map)
            ? (existing[uid] as String?)
            : null;
        if (currentName != displayName) {
          doc.reference
              .update({'memberNames.$uid': displayName})
              .catchError((_) {});
        }
      }

      // Restore active group if still valid
      if (_activeGroup != null) {
        final updated = _myGroups
            .where((g) => g.id == _activeGroup!.id)
            .toList();
        _activeGroup = updated.isNotEmpty ? updated.first : null;
      }
    } catch (e) {
      _errorMessage = '加载群组失败：$e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new group (only the leader calls this)
  Future<Group?> createGroup({
    required String name,
    Map<String, String> apiKeys = const {},
    String doubaoEndpoint = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final code = await _uniqueInviteCode();
      final docRef = _db.collection('groups').doc();
      final group = Group(
        id: docRef.id,
        name: name,
        leaderUid: user.uid,
        inviteCode: code,
        apiKeys: apiKeys,
        doubaoEndpoint: doubaoEndpoint,
        memberUids: [user.uid],
        memberNames: {
          user.uid: user.displayName ?? user.email?.split('@').first ?? 'User',
        },
        createdAt: DateTime.now(),
      );
      await docRef.set(group.toMap());
      _myGroups.insert(0, group);
      _activeGroup = group;
      return group;
    } catch (e) {
      _errorMessage = '创建群组失败：$e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Join a group with an invite code
  Future<Group?> joinGroup(String inviteCode) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final snap = await _db
          .collection('groups')
          .where('inviteCode', isEqualTo: inviteCode.trim().toUpperCase())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        _errorMessage = '邀请码无效，请检查后重试。';
        return null;
      }
      final doc = snap.docs.first;
      final group = Group.fromMap(doc.id, doc.data());
      if (group.memberUids.contains(user.uid)) {
        // Already a member — just navigate
        _activeGroup = group;
        return group;
      }
      await doc.reference.update({
        'memberUids': FieldValue.arrayUnion([user.uid]),
        'memberNames.${user.uid}':
            user.displayName ?? user.email?.split('@').first ?? 'User',
      });
      final updated = Group(
        id: group.id,
        name: group.name,
        leaderUid: group.leaderUid,
        inviteCode: group.inviteCode,
        apiKeys: group.apiKeys,
        doubaoEndpoint: group.doubaoEndpoint,
        memberUids: [...group.memberUids, user.uid],
        memberNames: {
          ...group.memberNames,
          user.uid: user.displayName ?? user.email?.split('@').first ?? 'User',
        },
        createdAt: group.createdAt,
      );
      _myGroups.insert(0, updated);
      _activeGroup = updated;
      return updated;
    } catch (e) {
      _errorMessage = '加入群组失败：$e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Leave or Delete Group
  Future<bool> leaveOrDeleteGroup(Group group) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isLeader = group.isLeader(user.uid);
      final docRef = _db.collection('groups').doc(group.id);

      if (isLeader) {
        // Delete the entire group document
        await docRef.delete();
      } else {
        // Remove self from memberUids
        await docRef.update({
          'memberUids': FieldValue.arrayRemove([user.uid]),
        });
      }

      _myGroups.removeWhere((g) => g.id == group.id);
      if (_activeGroup?.id == group.id) {
        _activeGroup = _myGroups.isNotEmpty ? _myGroups.first : null;
      }
      return true;
    } catch (e) {
      _errorMessage = '退出/解散群组失败：$e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream a single group document for real-time settings sync
  Stream<Group> streamGroup(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((snap) {
      if (!snap.exists) throw Exception('Group not found');
      return Group.fromMap(snap.id, snap.data()!);
    });
  }

  /// Update discussion settings (leader only) — syncs to all members via Firestore
  Future<void> updateDiscussionSettings({
    required String groupId,
    required int rounds,
    required String mode,
  }) async {
    await _db.collection('groups').doc(groupId).update({
      'discussionRounds': rounds,
      'discussionMode': mode,
    });
  }

  /// Update a group's API keys (leader only)
  Future<bool> updateGroupApiKeys({
    required String groupId,
    required Map<String, String> apiKeys,
    required String doubaoEndpoint,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _db.collection('groups').doc(groupId).update({
        'apiKeys': apiKeys,
        'doubaoEndpoint': doubaoEndpoint,
      });
      final idx = _myGroups.indexWhere((g) => g.id == groupId);
      if (idx != -1) {
        final old = _myGroups[idx];
        final updated = Group(
          id: old.id,
          name: old.name,
          leaderUid: old.leaderUid,
          inviteCode: old.inviteCode,
          apiKeys: apiKeys,
          doubaoEndpoint: doubaoEndpoint,
          memberUids: old.memberUids,
          memberNames: old.memberNames,
          createdAt: old.createdAt,
        );
        _myGroups[idx] = updated;
        if (_activeGroup?.id == groupId) _activeGroup = updated;
      }
      return true;
    } catch (e) {
      _errorMessage = '更新 API Key 失败：$e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearActiveGroup() {
    _activeGroup = null;
    notifyListeners();
  }
}
