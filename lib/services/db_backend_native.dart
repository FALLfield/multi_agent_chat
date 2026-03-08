// Native (dart:io) sqflite backend.
// This file is only loaded on non-web platforms.
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/agent_persona.dart';
import '../models/user_persona.dart';

Database? _database;

Future<Database> get _db async {
  if (_database != null) return _database!;
  _database = await _initSqflite();
  return _database!;
}

Future<Database> _initSqflite() async {
  final path = join(await getDatabasesPath(), 'multi_agent_chat.db');
  return openDatabase(
    path,
    version: 8,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE sessions(
      id TEXT PRIMARY KEY, title TEXT, createdAt TEXT, summary TEXT, groupId TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE messages(
      id TEXT PRIMARY KEY, text TEXT, createdAt TEXT,
      isUser INTEGER, agentId TEXT, sessionId TEXT,
      isConclusion INTEGER DEFAULT 0, senderName TEXT, replyTo TEXT, groupId TEXT,
      FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE TABLE agents(
      id TEXT PRIMARY KEY, name TEXT, systemInstruction TEXT,
      provider TEXT, modelName TEXT, groupId TEXT
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
  if (oldVersion < 8) {
    await db.execute('ALTER TABLE sessions ADD COLUMN groupId TEXT');
    await db.execute('ALTER TABLE messages ADD COLUMN groupId TEXT');
    await db.execute('ALTER TABLE agents ADD COLUMN groupId TEXT');
  }
}

// ── Sessions ────────────────────────────────────────────────────────────────

Future<void> insertSession(ChatSession session) async {
  final db = await _db;
  await db.insert(
    'sessions',
    session.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> updateSession(ChatSession session) async {
  final db = await _db;
  await db.update(
    'sessions',
    session.toMap(),
    where: 'id = ?',
    whereArgs: [session.id],
  );
}

Future<List<ChatSession>> getSessions(String groupId) async {
  final db = await _db;
  final maps = await db.query(
    'sessions',
    where: 'groupId = ?',
    whereArgs: [groupId],
    orderBy: 'createdAt DESC',
  );
  return maps.map(ChatSession.fromMap).toList();
}

// ── Messages ─────────────────────────────────────────────────────────────────

Future<void> insertMessage(ChatMessage message) async {
  final db = await _db;
  await db.insert(
    'messages',
    message.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> updateMessage(ChatMessage message) async {
  final db = await _db;
  await db.update(
    'messages',
    message.toMap(),
    where: 'id = ?',
    whereArgs: [message.id],
  );
}

Future<List<Map<String, dynamic>>> getMessagesForSession(
  String sessionId,
) async {
  final db = await _db;
  return db.query(
    'messages',
    where: 'sessionId = ?',
    whereArgs: [sessionId],
    orderBy: 'createdAt ASC',
  );
}

// ── Agents ───────────────────────────────────────────────────────────────────

Future<void> insertAgent(AgentPersona agent) async {
  final db = await _db;
  await db.insert(
    'agents',
    agent.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> updateAgent(AgentPersona agent) async {
  final db = await _db;
  await db.update(
    'agents',
    agent.toMap(),
    where: 'id = ?',
    whereArgs: [agent.id],
  );
}

Future<void> deleteAgent(String id) async {
  final db = await _db;
  await db.delete('agents', where: 'id = ?', whereArgs: [id]);
}

Future<List<AgentPersona>> getAgents(String groupId) async {
  final db = await _db;
  final maps = await db.query(
    'agents',
    where: 'groupId = ?',
    whereArgs: [groupId],
  );
  return maps.map(AgentPersona.fromMap).toList();
}

// ── Users ─────────────────────────────────────────────────────────────────────

Future<void> insertUser(UserPersona user) async {
  final db = await _db;
  await db.insert(
    'users',
    user.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> deleteUser(String id) async {
  final db = await _db;
  await db.delete('users', where: 'id = ?', whereArgs: [id]);
}

Future<List<UserPersona>> getUsers() async {
  final db = await _db;
  final maps = await db.query('users');
  return maps.map(UserPersona.fromMap).toList();
}

// ── History ───────────────────────────────────────────────────────────────────

Future<void> clearAllHistory(String groupId) async {
  final db = await _db;
  await db.delete('messages', where: 'groupId = ?', whereArgs: [groupId]);
  await db.delete('sessions', where: 'groupId = ?', whereArgs: [groupId]);
}
