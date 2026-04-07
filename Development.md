# Multi-Agent Chat — Development Documentation

> **Platform:** Flutter + Firebase · **Version:** 1.0.0 · **Language:** Dart ^3.10

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Requirements Analysis](#2-requirements-analysis)
3. [Feasibility Analysis](#3-feasibility-analysis)
4. [System Design](#4-system-design)
5. [Implementation](#5-implementation)
6. [AI Interaction Process](#6-ai-interaction-process)
7. [Testing & Known Issues](#7-testing--known-issues)
8. [Conclusion](#8-conclusion)

---

## 1. Project Overview

**Multi-Agent Chat** is a cross-platform Flutter application that lets users assemble a panel of AI agents — each configured with a distinct persona, LLM provider, and API key — and watch them collaboratively debate any topic in real time. Discussion results are shared across all group members via Firebase Firestore, making it a genuinely multi-user, collaborative AI experience.

### 1.1 Motivation

Existing AI chat tools interact with a single model at a time. This project explores a different paradigm: **pluralistic AI reasoning**, where multiple agents with different epistemic stances (analyst, critic, creative, pragmatist, etc.) argue about the same question, producing richer, more balanced insights than any single model would.

### 1.2 Core Concepts

| Concept | Description |
|---|---|
| **Agent** | An LLM persona with a name, system prompt, provider, model, and API key |
| **Group** | A shared workspace where members co-own a set of agents and sessions |
| **Session** | A persistent discussion thread within a group |
| **Discussion Round** | One full pass where every selected agent responds in turn |
| **Conclusion Phase** | After N rounds, each agent gives a closing stance; a neutral Moderator synthesises |

---

## 2. Requirements Analysis

### 2.1 Stakeholder & User Roles

| Role | Description | Permissions |
|---|---|---|
| **Group Leader** | Creates the group and owns its configuration | Full CRUD on agents, settings, sessions |
| **Group Member** | Joins via 6-character invite code | Submit questions, select agents, read sessions |
| **Unauthenticated User** | Not logged in | View login/signup screen only |

### 2.2 Functional Requirements

#### FR-1 Authentication
- FR-1.1 Users can register with email, password, and display name.
- FR-1.2 Users can log in and log out.
- FR-1.3 Friendly error messages are shown for common Firebase Auth error codes.

#### FR-2 Group Management
- FR-2.1 Leaders can create named groups; the system auto-generates a unique 6-character alphanumeric invite code.
- FR-2.2 Members can join a group by entering an invite code.
- FR-2.3 Members can leave a group; leaders can dissolve it (deletes the Firestore document).
- FR-2.4 Group membership and member display names sync in real time.

#### FR-3 Agent Management
- FR-3.1 Leaders can create, edit, and delete agents.
- FR-3.2 Each agent carries: name, system instruction, LLM provider, model name, API key, and (for Doubao) an endpoint ID.
- FR-3.3 Five built-in preset templates are available (Analyst, Creative, Critic, Pragmatist, Humanist).
- FR-3.4 API key fields are rendered as obscured password inputs.

#### FR-4 Discussion Sessions
- FR-4.1 Any member can create a new discussion session.
- FR-4.2 Session titles auto-populate from the first 20 characters of the opening message.
- FR-4.3 Sessions can be renamed or deleted.
- FR-4.4 All sessions within a group are visible to every member and sync in real time.

#### FR-5 Discussion Engine
- FR-5.1 **Sequential mode**: agents respond one by one; each agent sees all previous responses in the same round. After N rounds, a Conclusion Phase runs (each agent states a final position ≤100 words; a neutral Moderator synthesises ≤200 words).
- FR-5.2 **Concurrent mode**: all selected agents respond simultaneously via `Future.wait`.
- FR-5.3 Number of rounds (1–5) is configurable and syncs to all group members instantly.
- FR-5.4 The active discussion can be cancelled at any time; partial responses are preserved.

#### FR-6 @Mention System
- FR-6.1 `@AgentName` in a user message targets only that agent.
- FR-6.2 `@UserName` injects that user's last 3 messages as additional context.
- FR-6.3 Agents may prefix their replies with `@Name` to indicate reply attribution; this is stripped from the visible text and stored in the `replyTo` field.

#### FR-7 Agent Selection UI
- FR-7.1 A horizontally scrollable chip bar above the input field allows tap-based agent selection.
- FR-7.2 Selected agent count is shown as a hint ("N agents will respond").
- FR-7.3 All agents are selected by default when entering a session.

#### FR-8 Context & Memory
- FR-8.1 `_buildHistoryPayload()` constructs a sliding window of the last 6 messages per session.
- FR-8.2 After ≥10 messages, an auto-summarisation call generates a ≤200-word session summary stored in Firestore.
- FR-8.3 The summary is injected as a `system` message at the top of subsequent history payloads.

#### FR-9 Export
- FR-9.1 The current session can be exported as a Markdown file.
- FR-9.2 Export uses a platform split: `export_helper.dart` (native), `export_helper_web.dart` (web), `export_helper_stub.dart` (conditional import fallback).

#### FR-10 Internationalisation & Theme
- FR-10.1 UI strings support Chinese and English; all strings are defined as getter properties in `LocaleService`.
- FR-10.2 Light and dark themes are available; the user's preference is persisted via `SharedPreferences`.

### 2.3 Non-Functional Requirements

| ID | Requirement | Target |
|---|---|---|
| NFR-1 | **Responsiveness** | First streamed token appears within 2 s of submission |
| NFR-2 | **Cross-platform** | Runs on Web, iOS, Android, macOS, Linux, Windows |
| NFR-3 | **Real-time sync** | Firestore snapshot latency < 1 s under normal conditions |
| NFR-4 | **Security** | API keys stored in Firestore (not in client-side storage); obscured in UI |
| NFR-5 | **Scalability** | Firestore scales horizontally; no server infrastructure managed by the app |
| NFR-6 | **Usability** | Material 3 design; progressive disclosure pattern; accessible contrast ratios |
| NFR-7 | **Reliability** | Summarisation failures are silently swallowed; cancellation never corrupts state |

### 2.4 Use Case Summary

```
┌──────────────────────────────────────────────────────────────────┐
│  Unauthenticated User                                            │
│   └─ Register / Login                                            │
├──────────────────────────────────────────────────────────────────┤
│  Group Member                                                    │
│   ├─ Join Group (invite code)                                    │
│   ├─ Create / Select Session                                     │
│   ├─ Select Agents (chip bar or @mention)                        │
│   ├─ Submit Question → trigger discussion                        │
│   ├─ Stop Generation                                             │
│   ├─ Export Session                                              │
│   └─ Toggle Theme / Language                                     │
├──────────────────────────────────────────────────────────────────┤
│  Group Leader (all of the above, plus:)                          │
│   ├─ Create / Dissolve Group                                     │
│   ├─ Add / Edit / Delete Agents                                  │
│   ├─ Configure Discussion Mode & Rounds                          │
│   └─ Rename / Delete Sessions                                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Feasibility Analysis

### 3.1 Technical Feasibility

| Concern | Assessment |
|---|---|
| **Cross-platform UI** | Flutter compiles to native ARM/x64 and JS (web). A single codebase covers all 6 target platforms with minor conditional imports (`kIsWeb`). ✅ |
| **Backend** | Firebase provides managed Auth and Firestore. No server code to deploy or maintain. ✅ |
| **LLM Integration** | All 4 providers (Kimi, DeepSeek, Qwen, Doubao) implement the OpenAI-compatible `/chat/completions` SSE endpoint. A single `_callLLMStream()` method handles all providers with minimal branching. ✅ |
| **Real-Time Sync** | Firestore snapshot listeners (`Stream<QuerySnapshot>`) propagate changes to all connected clients within milliseconds. ✅ |
| **Streaming Responses** | The `http` package's `send()` method returns a `StreamedResponse` compatible with SSE parsing. Tested on web (XMLHttpRequest polyfill) and native. ✅ |
| **Context Window Management** | A sliding window approach (6 messages + summary) prevents token overflow without losing conversational coherence. ✅ |

### 3.2 Economic Feasibility

| Cost Item | Detail |
|---|---|
| Firebase Free Tier | 1 GB Firestore storage, 50k reads/day, 20k writes/day — sufficient for prototype and small team usage |
| LLM API Costs | Paid by the group leader (per-agent API keys); members incur no direct cost |
| Flutter / Dart SDK | Open source, free |
| Development Tools | Antigravity, Kiro, Claude Code — all AI-assisted; reduces person-hours significantly |

The project carries no infrastructure cost beyond LLM API usage, which scales linearly with actual discussion volume.

### 3.3 Operational Feasibility

- **Deployment**: Web build deploys to Firebase Hosting with `flutter build web`. Mobile builds follow standard App Store / Play Store pipelines.
- **Maintenance**: Schema changes require Firestore document migration; no SQL migrations. Firebase Console provides monitoring and security rule management.
- **Onboarding**: New members need only a 6-character invite code and the app URL — no environment setup required.

### 3.4 Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| API key leakage via Firestore rules misconfiguration | Medium | High | Implement strict Firestore security rules; consider server-side proxy for production |
| SSE parsing failure on certain network configurations | Low | Medium | Buffer-based SSE parser handles chunked and split events; errors logged and shown to user |
| Context window overflow for very long sessions | Medium | Medium | Sliding window + auto-summarisation caps token usage; window size tunable |
| Concurrent mode message ordering race condition | Medium | Low | Messages have `createdAt` timestamps; UI sorts by time |
| Firebase quota exhaustion | Low | High | Monitor Firebase Console; implement read throttling if needed |

---

## 4. System Design

### 4.1 Architecture Overview

The application follows a **client-heavy, serverless** architecture. All business logic — including LLM orchestration, context management, and discussion state — lives in the Flutter client. Firebase provides identity and a real-time document store.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Client                           │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │AuthService│  │ChatService│  │GroupSvc  │  │LocaleService │   │
│  │(Firebase │  │(Discussion│  │(Group    │  │ThemeService  │   │
│  │ Auth)    │  │ Engine)   │  │ CRUD)    │  │              │   │
│  └────┬─────┘  └────┬──────┘  └────┬─────┘  └──────────────┘   │
│       │             │              │                             │
│  ┌────▼─────────────▼──────────────▼────┐                       │
│  │          DatabaseService (singleton)  │                       │
│  │          Firestore CRUD + Streams     │                       │
│  └────────────────────┬─────────────────┘                       │
└───────────────────────┼─────────────────────────────────────────┘
                        │
          ┌─────────────▼────────────────┐
          │      Firebase Platform        │
          │  ┌──────────┐ ┌───────────┐  │
          │  │   Auth   │ │ Firestore │  │
          │  └──────────┘ └───────────┘  │
          └──────────────────────────────┘
                        │
          ┌─────────────▼────────────────┐
          │       LLM Providers (SSE)     │
          │  Kimi · DeepSeek · Qwen ·    │
          │  Doubao (OpenAI-compatible)  │
          └──────────────────────────────┘
```

### 4.2 State Management

Five `ChangeNotifier` providers are registered globally in `main.dart`:

| Provider | Responsibility |
|---|---|
| `AuthService` | Firebase Auth state (sign up, sign in, sign out, error messages) |
| `ChatService` | Discussion pipeline: LLM calls, streaming, history, session/message CRUD |
| `GroupService` | Group CRUD, invite codes, member management, discussion settings sync |
| `LocaleService` | i18n string getters for Chinese and English |
| `ThemeService` | Light/dark theme, persisted in `SharedPreferences` |

Provider selection rationale: `Provider` is lightweight and sufficient for this feature scope. It avoids the boilerplate of BLoC and the complexity of Riverpod while integrating cleanly with `ChangeNotifier`-based Firebase listener patterns.

### 4.3 Firestore Data Model

```
groups/{groupId}
  ├── name: String
  ├── leaderUid: String
  ├── inviteCode: String           // 6-char alphanumeric, unique
  ├── memberUids: String[]
  ├── memberNames: Map<uid, name>
  ├── discussionRounds: int
  ├── discussionMode: "sequential" | "concurrent"
  └── createdAt: ISO-8601 String

agents/{agentId}
  ├── id, name, systemInstruction
  ├── provider: "kimi"|"deepseek"|"qwen"|"doubao"
  ├── modelName: String
  ├── apiKey: String
  ├── doubaoEndpoint: String       // Volcengine endpoint ID
  └── groupId: String

sessions/{sessionId}
  ├── id, title, createdAt
  ├── summary: String?             // Auto-generated ≤200-word digest
  └── groupId: String

messages/{messageId}
  ├── id, text, createdAt
  ├── isUser: 0 | 1
  ├── agentId: String?
  ├── sessionId: String
  ├── isConclusion: 0 | 1
  ├── senderName: String?
  ├── replyTo: String?             // Parsed @attribution
  └── groupId: String
```

**Design decisions:**
- All collections are at the top level (flat structure) to simplify Firestore queries and avoid subcollection limitations.
- `isUser` and `isConclusion` are stored as integers (0/1) for SQLite backward compatibility (the project migrated from SQLite to Firestore mid-development).
- `agentId` is a foreign key resolved client-side; agent objects are not embedded to avoid duplication.

### 4.4 Discussion Pipeline Design

```
submitQuestion(text)
     │
     ▼
Add user ChatMessage → Firestore
     │
     ├── Parse @mentions (agents + users)
     │
     ▼
Build participatingAgents list
     │
     ├─────────────────────────────────────┐
     │ Sequential Mode                     │ Concurrent Mode
     │                                     │
     ▼                                     ▼
For each round (1..N):              Future.wait([
  For each agent:                     _processAgentTurn(agent1),
    _buildHistoryPayload()             _processAgentTurn(agent2),
    _processAgentTurn()                ...
    contextAccumulator += response   ])
  End round
Conclusion Phase (if N > 1):
  Each agent: final stance ≤100w
  Moderator: synthesis ≤200w
     │
     ▼
_triggerSummarization() [async, non-blocking]
```

### 4.5 Context Window Design

```
_buildHistoryPayload(agent, windowSize=6)
  ├── [system] Session summary (if exists)
  ├── [user]   Other agents' messages ("Agent X says: ...")
  ├── [assistant] This agent's own prior messages
  └── [user]   User messages ("[User: Name] says: ...")
```

This role-assignment strategy ensures each agent "remembers" its own prior statements as `assistant` turns, while seeing other agents' contributions as `user` turns — consistent with how LLMs are trained on dialogue.

### 4.6 UI Layout

```
ChatScreen
├── AppBar (session title, export, settings actions)
├── Drawer
│   ├── Section: Discussion History
│   │   └── Session list (tap to switch, long-press to rename/delete)
│   └── Section: Management
│       ├── Agent List → AgentEditDialog
│       ├── Group Settings → GroupSettingsDialog
│       └── Member list (collapsible)
├── Body
│   ├── Session Info Card (auto-collapses when messages exist)
│   ├── Message List (ChatMessageWidget with Markdown rendering)
│   ├── Agent Chip Bar (horizontal scroll, tap to select)
│   └── Input Row (TextField + Send button + Stop button)
└── Bottom: Discussion mode & rounds selector
```

---

## 5. Implementation

### 5.1 Project Structure

```
lib/
├── main.dart                    # Provider registration, Firebase init, routing
├── firebase_options.dart        # Auto-generated by flutterfire configure
├── models/
│   ├── agent_persona.dart       # AgentPersona data class + Firestore serialisation
│   ├── chat_message.dart        # ChatMessage with replyTo, isConclusion
│   ├── chat_session.dart        # ChatSession with summary field
│   ├── group.dart               # Group with member management helpers
│   └── user_persona.dart        # Lightweight user identity model
├── services/
│   ├── auth_service.dart        # Firebase Auth wrapper (~80 lines)
│   ├── chat_service.dart        # Discussion engine (~1,000 lines)
│   ├── database_service.dart    # Firestore CRUD + stream methods (~200 lines)
│   ├── group_service.dart       # Group/member management (~250 lines)
│   ├── locale_service.dart      # i18n string getters
│   ├── export_helper.dart       # Native file export
│   ├── export_helper_web.dart   # Web download export
│   └── export_helper_stub.dart  # Stub for conditional import
├── screens/
│   ├── auth_screen.dart         # Login / Register screen
│   ├── home_screen.dart         # Group selection / landing screen
│   ├── chat_screen.dart         # Main discussion screen (~1,268 lines)
│   ├── agent_list_screen.dart   # Agent management list
│   ├── agent_edit_dialog.dart   # Agent create/edit dialog
│   └── group_settings_dialog.dart
├── theme/
│   └── theme_service.dart       # Material 3 light/dark themes
└── widgets/
    └── chat_message_widget.dart # Markdown-rendered message bubble
```

### 5.2 LLM Streaming Integration

All four providers share an OpenAI-compatible SSE format. The `_callLLMStream()` method in `ChatService` handles all providers uniformly, with one branch for Doubao's endpoint ID convention:

```dart
Stream<String> _callLLMStream(AgentPersona agent, ...) async* {
  // Route to provider URL
  switch (agent.provider) {
    case 'kimi':    baseUrl = 'https://api.moonshot.cn/v1/chat/completions';
    case 'deepseek': baseUrl = 'https://api.deepseek.com/chat/completions';
    case 'qwen':    baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
    case 'doubao':  baseUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  }
  // Doubao uses endpoint ID as the model field
  final modelToUse = agent.provider == 'doubao'
      ? getEffectiveDoubaoEndpoint(agent: agent)
      : agent.modelName;

  // Send streaming request
  final request = http.Request('POST', Uri.parse(baseUrl));
  request.headers['Authorization'] = 'Bearer $apiKey';
  final response = await activeClient.send(request);

  // Parse SSE chunks
  await for (final chunk in response.stream.transform(utf8.decoder)) {
    buffer += chunk;
    while (buffer.contains('\n\n')) {
      // Extract data: {...} lines and yield delta content
      yield delta['content'];
    }
  }
}
```

### 5.3 Real-Time Synchronisation

`DatabaseService` exposes Firestore snapshot streams. `ChatService` subscribes to four streams simultaneously, with `StreamSubscription` handles for clean cancellation:

```dart
void _startStreams() {
  _agentSubscription = _dbService.streamAgents(_activeGroupId!).listen(...);
  _sessionSubscription = _dbService.streamSessions(_activeGroupId!).listen(...);
  _messageSubscription = _dbService.streamMessages(sessionId, agents).listen(...);
  _groupSettingsSubscription = _groupService.streamGroup(_activeGroupId!).listen(
    (group) {
      // Syncs discussionMode and discussionRounds to all members in real time
      _discussionMode = ...;
      _discussionRounds = group.discussionRounds;
      notifyListeners();
    },
  );
}
```

### 5.4 @Mention Parsing

```dart
final mentionRegex = RegExp(r'@(\S+)');
for (final match in mentionRegex.allMatches(questionText)) {
  final raw = match.group(1)!.toLowerCase();
  // 1. Try to match an agent name
  final foundAgents = allParticipatingAgents.where(
    (a) => a.name.toLowerCase().contains(raw),
  );
  mentionedAgents.addAll(foundAgents);
  // 2. If no agent matched, look for a real user → inject last 3 messages
  if (foundAgents.isEmpty) {
    final userMessages = _messages.where(
      (m) => m.isUser && (m.senderName?.toLowerCase().contains(raw) ?? false),
    ).toList();
    if (userMessages.isNotEmpty) {
      userMentionContext += '\n\n【用户 $userName 的最近发言】:\n'
          '${recent.map((m) => '- ${m.text}').join('\n')}';
    }
  }
}
```

### 5.5 Auto-Summarisation

After every discussion (except direct @mention replies), `_triggerSummarization()` runs asynchronously in the background. It builds a compact transcript of all session messages and calls the cheapest available agent to generate a ≤200-word summary, which is persisted to Firestore and prepended to future history payloads.

```dart
Future<void> _triggerSummarization() async {
  if (sessionMessages.length < 10) return;          // Not enough context yet
  // Build compact transcript
  final transcript = sessionMessages.map((m) => ...).join('\n\n');
  // Summarise using first agent with a valid API key
  final summaryAgent = AgentPersona(
    systemInstruction: '你是一个专业的会议摘要生成器，输出简洁、准确，不超过200字。', ...
  );
  // Merge with existing summary if present
  final prompt = existingSummary.isNotEmpty
      ? '...合并以下最新讨论与已有摘要...'
      : '...生成核心摘要...';
  // Save summary back to Firestore session document
  await _dbService.updateSession(updatedSession);
}
```

### 5.6 Invite Code Generation

Invite codes are 6 characters from a reduced alphabet (no `I`, `O`, `1`, `0` to avoid visual ambiguity). A collision check against Firestore ensures uniqueness:

```dart
static String _generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = Random.secure();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

Future<String> _uniqueInviteCode() async {
  while (true) {
    final code = _generateInviteCode();
    final snap = await _db.collection('groups')
        .where('inviteCode', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return code;   // No collision → use it
  }
}
```

### 5.7 Reply Attribution Parsing

After each agent completes streaming, the service inspects the first line of the response for an `@Name` prefix:

```dart
final replyPattern = RegExp(r'^@([^\s，,、。！？!?；:：]+)');
final inlineMatch = replyPattern.firstMatch(firstLine);
if (inlineMatch != null) {
  parsedReplyTo = inlineMatch.group(1);
  // Strip the @Name line from the visible message text
  displayText = lines.sublist(1).join('\n').trimLeft();
}
```

The cleaned `displayText` is shown in the UI, while `parsedReplyTo` is stored in Firestore and rendered as a reply thread indicator in `ChatMessageWidget`.

---

## 6. AI Interaction Process

This section documents every significant AI-assisted development step in chronological order, including the exact prompts, AI responses, my refinements, and the rationale behind each final decision.

> **AI Tools Used:**
> - **Gemini Deep Research** — initial architecture planning
> - **Antigravity** — rapid prototyping and first-iteration code generation
> - **Kiro** — continued development after Antigravity credits were exhausted
> - **Claude Code** — final documentation and codebase refinement

---

### 2026-02-20 — Project Inception & First Prototype

#### AI Interaction 1: Architecture Planning (Gemini Deep Research)

**Prompt:**
> "I want to build a multi-agent, multi-profession AI discussion app. Agents give insights from different domains. Dart platform, UI inspired by Gemini, dark/light theme toggle."

**AI Response:**
Gemini Deep Research returned a comprehensive analysis covering Dart + MCP architecture, multi-agent orchestration patterns, and UI design suggestions. It proposed a sophisticated agent-routing system with a central orchestrator.

**Refinement:**
The response was thorough but too abstract — it suggested an MCP-based routing layer that was overkill for a Flutter client app. I simplified the architecture to direct HTTP calls to OpenAI-compatible APIs.

**My Decision:**
I chose to use **direct SSE streaming** to each LLM provider rather than building a middleware routing layer. This kept the app stateless on the backend and put all intelligence in the Flutter client. I also decided to limit to 4 LLM providers (Kimi, DeepSeek, Qwen, Doubao) since they all share the OpenAI-compatible chat completions format.

---

#### AI Interaction 2: First Prototype Generation (Antigravity)

**Prompt:**
> "Build a Flutter multi-agent discussion app. Sequential discussion mode where agents take turns. Gemini-inspired UI design. Users provide their own API keys for Kimi, Qwen, Doubao, DeepSeek. Dark/light theme toggle."

**AI Response:**
Antigravity generated the initial project scaffold with: basic chat UI, theme service, and a single-file discussion engine. The UI used Material 3 with a dark/light toggle. The discussion logic called agents sequentially via HTTP.

**Refinement:**
1. The generated code had **import errors** and **missing dependency declarations** — I manually fixed `pubspec.yaml` to include all required packages.
2. The theme toggle was not persisted — I added `SharedPreferences` to save the user's preference.
3. The API call logic was hardcoded for a single provider — I refactored it into a provider-agnostic `_callLLMStream()` method.

**My Decision:**
I accepted Antigravity's UI structure but rewrote the service layer myself. The AI-generated service code was too rigid — it couldn't handle multiple providers or streaming responses. I designed `ChatService._callLLMStream()` as a unified method that all 4 providers use, differing only in endpoint URL.

---

### 2026-02-23 — API Integration & Multi-Provider Support

#### AI Interaction 3: API Connection Debugging (Antigravity)

**Prompt:**
> "The Doubao API returns 400 errors. The endpoint is https://ark.cn-beijing.volces.com/api/v3/chat/completions. Each agent has its own API key and a doubaoEndpoint field. Fix the streaming request."

**AI Response:**
The AI identified that the request was missing the `X-Domain-Token` header and the `model` field should map to the `doubaoEndpoint` value (Volcengine's endpoint ID), not a traditional model name.

**Refinement:**
I verified the fix by testing with a real Doubao endpoint ID. The SSE parsing also needed adjustment — Doubao's stream format used slightly different chunk boundaries than Kimi/DeepSeek.

**My Decision:**
I added a **provider-specific branch** in `_callLLMStream()` for Doubao: when `provider == 'doubao'`, the `model` field is set to the agent's `doubaoEndpoint` value instead of `modelName`. This was a necessary trade-off between API compatibility and code cleanliness.

---

#### AI Interaction 4: Discussion Mode Design (Antigravity)

**Prompt:**
> "Implement two discussion modes: sequential (agents take turns, multiple rounds) and concurrent (all agents respond at once). In sequential mode, later agents should see earlier agents' responses."

**AI Response:**
The AI generated a mode switch and concurrent implementation using `Future.wait()`. For sequential mode, it accumulated responses in a list and passed them to each subsequent agent.

**Refinement:**
The AI's sequential implementation passed the full accumulated text as a single user message, which quickly exceeded context windows. I redesigned it to use a **sliding window of 6 messages** plus an auto-generated session summary.

**My Decision:**
I implemented a **sliding window context system** (`_buildHistoryPayload()`) that keeps the last 6 messages + session summary. This prevents context overflow while still giving agents enough history to build coherent multi-round discussions. I also added a **conclusion phase** to sequential mode: after N rounds, each agent gives a 100-word final stance, then a neutral moderator synthesises everything.

**Lesson Learned:**
Asking a single task agent for full-stack development caused cascading errors. I switched to using **specialised agents for specific tasks** (bug-fixing, UI refinement) — this was significantly more effective.

---

### 2026-02-25 — Agent Customisation & Long-Term Memory

#### AI Interaction 5: Agent CRUD UI (Antigravity)

**Prompt:**
> "Create an agent management screen where users can add, edit, and delete agents. Each agent has: name, system instruction (personality prompt), provider dropdown (Kimi/DeepSeek/Qwen/Doubao), model name input, and API key input. Provide 5 preset agent templates."

**AI Response:**
The AI generated `AgentEditDialog` with form fields for all agent properties and 5 hardcoded preset templates (Analyst, Creative, Critic, Pragmatist, Humanist). It also created `AgentListScreen` with a list view and edit/delete actions.

**Refinement:**
1. The preset templates' prompts were too generic — I rewrote them to be more specific and domain-focused.
2. The form validation was missing — I added checks for empty name, empty API key, and invalid model name.
3. The API key input was a plain text field — I changed it to an obscured password field for security.

**My Decision:**
I kept the AI's dialog-based UI pattern (using `showDialog` instead of a full screen) because it is more efficient for quick edits. I also decided that **only the group leader** can manage agents — regular members can only select which agents participate in discussions.

---

#### AI Interaction 6: @Mention System Design (Antigravity)

**Prompt:**
> "Implement an @mention system: @AgentName triggers only that agent to respond, @UserName injects that user's last 3 messages as context. Agent replies should show @attribution when addressing someone."

**AI Response:**
The AI implemented regex-based parsing for `@mentions` in the input text. It added logic to filter agents based on mentions and inject user message history.

**Refinement:**
The initial implementation had a **bug where @mentions in agent responses triggered recursive agent calls** — I added a check to only parse mentions from user messages (`isUser == true`). I also improved the reply attribution: instead of just checking for `@` in the response text, I look at the actual reply target from the discussion context.

**My Decision:**
I kept the dual @mention system but added a **visual chip selector** (in the 2026-04-05 UX overhaul) as an alternative to typing `@AgentName`. This gives users two interaction methods: keyboard-driven and tap-driven.

---

### 2026-02-27 — Multi-User Platform & Firebase Integration

#### AI Interaction 7: Multi-User Architecture (Antigravity → Kiro)

**Prompt:**
> "Refactor the app to support multi-user. Add Firebase Auth (email/password), group system with invite codes, real-time sync via Firestore. Group leader manages agents and settings. Members join via invite code."

**AI Response:**
Antigravity generated the Firebase integration code including: `AuthService`, `GroupService`, `DatabaseService`, and the Firestore data model. It also created `AuthScreen` with login/signup forms.

**Refinement:**
1. **Switched from Antigravity to Kiro** midway because Antigravity credits were exhausted. Kiro continued the Firebase integration work.
2. The AI's `DatabaseService` initially used a mix of local and remote calls — I separated them clearly: Firestore for all shared data, with real-time snapshot listeners for live sync.
3. The invite code generation was a simple random string — I made it exactly 6 characters (uppercase alphanumeric, visually unambiguous) for easy verbal sharing.
4. The real-time sync had **stale data issues** — I added proper `StreamSubscription` cancellation to avoid memory leaks from orphaned Firestore listeners.

**My Decision:**
I chose a **group-first architecture** where all data (agents, sessions, messages) is scoped to a group. This simplified the Firestore security rules and the data flow. The key design decision was: **API keys are stored per-agent in Firestore** — this means the group leader provides the keys, and members do not need their own. This lowers the barrier to entry for group members.

---

### 2026-04-05 — UX Overhaul, UI Polish & Bug Fixes

#### AI Interaction 8: UX Evaluation & Chip Selector (Kiro)

**Prompt:**
> "Based on HCI evaluation, add an agent selector above the input area as horizontal scrollable chips. Users tap to select which agents participate. Show a count hint like '3 agents will respond'. Selected agents have coloured borders, unselected are dimmed."

**AI Response:**
Kiro generated a `Wrap` widget with `FilterChip`-style components for each agent. It added state tracking for selected agents and a hint text widget.

**Refinement:**
1. Changed from `Wrap` to `SingleChildScrollView` + `Row` for consistent horizontal scrolling behaviour.
2. The chip design was too generic — I customised it with agent-specific colours and avatar initials.
3. Added proper state sync: when all agents are selected, the hint text hides; when entering a new session, all agents auto-select by default.

**My Decision:**
The chip selector complements the existing @mention system rather than replacing it. Power users can still type `@AgentName` for precision, while casual users can tap chips. Both methods set the same underlying state (`_participatingAgentIds`).

---

#### AI Interaction 9: Bug Fixes (Kiro)

**Prompt:**
> "Fix these bugs: 1) Theme preference lost on restart. 2) User messages show as plain text, not Markdown. 3) Input field loses focus after sending. 4) Generic progress indicator during discussion. 5) Default agent participation requires leader pre-selection."

**AI Response:**
Kiro addressed each bug individually:
1. Added `SharedPreferences` persistence in `ThemeService.loadTheme()`.
2. Wrapped user message text in `MarkdownBody` widget.
3. Added `_focusNode.requestFocus()` after message submission.
4. Redesigned progress area with circular indicator + stop button.
5. Set all agents as selected by default in `ChatService.enterGroupMode()`.

**Refinement:**
For bug #2, the AI only wrapped the text in `MarkdownBody` — I also needed to ensure code blocks render with proper background styling (`surfaceContainerHighest`). For bug #4, I added the **agent typing indicator** (showing "Agent X is thinking..." with avatar) on top of the AI's progress redesign.

**My Decision:**
I accepted all 5 fixes and added 2 more the AI did not catch: removed a dead "add" button in the input area, and simplified the agent list screen to remove confusing participation checkboxes (replaced by the chip bar).

---

#### AI Interaction 10: Theme System Overhaul (Kiro)

**Prompt:**
> "Polish the Material 3 theme. Add cardTheme, dialogTheme, snackBarTheme for consistency. Add secondaryContainer and tertiary colors. Improve color contrast and spacing throughout the app."

**AI Response:**
Kiro updated `ThemeService` with comprehensive theme definitions for both light and dark modes. It added `cardTheme`, `dialogTheme`, `floatingActionButtonTheme`, `snackBarTheme`, and `dividerTheme`.

**Refinement:**
The AI's colour choices were too saturated in dark mode — I manually adjusted the `surfaceContainer` tones to be more neutral. I also added the `tertiary` colour seed for accent elements like the agent chips.

**My Decision:**
I kept the AI's theme structure but fine-tuned the specific colour values. The key insight: Material 3's dynamic colour system needs careful tuning — AI-generated colour palettes often lack the subtlety needed for dark mode.

---

#### AI Interaction 11: Drawer Reorganisation & Session Info Card (Kiro)

**Prompt:**
> "Reorganise the drawer into labelled sections: 'Discussion History' and 'Management'. Make group members collapsible. Add a collapsible session info card that auto-collapses when messages exist."

**AI Response:**
Kiro restructured the drawer with `ExpansionTile` widgets and section headers. It implemented the session info card as a tappable `Card` widget with `AnimatedSize` for collapse animation.

**Refinement:**
1. The `ExpansionTile` animation was janky — I replaced it with a custom `AnimatedCrossFade` for smoother transitions.
2. The session info card initially showed all details at once — I added the auto-collapse logic based on message count.

**My Decision:**
I kept the two-section drawer structure and the collapsible session card. The auto-collapse behaviour was my own design decision based on the principle of **progressive disclosure** — show summary info by default, details on demand.

---

### 2026-04-05 — Documentation & Code Quality

#### AI Interaction 12: README & .gitignore Update (Claude Code)

**Prompt:**
> "Help me update the README.md file and tidy up the .gitignore."

**AI Response:**
Claude Code analysed the codebase, compared it against the existing README, and identified discrepancies: missing `user_persona.dart` in the directory tree, incomplete `export_helper` file listing, missing dependencies in the table, and inaccurate data storage description. For `.gitignore`, it identified a redundant `*.dart_tool/` pattern, missing macOS desktop entries (`macos/Pods/`, `macos/.symlinks/`), missing Android keystore rules, and missing coverage/env/log patterns.

**Refinement:**
I reviewed each suggested change and confirmed all were valid. The updates were minimal and accurate — no over-engineering.

**My Decision:**
Accepted all changes. The README and `.gitignore` are now consistent with the actual codebase state.

---

### AI Collaboration Methodology — Retrospective

After 12 AI interactions across 4 different tools, several patterns emerged:

| Pattern | Observation |
|---|---|
| **Narrow prompts outperform broad ones** | "Fix this specific Doubao 400 error" yielded immediately usable code; "build the full backend" produced code that needed significant rework |
| **AI excels at boilerplate** | Form validation, CRUD dialogs, theme definitions — all generated correctly on the first attempt |
| **AI struggles with cross-cutting concerns** | Memory management (stream cancellation), context window overflow, and stateful edge cases consistently required manual correction |
| **Switching tools mid-feature is risky** | The Antigravity → Kiro switch (Interaction 7) required re-establishing context and caused temporary inconsistencies |
| **AI as pair reviewer** | Claude Code's documentation review (Interaction 12) caught real discrepancies the human author had missed |

---

## 7. Testing & Known Issues

### 7.1 Testing Approach

Automated testing was not implemented in this prototype phase. Manual testing was performed on:
- **Web** (Chrome, via `flutter run -d chrome`)
- **macOS desktop** (via Mac Simulator)
- **iOS Simulator** (via Xcode Simulator)

All 4 LLM providers were tested with real API keys across both discussion modes.

### 7.2 Known Issues & Future Work

| Priority | Issue | Notes |
|---|---|---|
| High | API keys stored in Firestore plaintext — not encrypted at rest | Should use a server-side proxy for production |
| High | No Firestore security rules defined (uses test mode) | Must add rules before any public release |
| Medium | `chat_screen.dart` (1,268 lines) and `chat_service.dart` (1,007 lines) exceed recommended file size | Needs refactoring into smaller widgets/services |
| Medium | Message pagination not implemented — all messages load at once | Could cause performance issues in long sessions |
| Medium | Concurrent mode message ordering depends on arrival time | Timestamps are stored; UI sorts by `createdAt` |
| Low | No `intl` package — i18n uses manual getter-based approach | Acceptable for 2-language support; `intl` needed for more |
| Low | No message search functionality | — |
| Low | Firestore composite indexes not explicitly defined | May cause query errors as data grows |
| Low | No unit or integration tests | — |

---

## 8. Conclusion

This project demonstrates that a sophisticated, multi-user AI collaboration platform can be built rapidly using Flutter + Firebase + AI development tools. The most significant architectural decisions — direct SSE streaming, group-scoped Firestore data, sliding window context, and the sequential/concurrent dual-mode engine — were all made or refined based on real limitations encountered during development.

The AI interaction process revealed a clear pattern: AI tools are most valuable as **accelerators for well-understood tasks** (boilerplate, UI scaffolding, single-concern bug fixes) and least reliable for **systemic design** (cross-cutting state management, multi-step data flows). The most effective workflow was to use AI for initial generation, then apply human judgment to verify correctness, fix edge cases, and make architectural trade-offs.

The platform is functional and demonstrates the core thesis: multiple AI agents with distinct personas produce richer, more multi-faceted discussion than any single model — a useful primitive for research brainstorming, creative ideation, and structured debate.

---

*Last updated: 2026-04-05 | Claude Code assisted revision*