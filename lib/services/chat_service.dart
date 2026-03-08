import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_persona.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/user_persona.dart';
import '../models/group.dart';
import 'database_service.dart';

enum DiscussionMode { sequential, concurrent }

class ChatService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  // Store API Keys
  final Map<String, String> _apiKeys = {
    'kimi': '',
    'doubao': '',
    'deepseek': '',
  };

  String _doubaoEndpoint = '';
  String get doubaoEndpoint => _doubaoEndpoint;

  // Store Group API Keys
  Map<String, String>? _groupApiKeys;
  String? _groupDoubaoEndpoint;

  String? _activeSessionId;
  String? get activeSessionId => _activeSessionId;

  List<ChatSession> _sessions = [];
  List<ChatSession> get sessions => _sessions;

  DiscussionMode _discussionMode = DiscussionMode.sequential;
  DiscussionMode get discussionMode => _discussionMode;

  void setDiscussionMode(DiscussionMode mode) {
    _discussionMode = mode;
    notifyListeners();
  }

  int _discussionRounds = 1;
  int get discussionRounds => _discussionRounds;

  Future<void> setDiscussionRounds(int rounds) async {
    _discussionRounds = rounds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('discussion_rounds', rounds);
  }

  List<UserPersona> _users = [];
  List<UserPersona> get users => _users;

  UserPersona? _currentUser;
  UserPersona? get currentUser => _currentUser;

  void setCurrentUser(UserPersona user) {
    _currentUser = user;
    notifyListeners();
  }

  ChatService() {
    _initService();
  }

  Future<void> _initService() async {
    await _loadApiKeys();
    await _loadUsers();
    await _loadAgents();
    await _loadSessions();
  }

  Future<void> _loadUsers() async {
    _users = await _dbService.getUsers();
    if (_users.isEmpty) {
      final defaultUser = UserPersona(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'User 1',
      );
      await _dbService.insertUser(defaultUser);
      _users.add(defaultUser);
    }
    _currentUser = _users.first;
    notifyListeners();
  }

  Future<void> addUser(String name) async {
    final newUser = UserPersona(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    await _dbService.insertUser(newUser);
    _users.add(newUser);
    _currentUser = newUser;
    notifyListeners();
  }

  Future<void> deleteUser(String id) async {
    await _dbService.deleteUser(id);
    _users.removeWhere((u) => u.id == id);
    if (_currentUser?.id == id) {
      _currentUser = _users.isNotEmpty ? _users.first : null;
    }
    notifyListeners();
  }

  // The roster of agents participating in the round table
  List<AgentPersona> _activeAgents = [];
  List<AgentPersona> get activeAgents => _activeAgents;

  String? _activeGroupId;
  String? get activeGroupId => _activeGroupId;

  Future<void> enterGroupMode(Group group) async {
    _activeGroupId = group.id;
    setGroupApiKeys(group.apiKeys, group.doubaoEndpoint);
    await _loadAgents();
    await _loadSessions();
  }

  void exitGroupMode() {
    _activeGroupId = null;
    clearGroupApiKeys();
    _activeAgents = [];
    _sessions = [];
    _messages = [];
    notifyListeners();
  }

  Future<void> _loadAgents() async {
    if (_activeGroupId == null) return;
    _activeAgents = await _dbService.getAgents(_activeGroupId!);
    if (_activeAgents.isEmpty) {
      // Pick the first provider that actually has an API key configured
      final providerPriority = ['kimi', 'deepseek', 'doubao'];
      final modelMap = {
        'kimi': 'moonshot-v1-8k',
        'deepseek': 'deepseek-chat',
        'doubao': 'doubao-pro-32k',
      };
      String bestProvider = providerPriority.first;
      String bestModel = modelMap[bestProvider]!;
      for (final p in providerPriority) {
        if (getApiKey(p).isNotEmpty) {
          bestProvider = p;
          bestModel = modelMap[p]!;
          break;
        }
      }

      final defaults = [
        AgentPersona(
          id: 'agent_philosopher_${_activeGroupId!}',
          name: '哲学家 (Philosopher)',
          systemInstruction: '你是一位深邃的哲学家。请用苏格拉底式的引导方式，从伦理、道德、存在主义角度剖析当前问题。',
          provider: bestProvider,
          modelName: bestModel,
          groupId: _activeGroupId!,
        ),
        AgentPersona(
          id: 'agent_doctor_${_activeGroupId!}',
          name: '医生 (Doctor)',
          systemInstruction: '你是一位专业的临床主治医生。回复请带有职业素养，用循证医学的结构化思维去诊断问题的根本原因。',
          provider: bestProvider,
          modelName: bestModel,
          groupId: _activeGroupId!,
        ),
        AgentPersona(
          id: 'agent_programmer_${_activeGroupId!}',
          name: '程序员 (Programmer)',
          systemInstruction:
              '你是一位高级全栈工程师。你信奉代码就是真理，喜欢用计算机科学、算法结构、系统架构等编程概念来解构现实世界。',
          provider: bestProvider,
          modelName: bestModel,
          groupId: _activeGroupId!,
        ),
      ];
      for (var agent in defaults) {
        await _dbService.insertAgent(agent);
        _activeAgents.add(agent);
      }
    }
    notifyListeners();
  }

  Future<void> _loadSessions() async {
    if (_activeGroupId == null) return;
    _sessions = await _dbService.getSessions(_activeGroupId!);
    if (_sessions.isNotEmpty) {
      await loadSession(_sessions.first.id);
    } else {
      createNewSession();
    }
  }

  Future<void> loadSession(String sessionId) async {
    _activeSessionId = sessionId;
    _messages = await _dbService.getMessagesForSession(
      sessionId,
      _activeAgents,
    );
    notifyListeners();
  }

  Future<void> createNewSession() async {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Discussion',
      createdAt: DateTime.now(),
      groupId: _activeGroupId ?? '',
    );
    await _dbService.insertSession(newSession);
    _sessions.insert(0, newSession);
    _activeSessionId = newSession.id;
    _messages = [];
    notifyListeners();
  }

  Future<void> renameSession(String sessionId, String newTitle) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    final updated = ChatSession(
      id: sessionId,
      title: newTitle.trim().isEmpty ? 'New Discussion' : newTitle.trim(),
      createdAt: _sessions[idx].createdAt,
      groupId: _sessions[idx].groupId,
    );
    _sessions[idx] = updated;
    await _dbService.updateSession(updated);
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    if (_activeGroupId == null) return;
    await _dbService.clearAllHistory(_activeGroupId!);
    _sessions = [];
    createNewSession();
  }

  Future<void> _loadApiKeys() async {
    final prefs = await SharedPreferences.getInstance();

    // Auto-inject previous macOS keys for seamless Web transition
    if (prefs.getString('api_key_doubao') == null) {
      await prefs.setString(
        'api_key_doubao',
        '5df968da-0311-4ce7-9fc0-75e4e5fcf79d',
      );
      await prefs.setString('doubao_endpoint', 'doubao-seed-2-0-pro-260215');
      await prefs.setString(
        'api_key_deepseek',
        'sk-7a738ef7e5e3435facc6e1e30815b805',
      );
      await prefs.setString(
        'api_key_kimi',
        'sk-qZ4wI9mkso1UACFsYmKgZgF6kH4nHAXEuSw34hp0pxjPIrYK',
      );
    }

    for (final provider in _apiKeys.keys) {
      final key = prefs.getString('api_key_$provider');
      if (key != null) {
        _apiKeys[provider] = key;
      }
    }
    _doubaoEndpoint = prefs.getString('doubao_endpoint') ?? '';

    final savedIds = prefs.getStringList('participating_agents');
    if (savedIds != null) {
      _participatingAgentIds = savedIds.toSet();
    } else {
      // Default to all agents if never saved
      _participatingAgentIds = _activeAgents.map((a) => a.id).toSet();
    }

    _discussionRounds = prefs.getInt('discussion_rounds') ?? 1;

    notifyListeners();
  }

  Future<void> updateApiKey(String provider, String key) async {
    _apiKeys[provider] = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key_$provider', key);
    notifyListeners();
  }

  Future<void> updateDoubaoEndpoint(String endpoint) async {
    _doubaoEndpoint = endpoint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('doubao_endpoint', endpoint);
    notifyListeners();
  }

  void setGroupApiKeys(Map<String, String> keys, String doubaoEndpoint) {
    _groupApiKeys = keys;
    _groupDoubaoEndpoint = doubaoEndpoint;
  }

  void clearGroupApiKeys() {
    _groupApiKeys = null;
    _groupDoubaoEndpoint = null;
  }

  String getApiKey(String provider) {
    if (_groupApiKeys != null && _groupApiKeys![provider]?.isNotEmpty == true) {
      return _groupApiKeys![provider]!;
    }
    return _apiKeys[provider] ?? '';
  }

  String getEffectiveDoubaoEndpoint() {
    if (_groupDoubaoEndpoint != null && _groupDoubaoEndpoint!.isNotEmpty) {
      return _groupDoubaoEndpoint!;
    }
    return _doubaoEndpoint;
  }

  Set<String> _participatingAgentIds = {};
  Set<String> get participatingAgentIds => _participatingAgentIds;

  bool isAgentParticipating(String id) => _participatingAgentIds.contains(id);

  Future<void> toggleAgentParticipation(String id, bool participates) async {
    if (participates) {
      _participatingAgentIds.add(id);
    } else {
      _participatingAgentIds.remove(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'participating_agents',
      _participatingAgentIds.toList(),
    );
  }

  // --- Agent Management Methods ---

  Future<void> addAgent(AgentPersona agent) async {
    await _dbService.insertAgent(agent);
    _activeAgents.add(agent);
    notifyListeners();
  }

  Future<void> updateAgentDetails(AgentPersona agent) async {
    await _dbService.updateAgent(agent);
    final index = _activeAgents.indexWhere((a) => a.id == agent.id);
    if (index != -1) {
      _activeAgents[index] = agent;
      notifyListeners();
    }
  }

  Future<void> deleteAgent(String id) async {
    await _dbService.deleteAgent(id);
    _activeAgents.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isCancelled = false;
  http.Client? _httpClient;

  void stopGeneration() {
    _isCancelled = true;
    _httpClient?.close();
    _httpClient = null;
    _isProcessing = false;
    notifyListeners();
  }

  /// Starts the discussion pipeline
  Future<void> submitQuestion(String questionText) async {
    if (questionText.trim().isEmpty || _isProcessing) return;

    _isCancelled = false;
    _httpClient = http.Client();

    // 1. Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: questionText,
      createdAt: DateTime.now(),
      isUser: true,
      sessionId: _activeSessionId,
      senderName: _currentUser?.name,
      groupId: _activeGroupId ?? '',
    );
    _messages.add(userMessage);
    await _dbService.insertMessage(userMessage);

    // Update session title for the very first message
    if (_messages.length == 1 && _activeSessionId != null) {
      final sessionIndex = _sessions.indexWhere(
        (s) => s.id == _activeSessionId,
      );
      if (sessionIndex != -1) {
        final title = questionText.length > 20
            ? '${questionText.substring(0, 20)}...'
            : questionText;
        final updatedSession = ChatSession(
          id: _activeSessionId!,
          title: title,
          createdAt: _sessions[sessionIndex].createdAt,
          groupId: _activeGroupId ?? '',
        );
        _sessions[sessionIndex] = updatedSession;
        await _dbService.insertSession(updatedSession);
      }
    }

    _isProcessing = true;
    notifyListeners();

    final userName = _currentUser?.name ?? "User";
    String contextAccumulator = "User [$userName] asking: $questionText\n\n";

    final allParticipatingAgents = _activeAgents
        .where((a) => _participatingAgentIds.contains(a.id))
        .toList();

    // --- @Mention Directed Invocation ---
    // If the user's message contains @SomeAgentName, only invoke that agent.
    final mentionedAgents = <AgentPersona>[];
    final mentionRegex = RegExp(r'@(\S+)');
    final mentionMatches = mentionRegex.allMatches(questionText);
    if (mentionMatches.isNotEmpty) {
      for (final match in mentionMatches) {
        final raw = match.group(1)!.toLowerCase();
        // Try to find an agent whose name contains the mentioned keyword
        final found = allParticipatingAgents.where(
          (a) => a.name.toLowerCase().contains(raw),
        );
        mentionedAgents.addAll(found);
      }
    }
    // Use mentioned agents if found, otherwise all participating agents
    final isDirectMention = mentionedAgents.isNotEmpty;
    final participatingAgents = isDirectMention
        ? mentionedAgents
              .toSet()
              .toList() // .toSet() deduplicates
        : allParticipatingAgents;

    if (participatingAgents.isEmpty) {
      // Fallback message if no agents are active
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "System: 请前往配置页至少勾选一位参与讨论的 AI Agent。",
        createdAt: DateTime.now(),
        isUser: false,
        sessionId: _activeSessionId,
        groupId: _activeGroupId ?? '',
      );
      _messages.add(errorMessage);
      await _dbService.insertMessage(errorMessage);
      _isProcessing = false;
      notifyListeners();
      return;
    }

    if (_discussionMode == DiscussionMode.sequential) {
      // 2. Sequential Discussion Pipeline (Multi-Round)
      // For direct @mentions (user targeting a specific agent), always single round
      final effectiveRounds = isDirectMention ? 1 : _discussionRounds;
      for (int i = 0; i < effectiveRounds; i++) {
        if (_isCancelled) break;
        if (effectiveRounds > 1) {
          contextAccumulator += "\n--- 第 ${i + 1} 轮讨论 ---\n";
        }
        for (var agent in participatingAgents) {
          if (_isCancelled) break;
          String systemDebatePrompt = "";
          if (i > 0) {
            systemDebatePrompt =
                "\n\n【系统附加指令】：这是第 ${i + 1} 轮辩论回合。请你作为专家 ${agent.name}，强力且犀利地反驳或补充上方其他专家的观点，直击逻辑痛点。务必将发言控制在 150 字以内，保持火药味。";
          } else if (effectiveRounds > 1) {
            systemDebatePrompt =
                "\n\n【系统附加指令】：这是多轮讨论的第一轮。请你作为 ${agent.name} 发表独立初步观点。立场鲜明，并且将发言严格控制在 150 字左右。";
          }

          final finalPrompt = contextAccumulator + systemDebatePrompt;
          // Strict reply-attribution instruction:
          // The LLM must put ONLY "@SomeName" on the very first line if replying
          // to someone specific, and nothing else on that line.
          final replyHint = (_messages.length > 1 && !isDirectMention)
              ? "\n\n【严格格式指令 — 必须遵守】：如果你的回复主要针对某一个特定人的观点，你必须在回复的第一行单独写 @对方名字（例如：@先锋艺术家），该行不能有任何其他文字。第二行起再写正文内容。如果是综合性发言，直接写正文，不要加 @ 标注。"
              : "";
          final history = _buildHistoryPayload(agent, 6);
          final responseText = await _processAgentTurn(
            agent,
            finalPrompt + replyHint,
            historyPayload: history,
          );
          contextAccumulator += "\n<${agent.name}>: $responseText\n";

          // Wait a bit to simulate thinking or streaming delay
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Conclusion Phase — only for multi-round non-directed discussions
      if (effectiveRounds > 1 && !isDirectMention && !_isCancelled) {
        contextAccumulator += "\n--- 结论阶段 ---\n";
        for (var agent in participatingAgents) {
          if (_isCancelled) break;
          final prompt =
              "$contextAccumulator\n\n【系统附加指令】：作为辩论收尾，请在刚才多轮交锋的基础上，用一段话（100字以内）提炼出最大的分歧点和最终共识。";
          final replyHint =
              "\n【回复标注指令】：如果你在收尾时主要是认同或反对某一特定专家的总结，请在回复第一行写 @[那个专家名字]，然后换行写正文。";
          final history = _buildHistoryPayload(agent, 6);
          final responseText = await _processAgentTurn(
            agent,
            prompt + replyHint,
            isConclusion: true,
            historyPayload: history,
          );
          contextAccumulator += "\n<${agent.name} 最终裁决>: $responseText\n";
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } else {
      // 3. Concurrent Discussion Pipeline
      List<Future<void>> futures = [];
      for (var agent in participatingAgents) {
        if (_isCancelled) break;
        final replyHint = (_messages.length > 1 && !isDirectMention)
            ? "\n\n【严格格式指令 — 必须遵守】：如果你的回复主要针对某一个特定人的观点，你必须在回复的第一行单独写 @对方名字（例如：@先锋艺术家），该行不能有任何其他文字。第二行起再写正文内容。如果是综合性发言，直接写正文，不要加 @ 标注。"
            : "";
        final history = _buildHistoryPayload(agent, 6);
        futures.add(
          _processAgentTurn(
            agent,
            contextAccumulator + replyHint,
            historyPayload: history,
          ),
        );
      }
      await Future.wait(futures);
    }

    _isProcessing = false;
    _httpClient?.close();
    _httpClient = null;
    notifyListeners();

    // Async summarization: skip for direct @mention invocations (single targeted reply)
    if (!isDirectMention) {
      _triggerSummarization();
    }
  }

  Future<String> _processAgentTurn(
    AgentPersona agent,
    String promptText, {
    bool isConclusion = false,
    List<Map<String, String>>? historyPayload,
  }) async {
    final messageId =
        '${DateTime.now().millisecondsSinceEpoch}_${agent.id}_${UniqueKey().toString()}';

    // Simulate streaming by progressively updating the message
    final newMessage = ChatMessage(
      id: messageId,
      text: "Thinking...",
      createdAt: DateTime.now(),
      isUser: false,
      agent: agent,
      sessionId: _activeSessionId,
      isConclusion: isConclusion,
      groupId: _activeGroupId ?? '',
    );
    _messages.add(newMessage);
    await _dbService.insertMessage(newMessage);
    notifyListeners();

    String currentResponse = "";
    final apiKey = getApiKey(agent.provider);
    if (apiKey.isEmpty) {
      _updateMessageText(
        messageId,
        newMessage,
        agent,
        "⚠️ 请在设置中配置 **${agent.provider}** 的 API Key。",
        isConclusion,
      );
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) await _dbService.updateMessage(_messages[idx]);
      return currentResponse;
    }

    try {
      final responseStream = _callLLMStream(
        agent,
        historyPayload ?? [],
        promptText,
        apiKey,
      );

      await for (final chunk in responseStream) {
        if (_isCancelled) {
          currentResponse += "\n\n*[Stopped by user]*";
          _updateMessageText(
            messageId,
            newMessage,
            agent,
            currentResponse,
            isConclusion,
          );
          break;
        }
        currentResponse += chunk;
        _updateMessageText(
          messageId,
          newMessage,
          agent,
          currentResponse,
          isConclusion,
        );
      }

      // Save final message to DB
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) await _dbService.updateMessage(_messages[idx]);
    } catch (e) {
      _updateMessageText(
        messageId,
        newMessage,
        agent,
        "❌ ERROR: $e",
        isConclusion,
      );
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) await _dbService.updateMessage(_messages[idx]);
    }
    // Parse replyTo from the final response (the LLM may prefix @Name on the first line)
    String? parsedReplyTo;
    String displayText = currentResponse;
    final lines = currentResponse.split('\n');
    if (lines.isNotEmpty) {
      final firstLine = lines[0].trim();
      // Match @Name where Name is letters/digits/CJK — stops at punctuation/space
      final replyPattern = RegExp(r'^@([^\s，,、。！？!?；:：]+)');
      final inlineMatch = replyPattern.firstMatch(firstLine);
      if (inlineMatch != null) {
        parsedReplyTo = inlineMatch.group(1);
        // Strip the @Name (and any immediately following punctuation/space) from text
        final afterName = firstLine
            .substring(inlineMatch.end)
            .replaceFirst(RegExp(r'^[，,、\s]+'), '');
        final rest = lines.length > 1 ? '\n${lines.sublist(1).join('\n')}' : '';
        // If the first line had more content beyond @Name, prepend it
        displayText = afterName.isNotEmpty
            ? afterName + rest
            : lines.sublist(1).join('\n').trimLeft();
      }
    }

    // Update the message with the parsed replyTo and cleaned display text
    if (parsedReplyTo != null) {
      _updateMessageText(
        messageId,
        newMessage,
        agent,
        displayText,
        isConclusion,
        replyTo: parsedReplyTo,
      );
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) await _dbService.updateMessage(_messages[idx]);
    }

    return displayText.isEmpty ? currentResponse : displayText;
  }

  void _updateMessageText(
    String messageId,
    ChatMessage original,
    AgentPersona agent,
    String newText,
    bool isConclusion, {
    String? replyTo,
  }) {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final updatedMessage = ChatMessage(
        id: messageId,
        text: newText,
        createdAt: original.createdAt,
        isUser: false,
        agent: agent,
        sessionId: _activeSessionId,
        isConclusion: isConclusion,
        groupId: _activeGroupId ?? '',
        // Preserve existing replyTo if no new one was parsed yet
        replyTo: replyTo ?? _messages[idx].replyTo,
      );
      _messages[idx] = updatedMessage;
      notifyListeners();
    }
  }

  /// Builds the sliding window history payload for a given agent.
  /// Includes the session summary and the last [windowSize] messages.
  List<Map<String, String>> _buildHistoryPayload(
    AgentPersona currentAgent,
    int windowSize,
  ) {
    final sessionIndex = _sessions.indexWhere((s) => s.id == _activeSessionId);
    final session = sessionIndex != -1 ? _sessions[sessionIndex] : null;

    final List<Map<String, String>> payload = [];

    // 1. Inject session summary as a system memory if available
    if (session?.summary != null && session!.summary!.isNotEmpty) {
      payload.add({
        'role': 'system',
        'content': '【历史讨论记忆摘要】:\n${session.summary}',
      });
    }

    // 2. Inject the most recent messages as sliding-window context
    // Exclude the last message (which is the current user question, will be the 'user' prompt)
    final recentMessages = _messages.length > windowSize + 1
        ? _messages.sublist(
            _messages.length - windowSize - 1,
            _messages.length - 1,
          )
        : _messages.sublist(0, _messages.isNotEmpty ? _messages.length - 1 : 0);

    for (final msg in recentMessages) {
      if (msg.isUser) {
        payload.add({
          'role': 'user',
          'content': '[User: ${msg.senderName ?? "User"}] 说: ${msg.text}',
        });
      } else if (msg.agent?.id == currentAgent.id) {
        // This agent's own previous message → as assistant
        payload.add({'role': 'assistant', 'content': msg.text});
      } else {
        // Another agent's message → as a user turn (from the LLM's perspective)
        payload.add({
          'role': 'user',
          'content': '[Agent: ${msg.agent?.name ?? "Agent"}] 说: ${msg.text}',
        });
      }
    }

    return payload;
  }

  /// Fires in the background to summarize the session after discussion ends.
  /// Uses the cheapest/fastest available provider to save cost.
  Future<void> _triggerSummarization() async {
    final sessionMessages = _messages
        .where((m) => m.sessionId == _activeSessionId)
        .toList();
    if (sessionMessages.length < 10) {
      return; // Not enough context to summarize yet
    }

    final sessionIndex = _sessions.indexWhere((s) => s.id == _activeSessionId);
    if (sessionIndex == -1) return;

    // Build a compact transcript for the LLM to summarize
    final transcript = sessionMessages
        .map((m) {
          if (m.isUser) return '[User: ${m.senderName ?? "User"}]: ${m.text}';
          return '[Agent: ${m.agent?.name ?? "Agent"}]: ${m.text}';
        })
        .join('\n\n');

    // Pick the fastest available provider for summarization
    String? bestKey;
    String? bestProvider;
    String? bestModel;
    for (final entry in _apiKeys.entries) {
      if (entry.value.isNotEmpty) {
        bestProvider = entry.key;
        bestKey = entry.value;
        bestModel = _activeAgents
            .firstWhere(
              (a) => a.provider == bestProvider,
              orElse: () => AgentPersona(
                id: '',
                name: '',
                systemInstruction: '',
                provider: bestProvider!,
                modelName: bestProvider == 'doubao'
                    ? (getEffectiveDoubaoEndpoint().isNotEmpty
                          ? getEffectiveDoubaoEndpoint()
                          : 'doubao-pro-32k')
                    : (bestProvider == 'kimi'
                          ? 'moonshot-v1-8k'
                          : 'deepseek-chat'),
                groupId: _activeGroupId ?? '',
              ),
            )
            .modelName;
        break;
      }
    }

    if (bestKey == null || bestProvider == null) return;

    final existingSummary = _sessions[sessionIndex].summary ?? '';
    final summarizePrompt = existingSummary.isNotEmpty
        ? '你是一个讨论摘要生成器。请将以下最新的讨论记录，与之前的摘要合并，生成一份新的、不超过200字的核心摘要。重点提炼：主要分歧、共识、和各方关键观点。\n\n【已有摘要】:\n$existingSummary\n\n【最新讨论记录】:\n$transcript'
        : '你是一个讨论摘要生成器。请将以下讨论记录，生成一份不超过200字的核心摘要。重点提炼：主要分歧、共识、和各方关键观点。\n\n【讨论记录】:\n$transcript';

    try {
      final summaryAgent = AgentPersona(
        id: 'summarizer',
        name: 'Summarizer',
        systemInstruction: '你是一个专业的会议摘要生成器，输出简洁、准确，不超过200字。',
        provider: bestProvider,
        modelName: bestModel!,
        groupId: _activeGroupId ?? '',
      );

      // Collect the full summary text
      String newSummary = '';
      final summarizeClient = http.Client();
      try {
        final stream = _callLLMStream(
          summaryAgent,
          [],
          summarizePrompt,
          bestKey,
          client: summarizeClient,
        );
        await for (final chunk in stream) {
          newSummary += chunk;
        }
      } finally {
        summarizeClient.close();
      }

      if (newSummary.isNotEmpty) {
        final updatedSession = ChatSession(
          id: _sessions[sessionIndex].id,
          title: _sessions[sessionIndex].title,
          createdAt: _sessions[sessionIndex].createdAt,
          summary: newSummary,
          groupId: _activeGroupId ?? '',
        );
        _sessions[sessionIndex] = updatedSession;
        await _dbService.updateSession(updatedSession);
      }
    } catch (e) {
      // Silently ignore summarization failures — non-critical
    }
  }

  Stream<String> _callLLMStream(
    AgentPersona agent,
    List<Map<String, String>> historyMessages,
    String currentPrompt,
    String apiKey, {
    http.Client? client,
  }) async* {
    String baseUrl = '';

    switch (agent.provider) {
      case 'kimi':
        baseUrl = 'https://api.moonshot.cn/v1/chat/completions';
        break;
      case 'deepseek':
        baseUrl = 'https://api.deepseek.com/chat/completions';
        break;
      case 'qwen':
        baseUrl =
            'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
        break;
      case 'doubao': // Assuming Volcengine openai compat endpoint
        baseUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
        break;
      default:
        throw Exception("Unknown provider");
    }

    final modelToUse =
        agent.provider == 'doubao' && getEffectiveDoubaoEndpoint().isNotEmpty
        ? getEffectiveDoubaoEndpoint()
        : agent.modelName;

    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': agent.systemInstruction},
      // Inject history from sliding window (excludes system messages which are already at top)
      ...historyMessages.where((m) => m['role'] != 'system'),
      {'role': 'user', 'content': currentPrompt},
    ];

    final body = jsonEncode({
      "model": modelToUse,
      "messages": messages,
      "temperature": 0.7,
      "stream": true, // Request streaming!
    });

    final request = http.Request('POST', Uri.parse(baseUrl));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.body = body;

    // Use injected client (for summarization) or global http client (for main pipeline)
    final activeClient = client ?? _httpClient;
    if (activeClient == null) throw Exception("Request cancelled");
    final response = await activeClient.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception("Request failed [${response.statusCode}]: $errorBody");
    }

    final stream = response.stream.transform(utf8.decoder);
    String buffer = '';

    await for (final chunk in stream) {
      buffer += chunk;

      // SSE events are separated by double newline
      while (buffer.contains('\n\n')) {
        final index = buffer.indexOf('\n\n');
        final currentEvent = buffer.substring(0, index);
        buffer = buffer.substring(index + 2);

        // Typical OpenAI-compatible SSE format:
        // data: {"id":"...", "choices":[{"delta":{"content":"Hello"}}]}
        final lines = currentEvent.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') {
              return;
            }
            try {
              final dataJson = jsonDecode(dataStr);
              final delta = dataJson['choices'][0]['delta'];
              if (delta != null && delta['content'] != null) {
                yield delta['content'] as String;
              }
            } catch (e) {
              // Ignore malformed JSON or parts we don't care about
            }
          }
        }
      }
    }
  }
}
