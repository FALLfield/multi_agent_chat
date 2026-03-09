import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_persona.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/group.dart';
import 'database_service.dart';
import 'group_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum DiscussionMode { sequential, concurrent }

class ChatService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final GroupService _groupService = GroupService();

  StreamSubscription<List<AgentPersona>>? _agentSubscription;
  StreamSubscription<List<ChatSession>>? _sessionSubscription;
  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  StreamSubscription<Group>? _groupSettingsSubscription;

  final Map<String, String> _localStreamingText = {};

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages {
    return _messages.map((m) {
      if (_localStreamingText.containsKey(m.id)) {
        return ChatMessage(
          id: m.id,
          text: _localStreamingText[m.id]!,
          createdAt: m.createdAt,
          isUser: m.isUser,
          agent: m.agent,
          sessionId: m.sessionId,
          isConclusion: m.isConclusion,
          senderName: m.senderName,
          replyTo: m.replyTo,
          groupId: m.groupId,
        );
      }
      return m;
    }).toList();
  }

  String? _activeSessionId;
  String? get activeSessionId => _activeSessionId;

  List<ChatSession> _sessions = [];
  List<ChatSession> get sessions => _sessions;

  DiscussionMode _discussionMode = DiscussionMode.sequential;
  DiscussionMode get discussionMode => _discussionMode;

  void setDiscussionMode(DiscussionMode mode) {
    _discussionMode = mode;
    notifyListeners();
    // Persist to Firestore so all group members sync
    if (_activeGroupId != null) {
      _groupService.updateDiscussionSettings(
        groupId: _activeGroupId!,
        rounds: _discussionRounds,
        mode: mode == DiscussionMode.sequential ? 'sequential' : 'concurrent',
      );
    }
  }

  int _discussionRounds = 1;
  int get discussionRounds => _discussionRounds;

  Future<void> setDiscussionRounds(int rounds) async {
    _discussionRounds = rounds;
    notifyListeners();
    // Persist to Firestore so all group members sync
    if (_activeGroupId != null) {
      await _groupService.updateDiscussionSettings(
        groupId: _activeGroupId!,
        rounds: rounds,
        mode: _discussionMode == DiscussionMode.sequential
            ? 'sequential'
            : 'concurrent',
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('discussion_rounds', rounds);
    }
  }

  String get _currentUserName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "User";
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!;
    }
    if (user.email != null) {
      return user.email!.split('@').first;
    }
    return "User";
  }

  ChatService() {
    _initService();
  }

  Future<void> _initService() async {
    await _loadSettings();
    await _loadAgents();
    await _loadSessions();
  }

  // The roster of agents participating in the round table
  List<AgentPersona> _activeAgents = [];
  List<AgentPersona> get activeAgents => _activeAgents;

  String? _activeGroupId;
  String? get activeGroupId => _activeGroupId;

  Future<void> enterGroupMode(Group group) async {
    _activeGroupId = group.id;
    await _loadAgents();
    await _loadSessions();
    _startStreams();
  }

  void _startStreams() {
    if (_activeGroupId == null) return;
    _agentSubscription?.cancel();
    _agentSubscription = _dbService.streamAgents(_activeGroupId!).listen((
      agents,
    ) {
      _activeAgents = agents;
      notifyListeners();
    });

    // Bug1 fix: sync discussionRounds & discussionMode from Firestore in real-time
    _groupSettingsSubscription?.cancel();
    _groupSettingsSubscription = _groupService
        .streamGroup(_activeGroupId!)
        .listen((group) {
          final newMode = group.discussionMode == 'concurrent'
              ? DiscussionMode.concurrent
              : DiscussionMode.sequential;
          final newRounds = group.discussionRounds;
          if (_discussionMode != newMode || _discussionRounds != newRounds) {
            _discussionMode = newMode;
            _discussionRounds = newRounds;
            notifyListeners();
          }
        });

    _sessionSubscription?.cancel();
    _sessionSubscription = _dbService.streamSessions(_activeGroupId!).listen((
      sessionsList,
    ) {
      _sessions = sessionsList;
      if (_sessions.isNotEmpty) {
        // Bug3 fix: only auto-navigate if the current session was deleted
        // (i.e. _activeSessionId is no longer in the list).
        // Do NOT jump when another user creates a new session.
        if (_activeSessionId == null) {
          loadSession(_sessions.first.id);
        } else if (!sessionsList.any((s) => s.id == _activeSessionId)) {
          // Current session was deleted — navigate to the newest one
          loadSession(_sessions.first.id);
        } else {
          notifyListeners();
        }
      } else {
        if (_activeSessionId == null) {
          createNewSession();
        }
      }
    });
  }

  void exitGroupMode() {
    _activeGroupId = null;
    _activeAgents = [];
    _sessions = [];
    _messages = [];
    _localStreamingText.clear();
    _agentSubscription?.cancel();
    _sessionSubscription?.cancel();
    _messageSubscription?.cancel();
    _groupSettingsSubscription?.cancel();
    notifyListeners();
  }

  Future<void> _loadAgents() async {
    if (_activeGroupId == null) return;
    _activeAgents = await _dbService.getAgents(_activeGroupId!);
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
    _localStreamingText.clear();
    _activeSessionId = sessionId;
    _messages = await _dbService.getMessagesForSession(
      sessionId,
      _activeAgents,
    );
    _messageSubscription?.cancel();
    _messageSubscription = _dbService
        .streamMessages(sessionId, _activeAgents)
        .listen((msgs) {
          _messages = msgs;
          notifyListeners();
        });
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
    _messageSubscription?.cancel();
    _messageSubscription = _dbService
        .streamMessages(newSession.id, _activeAgents)
        .listen((msgs) {
          _messages = msgs;
          notifyListeners();
        });
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

  Future<void> deleteSession(String sessionId) async {
    await _dbService.deleteSession(sessionId);
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
      _messages = [];
      _messageSubscription?.cancel();
      if (_sessions.isNotEmpty) {
        await loadSession(_sessions.first.id);
      } else {
        await createNewSession();
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> clearAllHistory() async {
    if (_activeGroupId == null) return;
    await _dbService.clearAllHistory(_activeGroupId!);
    _sessions = [];
    createNewSession();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedIds = prefs.getStringList('participating_agents');
    if (savedIds != null) {
      _participatingAgentIds = savedIds.toSet();
    } else {
      _participatingAgentIds = _activeAgents.map((a) => a.id).toSet();
    }

    _discussionRounds = prefs.getInt('discussion_rounds') ?? 1;

    notifyListeners();
  }

  String getApiKey(String provider, {AgentPersona? agent}) {
    if (agent != null && agent.apiKey.isNotEmpty) return agent.apiKey;
    return '';
  }

  String getEffectiveDoubaoEndpoint({AgentPersona? agent}) {
    if (agent != null && agent.doubaoEndpoint.isNotEmpty) {
      return agent.doubaoEndpoint;
    }
    return '';
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
      senderName: _currentUserName,
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

    final userName = _currentUserName;
    String contextAccumulator = "User [$userName] asking: $questionText\n\n";

    final allParticipatingAgents = _activeAgents
        .where((a) => _participatingAgentIds.contains(a.id))
        .toList();

    // --- @Mention Directed Invocation ---
    // If the user's message contains @SomeAgentName, only invoke that agent.
    // If @RealUserName is mentioned, inject that user's recent messages as context.
    final mentionedAgents = <AgentPersona>[];
    String userMentionContext = '';
    final mentionRegex = RegExp(r'@(\S+)');
    final mentionMatches = mentionRegex.allMatches(questionText);
    if (mentionMatches.isNotEmpty) {
      for (final match in mentionMatches) {
        final raw = match.group(1)!.toLowerCase();
        // Try to find an agent whose name contains the mentioned keyword
        final foundAgents = allParticipatingAgents.where(
          (a) => a.name.toLowerCase().contains(raw),
        );
        mentionedAgents.addAll(foundAgents);

        // Bug2 fix: if no agent matched, look for a real user by senderName
        if (foundAgents.isEmpty) {
          final userMessages = _messages
              .where(
                (m) =>
                    m.isUser &&
                    (m.senderName?.toLowerCase().contains(raw) ?? false),
              )
              .toList();
          if (userMessages.isNotEmpty) {
            // Take the last 3 messages from that user as context
            final recent = userMessages.length > 3
                ? userMessages.sublist(userMessages.length - 3)
                : userMessages;
            final userName = userMessages.last.senderName ?? raw;
            userMentionContext +=
                '\n\n【用户 $userName 的最近发言，请针对这些内容进行讨论】:\n' +
                recent.map((m) => '- ${m.text}').join('\n');
          }
        }
      }
    }
    // Use mentioned agents if found, otherwise all participating agents
    final isDirectMention = mentionedAgents.isNotEmpty;
    final participatingAgents = isDirectMention
        ? mentionedAgents.toSet().toList()
        : allParticipatingAgents;

    // Append user mention context to the accumulator
    if (userMentionContext.isNotEmpty) {
      contextAccumulator += userMentionContext;
    }

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

        // Step 1: each agent gives their own closing summary
        for (var agent in participatingAgents) {
          if (_isCancelled) break;
          final prompt =
              "$contextAccumulator\n\n【系统附加指令】：作为辩论收尾，请在刚才多轮交锋的基础上，用一段话（100字以内）提炼出你自己的最终立场与核心观点。";
          final history = _buildHistoryPayload(agent, 6);
          final responseText = await _processAgentTurn(
            agent,
            prompt,
            isConclusion: true,
            historyPayload: history,
          );
          contextAccumulator += "\n<${agent.name} 最终立场>: $responseText\n";
          await Future.delayed(const Duration(milliseconds: 500));
        }

        // Step 2: a neutral moderator agent synthesizes everything into one final verdict
        if (!_isCancelled) {
          final firstAgent = participatingAgents.first;
          final moderatorAgent = AgentPersona(
            id: 'moderator_final',
            name: '主持人 (Moderator)',
            systemInstruction:
                '你是一位中立、客观的讨论主持人。你的职责是综合所有参与者的观点，提炼核心分歧与共识，给出一个公正、全面的最终结论。',
            provider: firstAgent.provider,
            modelName: firstAgent.modelName,
            groupId: _activeGroupId ?? '',
            apiKey: firstAgent.apiKey,
            doubaoEndpoint: firstAgent.doubaoEndpoint,
          );
          final moderatorPrompt =
              "$contextAccumulator\n\n【系统附加指令】：以上是所有专家的最终立场。请你作为中立主持人，综合以上所有观点，用200字以内给出一个全面、客观的最终结论：包括各方最大分歧、达成的共识，以及你认为最有价值的洞见。";
          await _processAgentTurn(
            moderatorAgent,
            moderatorPrompt,
            isConclusion: true,
            historyPayload: [],
          );
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
    final apiKey = getApiKey(agent.provider, agent: agent);
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
    _localStreamingText[messageId] = newText;
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

    // Pick the first agent that has a key configured
    AgentPersona? summaryAgent;
    for (final a in _activeAgents) {
      if (a.apiKey.isNotEmpty) {
        summaryAgent = AgentPersona(
          id: 'summarizer',
          name: 'Summarizer',
          systemInstruction: '你是一个专业的会议摘要生成器，输出简洁、准确，不超过200字。',
          provider: a.provider,
          modelName: a.modelName,
          groupId: _activeGroupId ?? '',
          apiKey: a.apiKey,
          doubaoEndpoint: a.doubaoEndpoint,
        );
        break;
      }
    }
    if (summaryAgent == null) return;

    final existingSummary = _sessions[sessionIndex].summary ?? '';
    final summarizePrompt = existingSummary.isNotEmpty
        ? '你是一个讨论摘要生成器。请将以下最新的讨论记录，与之前的摘要合并，生成一份新的、不超过200字的核心摘要。重点提炼：主要分歧、共识、和各方关键观点。\n\n【已有摘要】:\n$existingSummary\n\n【最新讨论记录】:\n$transcript'
        : '你是一个讨论摘要生成器。请将以下讨论记录，生成一份不超过200字的核心摘要。重点提炼：主要分歧、共识、和各方关键观点。\n\n【讨论记录】:\n$transcript';

    try {
      // Collect the full summary text
      String newSummary = '';
      final summarizeClient = http.Client();
      try {
        final stream = _callLLMStream(
          summaryAgent,
          [],
          summarizePrompt,
          summaryAgent.apiKey,
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
        agent.provider == 'doubao' && getEffectiveDoubaoEndpoint(agent: agent).isNotEmpty
        ? getEffectiveDoubaoEndpoint(agent: agent)
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
