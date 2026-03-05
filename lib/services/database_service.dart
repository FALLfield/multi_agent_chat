import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/agent_persona.dart';
import '../models/user_persona.dart';

/// Platform-adaptive storage service.
/// • Web  → SharedPreferences (browser localStorage, zero config)
/// • Native → sqflite (SQLite)
///
/// The public API is identical on both platforms so the rest of the
/// app never needs to know which backend is in use.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // ── Native only ──────────────────────────────────────────────────────────
  static Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await _initSqflite();
    return _database!;
  }

  Future<Database> _initSqflite() async {
    final path = join(await getDatabasesPath(), 'multi_agent_chat.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions(
        id TEXT PRIMARY KEY, title TEXT, createdAt TEXT, summary TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE messages(
        id TEXT PRIMARY KEY, text TEXT, createdAt TEXT,
        isUser INTEGER, agentId TEXT, sessionId TEXT,
        isConclusion INTEGER DEFAULT 0, senderName TEXT, replyTo TEXT,
        FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE agents(
        id TEXT PRIMARY KEY, name TEXT, systemInstruction TEXT,
        provider TEXT, modelName TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE users(id TEXT PRIMARY KEY, name TEXT)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE agents(
          id TEXT PRIMARY KEY, name TEXT, systemInstruction TEXT,
          provider TEXT, modelName TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('CREATE TABLE users(id TEXT PRIMARY KEY, name TEXT)');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN isConclusion INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE messages ADD COLUMN senderName TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE sessions ADD COLUMN summary TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE messages ADD COLUMN replyTo TEXT');
    }
  }

  // ── Web helpers (SharedPreferences / localStorage) ────────────────────────
  //
  // Data layout in SharedPreferences:
  //   'web_sessions'  → JSON list of session maps
  //   'web_messages'  → JSON list of message maps
  //   'web_agents'    → JSON list of agent maps
  //   'web_users'     → JSON list of user maps

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

  // ── Session Methods ───────────────────────────────────────────────────────

  Future<void> insertSession(ChatSession session) async {
    if (kIsWeb) {
      final list = await _webRead('web_sessions');
      list.removeWhere((m) => m['id'] == session.id);
      list.add(session.toMap());
      await _webWrite('web_sessions', list);
    } else {
      final db = await _db;
      await db.insert(
        'sessions',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> updateSession(ChatSession session) async {
    if (kIsWeb) {
      await insertSession(session); // upsert
    } else {
      final db = await _db;
      await db.update(
        'sessions',
        session.toMap(),
        where: 'id = ?',
        whereArgs: [session.id],
      );
    }
  }

  Future<List<ChatSession>> getSessions() async {
    if (kIsWeb) {
      final list = await _webRead('web_sessions');
      list.sort(
        (a, b) =>
            (b['createdAt'] as String).compareTo(a['createdAt'] as String),
      );
      return list.map(ChatSession.fromMap).toList();
    } else {
      final db = await _db;
      final maps = await db.query('sessions', orderBy: 'createdAt DESC');
      return maps.map(ChatSession.fromMap).toList();
    }
  }

  // ── Message Methods ───────────────────────────────────────────────────────

  Future<void> insertMessage(ChatMessage message) async {
    if (kIsWeb) {
      final list = await _webRead('web_messages');
      list.removeWhere((m) => m['id'] == message.id);
      list.add(message.toMap());
      await _webWrite('web_messages', list);
    } else {
      final db = await _db;
      await db.insert(
        'messages',
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> updateMessage(ChatMessage message) async {
    if (kIsWeb) {
      await insertMessage(message); // upsert
    } else {
      final db = await _db;
      await db.update(
        'messages',
        message.toMap(),
        where: 'id = ?',
        whereArgs: [message.id],
      );
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
      final db = await _db;
      maps = await db.query(
        'messages',
        where: 'sessionId = ?',
        whereArgs: [sessionId],
        orderBy: 'createdAt ASC',
      );
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

  // ── Agent Methods ─────────────────────────────────────────────────────────

  Future<void> insertAgent(AgentPersona agent) async {
    if (kIsWeb) {
      final list = await _webRead('web_agents');
      list.removeWhere((m) => m['id'] == agent.id);
      list.add(agent.toMap());
      await _webWrite('web_agents', list);
    } else {
      final db = await _db;
      await db.insert(
        'agents',
        agent.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> updateAgent(AgentPersona agent) async {
    if (kIsWeb) {
      await insertAgent(agent); // upsert
    } else {
      final db = await _db;
      await db.update(
        'agents',
        agent.toMap(),
        where: 'id = ?',
        whereArgs: [agent.id],
      );
    }
  }

  Future<void> deleteAgent(String id) async {
    if (kIsWeb) {
      final list = await _webRead('web_agents');
      list.removeWhere((m) => m['id'] == id);
      await _webWrite('web_agents', list);
    } else {
      final db = await _db;
      await db.delete('agents', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<List<AgentPersona>> getAgents() async {
    if (kIsWeb) {
      final list = await _webRead('web_agents');
      return list.map(AgentPersona.fromMap).toList();
    } else {
      final db = await _db;
      final maps = await db.query('agents');
      return maps.map(AgentPersona.fromMap).toList();
    }
  }

  // ── User Methods ──────────────────────────────────────────────────────────

  Future<void> insertUser(UserPersona user) async {
    if (kIsWeb) {
      final list = await _webRead('web_users');
      list.removeWhere((m) => m['id'] == user.id);
      list.add(user.toMap());
      await _webWrite('web_users', list);
    } else {
      final db = await _db;
      await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> deleteUser(String id) async {
    if (kIsWeb) {
      final list = await _webRead('web_users');
      list.removeWhere((m) => m['id'] == id);
      await _webWrite('web_users', list);
    } else {
      final db = await _db;
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<List<UserPersona>> getUsers() async {
    if (kIsWeb) {
      final list = await _webRead('web_users');
      return list.map(UserPersona.fromMap).toList();
    } else {
      final db = await _db;
      final maps = await db.query('users');
      return maps.map(UserPersona.fromMap).toList();
    }
  }

  // ── Clear History ─────────────────────────────────────────────────────────

  Future<void> clearAllHistory() async {
    if (kIsWeb) {
      await _webWrite('web_messages', []);
      await _webWrite('web_sessions', []);
    } else {
      final db = await _db;
      await db.delete('messages');
      await db.delete('sessions');
    }
  }
}
