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
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final snap = await _db
          .collection('groups')
          .where('memberUids', arrayContains: uid)
          .orderBy('createdAt', descending: true)
          .get();
      _myGroups = snap.docs.map((d) => Group.fromMap(d.id, d.data())).toList();
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
    required Map<String, String> apiKeys,
    required String doubaoEndpoint,
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
      // Add user to memberUids array
      await doc.reference.update({
        'memberUids': FieldValue.arrayUnion([user.uid]),
      });
      final updated = Group(
        id: group.id,
        name: group.name,
        leaderUid: group.leaderUid,
        inviteCode: group.inviteCode,
        apiKeys: group.apiKeys,
        doubaoEndpoint: group.doubaoEndpoint,
        memberUids: [...group.memberUids, user.uid],
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
