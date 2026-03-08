// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/agent_persona.dart';
import '../models/user_persona.dart';

// Conditional import: on web builds dart2js only sees the stub (no sqflite).
// On native (dart:io) the real sqflite backend is loaded.
import 'db_backend_stub.dart'
    if (dart.library.io) 'db_backend_native.dart'
    as native_db;

/// Platform-adaptive storage service.
/// • Web    → SharedPreferences (browser localStorage)
/// • Native → sqflite via [db_backend_native.dart]
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // ── Web helpers ────────────────────────────────────────────────────────────

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Map<String, dynamic>>> _webRead(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<void> _webWrite(String key, List<Map<String, dynamic>> data) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(data));
  }

  // ── Session Methods ────────────────────────────────────────────────────────

  Future<void> insertSession(ChatSession session) async {
    if (kIsWeb) {
      final list = await _webRead('web_sessions');
      list.removeWhere((m) => m['id'] == session.id);
      list.add(session.toMap());
      await _webWrite('web_sessions', list);
    } else {
      await native_db.insertSession(session);
    }
  }

  Future<void> updateSession(ChatSession session) async {
    if (kIsWeb) {
      await insertSession(session);
    } else {
      await native_db.updateSession(session);
    }
  }

  Future<List<ChatSession>> getSessions(String groupId) async {
    if (kIsWeb) {
      final list = await _webRead('web_sessions');
      final filtered = list.where((m) => m['groupId'] == groupId).toList();
      filtered.sort(
        (a, b) =>
            (b['createdAt'] as String).compareTo(a['createdAt'] as String),
      );
      return filtered.map(ChatSession.fromMap).toList();
    } else {
      return native_db.getSessions(groupId);
    }
  }

  // ── Message Methods ────────────────────────────────────────────────────────

  Future<void> insertMessage(ChatMessage message) async {
    if (kIsWeb) {
      final list = await _webRead('web_messages');
      list.removeWhere((m) => m['id'] == message.id);
      list.add(message.toMap());
      await _webWrite('web_messages', list);
    } else {
      await native_db.insertMessage(message);
    }
  }

  Future<void> updateMessage(ChatMessage message) async {
    if (kIsWeb) {
      await insertMessage(message);
    } else {
      await native_db.updateMessage(message);
    }
  }

  Future<List<ChatMessage>> getMessagesForSession(
    String sessionId,
    List<AgentPersona> activeAgents,
  ) async {
    final List<Map<String, dynamic>> maps;
    if (kIsWeb) {
      final all = await _webRead('web_messages');
      maps = all.where((m) => m['sessionId'] == sessionId).toList()
        ..sort(
          (a, b) =>
              (a['createdAt'] as String).compareTo(b['createdAt'] as String),
        );
    } else {
      maps = await native_db.getMessagesForSession(sessionId);
    }

    return maps.map((map) {
      final agentId = map['agentId'] as String?;
      AgentPersona? agent;
      if (agentId != null) {
        try {
          agent = activeAgents.firstWhere((a) => a.id == agentId);
        } catch (_) {}
      }
      return ChatMessage.fromMap(map, agent: agent);
    }).toList();
  }

  // ── Agent Methods ──────────────────────────────────────────────────────────

  Future<void> insertAgent(AgentPersona agent) async {
    if (kIsWeb) {
      final list = await _webRead('web_agents');
      list.removeWhere((m) => m['id'] == agent.id);
      list.add(agent.toMap());
      await _webWrite('web_agents', list);
    } else {
      await native_db.insertAgent(agent);
    }
  }

  Future<void> updateAgent(AgentPersona agent) async {
    if (kIsWeb) {
      await insertAgent(agent);
    } else {
      await native_db.updateAgent(agent);
    }
  }

  Future<void> deleteAgent(String id) async {
    if (kIsWeb) {
      final list = await _webRead('web_agents');
      list.removeWhere((m) => m['id'] == id);
      await _webWrite('web_agents', list);
    } else {
      await native_db.deleteAgent(id);
    }
  }

  Future<List<AgentPersona>> getAgents(String groupId) async {
    if (kIsWeb) {
      final list = await _webRead('web_agents');
      final filtered = list.where((m) => m['groupId'] == groupId).toList();
      return filtered.map(AgentPersona.fromMap).toList();
    } else {
      return native_db.getAgents(groupId);
    }
  }

  // ── User Methods ───────────────────────────────────────────────────────────

  Future<void> insertUser(UserPersona user) async {
    if (kIsWeb) {
      final list = await _webRead('web_users');
      list.removeWhere((m) => m['id'] == user.id);
      list.add(user.toMap());
      await _webWrite('web_users', list);
    } else {
      await native_db.insertUser(user);
    }
  }

  Future<void> deleteUser(String id) async {
    if (kIsWeb) {
      final list = await _webRead('web_users');
      list.removeWhere((m) => m['id'] == id);
      await _webWrite('web_users', list);
    } else {
      await native_db.deleteUser(id);
    }
  }

  Future<List<UserPersona>> getUsers() async {
    if (kIsWeb) {
      final list = await _webRead('web_users');
      return list.map(UserPersona.fromMap).toList();
    } else {
      return native_db.getUsers();
    }
  }

  // ── Clear History ──────────────────────────────────────────────────────────

  Future<void> clearAllHistory(String groupId) async {
    if (kIsWeb) {
      final msgs = await _webRead('web_messages');
      msgs.removeWhere((m) => m['groupId'] == groupId);
      await _webWrite('web_messages', msgs);

      final sess = await _webRead('web_sessions');
      sess.removeWhere((s) => s['groupId'] == groupId);
      await _webWrite('web_sessions', sess);
    } else {
      await native_db.clearAllHistory(groupId);
    }
  }
}
