// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/agent_persona.dart';
import '../models/user_persona.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Session Methods ────────────────────────────────────────────────────────

  Future<void> insertSession(ChatSession session) async {
    await _db.collection('sessions').doc(session.id).set(session.toMap());
  }

  Future<void> updateSession(ChatSession session) async {
    await _db
        .collection('sessions')
        .doc(session.id)
        .set(session.toMap(), SetOptions(merge: true));
  }

  Future<List<ChatSession>> getSessions(String groupId) async {
    final snap = await _db
        .collection('sessions')
        .where('groupId', isEqualTo: groupId)
        .get();
    final list = snap.docs
        .map((doc) => ChatSession.fromMap(doc.data()))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Stream<List<ChatSession>> streamSessions(String groupId) {
    return _db
        .collection('sessions')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => ChatSession.fromMap(doc.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ── Message Methods ────────────────────────────────────────────────────────

  Future<void> insertMessage(ChatMessage message) async {
    await _db.collection('messages').doc(message.id).set(message.toMap());
  }

  Future<void> updateMessage(ChatMessage message) async {
    await _db
        .collection('messages')
        .doc(message.id)
        .set(message.toMap(), SetOptions(merge: true));
  }

  Future<List<ChatMessage>> getMessagesForSession(
    String sessionId,
    List<AgentPersona> activeAgents,
  ) async {
    final snap = await _db
        .collection('messages')
        .where('sessionId', isEqualTo: sessionId)
        .get();

    final list = snap.docs.map((doc) {
      final map = doc.data();
      final agentId = map['agentId'] as String?;
      AgentPersona? agent;
      if (agentId != null) {
        try {
          agent = activeAgents.firstWhere((a) => a.id == agentId);
        } catch (_) {}
      }
      return ChatMessage.fromMap(map, agent: agent);
    }).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Stream<List<ChatMessage>> streamMessages(
    String sessionId,
    List<AgentPersona> activeAgents,
  ) {
    return _db
        .collection('messages')
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) {
            final map = doc.data();
            final agentId = map['agentId'] as String?;
            AgentPersona? agent;
            if (agentId != null) {
              try {
                agent = activeAgents.firstWhere((a) => a.id == agentId);
              } catch (_) {}
            }
            return ChatMessage.fromMap(map, agent: agent);
          }).toList();
          list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  // ── Agent Methods ──────────────────────────────────────────────────────────

  Future<void> insertAgent(AgentPersona agent) async {
    await _db.collection('agents').doc(agent.id).set(agent.toMap());
  }

  Future<void> updateAgent(AgentPersona agent) async {
    await _db
        .collection('agents')
        .doc(agent.id)
        .set(agent.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteAgent(String id) async {
    await _db.collection('agents').doc(id).delete();
  }

  Future<List<AgentPersona>> getAgents(String groupId) async {
    final snap = await _db
        .collection('agents')
        .where('groupId', isEqualTo: groupId)
        .get();
    return snap.docs.map((doc) => AgentPersona.fromMap(doc.data())).toList();
  }

  Stream<List<AgentPersona>> streamAgents(String groupId) {
    return _db
        .collection('agents')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => AgentPersona.fromMap(doc.data())).toList(),
        );
  }

  // ── User Methods ───────────────────────────────────────────────────────────

  Future<void> insertUser(UserPersona user) async {
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> deleteUser(String id) async {
    await _db.collection('users').doc(id).delete();
  }

  Future<List<UserPersona>> getUsers() async {
    final snap = await _db.collection('users').get();
    return snap.docs.map((doc) => UserPersona.fromMap(doc.data())).toList();
  }

  // ── Clear History ──────────────────────────────────────────────────────────

  Future<void> deleteSession(String sessionId) async {
    final msgs = await _db
        .collection('messages')
        .where('sessionId', isEqualTo: sessionId)
        .get();
    for (var doc in msgs.docs) {
      await doc.reference.delete();
    }
    await _db.collection('sessions').doc(sessionId).delete();
  }

  Future<void> clearAllHistory(String groupId) async {
    final msgs = await _db
        .collection('messages')
        .where('groupId', isEqualTo: groupId)
        .get();
    for (var doc in msgs.docs) {
      await doc.reference.delete();
    }
    final sess = await _db
        .collection('sessions')
        .where('groupId', isEqualTo: groupId)
        .get();
    for (var doc in sess.docs) {
      await doc.reference.delete();
    }
  }
}
