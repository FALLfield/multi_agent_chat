// Web stub — all functions are no-ops / return empty lists.
// dart2js only ever sees this file, so sqflite symbols never enter the web build.
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/agent_persona.dart';
import '../models/user_persona.dart';

Future<void> insertSession(ChatSession session) async {}
Future<void> updateSession(ChatSession session) async {}
Future<List<ChatSession>> getSessions(String groupId) async => [];

Future<void> insertMessage(ChatMessage message) async {}
Future<void> updateMessage(ChatMessage message) async {}
Future<List<Map<String, dynamic>>> getMessagesForSession(
  String sessionId,
) async => [];

Future<void> insertAgent(AgentPersona agent) async {}
Future<void> updateAgent(AgentPersona agent) async {}
Future<void> deleteAgent(String id) async {}
Future<List<AgentPersona>> getAgents(String groupId) async => [];

Future<void> insertUser(UserPersona user) async {}
Future<void> deleteUser(String id) async {}
Future<List<UserPersona>> getUsers() async => [];

Future<void> clearAllHistory(String groupId) async {}
