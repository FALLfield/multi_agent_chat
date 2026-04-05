# Multi-Agent Chat — Development Log

> A multi-agent discussion platform built with Flutter + Firebase. Users configure AI agents with different personas, and agents debate topics collaboratively — simulating a real team discussion environment.

---

## Tech Stack

| Layer     | Technology                                     |
|-----------|-----------------------------------------------|
| Language  | Dart (Flutter SDK ^3.10)                      |
| Framework | Flutter (Material 3)                          |
| Backend   | Firebase (Auth + Firestore)                   |
| State     | Provider                                      |
| LLM APIs  | Kimi (Moonshot), DeepSeek, Qwen, Doubao      |
| AI Tools  | Gemini 3 Pro (planning), Antigravity + Kiro (development) |
| IDE       | Antigravity                                   |
| Simulator | Mac Simulator                                 |
| VCS       | Git                                           |

---

## Development Timeline

### 2026-02-20 — Project Inception & First Prototype

**Goal**: Build a multi-agent AI discussion app where agents from different domains share perspectives on a single question.

1. Used **Gemini Deep Research** to generate an initial architecture plan based on the prompt:
   > "I want to build a multi-agent, multi-profession AI discussion app. Agents give insights from different domains. Dart platform, UI inspired by Gemini, dark/light theme toggle."
   Deep Research returned a comprehensive analysis (Dart + MCP), but wasn't directly actionable — shifted to building directly in Antigravity.

2. Refined the prompt to specify **sequential discussion** (not concurrent), with **Gemini-inspired design**, and **user-provided API keys** for Kimi, Qwen, Doubao, and DeepSeek.

3. Antigravity generated the first prototype. Fixed initial code issues. End of Day 1 deliverable: working prototype with basic UI.

---

### 2026-02-23 — API Integration & Multi-Provider Support

**Goal**: Connect LLM providers and implement discussion modes.

1. Successfully connected to Kimi, DeepSeek, and Doubao APIs. **Qwen was dropped** due to network issues (Singapore region incompatibility with the API endpoint).

2. Fixed Doubao-specific bugs (endpoint configuration, SSE parsing). Platform now supports both **sequential discussion** (agents speak one after another) and **concurrent response** (all agents respond simultaneously).

3. Planned four interaction modes:
   - Single user ↔ Single AI
   - Single user ↔ Multiple AIs *(implemented)*
   - Multiple users ↔ Single AI
   - Multiple users ↔ Multiple AIs

4. Also planned **multi-round discussion** (configurable 1-5 rounds in sequential mode, with final conclusions from each agent and a neutral moderator synthesis).

5. Note: Asking a single task agent for full-stack development caused cascading errors. Switched to using specialized agents for bug-fixing — more effective.

---

### 2026-02-25 — Agent Customization & Long-Term Memory

**Goal**: Allow users to create custom agents and give agents conversation memory.

1. Implemented **agent creation**: users can define agent name, system instruction, provider, and model. Added virtual users for testing multi-user detection.

2. Discovered a critical UX gap: agents only reacted to the current question without memory of prior discussion.

3. Implemented **long-term memory** via a sliding-window context system:
   - Recent messages are injected as conversation history
   - Session summaries auto-generate after 10 messages (background, non-blocking)
   - Agents can reference and build upon previous exchanges

4. Implemented **@mention system**:
   - `@AgentName` — targets a specific agent for a direct reply
   - `@UserName` — injects that user's last 3 messages as context
   - Reply attribution: agent responses show `@Name` when directly addressing someone

---

### 2026-02-27 — Multi-User Platform & Firebase Integration

**Goal**: Transform from single-user prototype to a real multi-user platform.

1. Designed and implemented the full multi-user architecture:
   - Firebase Authentication (email/password signup & login)
   - Group system with **6-character invite codes**
   - Group leader (creator) manages: agents, API keys, discussion settings
   - Members join via invite code, no API keys required
   - All data stored in Firestore with real-time sync

2. Firestore data model:
   ```
   groups/{groupId}        → group metadata, members, settings
     agents/{agentId}      → per-agent config
   sessions/{sessionId}    → discussion sessions, auto-summary
   messages/{messageId}    → messages with agent attribution
   ```

3. Switched from Antigravity to **Kiro** (Antigravity credits exhausted) to complete the remaining Firebase integration work. All features fully implemented and deployed.

---

### 2026-04-05 — UX Overhaul, UI Polish & Bug Fixes

**Goal**: Improve usability, fix bugs, and polish the visual design.

#### UX: Agent Selector Chips

- Added a **horizontal scrollable row of agent chips** above the text input area
- Users can **visually tap to select** which agents participate in the next response
- Selected agents are highlighted with colored borders and labels
- Unselected agents are dimmed — only selected agents respond
- `@mention` still works as a keyboard shortcut within the input
- This simulates a natural team discussion: user picks who to address, those agents respond and remember context

#### UX: HCI Improvements

Based on HCI evaluation, implemented 6 user experience enhancements:

1. **"Agent X is thinking..." typing indicator** — During discussion, the progress area now shows the current agent's avatar and name instead of generic "Discussing..." text. `ChatService.currentSpeakingAgent` property tracks which agent is being processed.

2. **Agent count confirmation** — When a subset of agents is selected, a small hint text ("3 agents will respond") appears between the chips and input field. Hidden when all agents are selected.

3. **Drawer reorganization** — Split drawer into two labeled sections: "Discussion History" (sessions + new discussion) and "Management" (agent roster, group members, clear history, leave group). Group members now default to collapsed. All items use compact density for better information density.

4. **Collapsible session info card** — The session info card (mode, rounds, agents) is now tappable to expand/collapse. Auto-collapses when messages exist, saving vertical space. Expanded view shows individual participating agent names.

5. **Smart placeholder text** — Input placeholder changed from generic "Ask a question..." to "Ask a question. @mention or select agents above." — clarifies both interaction methods.

6. **Mode toggle moved to Group Settings** — The Sequential/Concurrent mode toggle moved from the AppBar (where it was easily misclicked) to the Group Settings dialog, alongside the rounds slider. Uses a `SegmentedButton` for clear visual selection.

#### Bug Fixes

| Issue | Fix |
|-------|-----|
| Theme preference lost on app restart | Added `SharedPreferences` persistence in `ThemeService` |
| Dead "add" button in input area (did nothing) | Removed the non-functional button |
| User messages rendered as plain text | Wrapped in `MarkdownBody` for consistent rendering |
| Input field lost focus after sending message | Added `_focusNode.requestFocus()` after submit |
| Generic progress indicator during discussion | Redesigned with circular progress + stop button |
| Default agent participation required leader pre-selection | All agents auto-selected by default when group is entered |
| Agent list showed participation checkboxes (confusing) | Simplified to add/edit/delete management only |

#### UI Improvements

- **Theme**: Added `cardTheme`, `dialogTheme`, `floatingActionButtonTheme`, `snackBarTheme`, `dividerTheme` for consistent Material 3 styling. Added `secondaryContainer` and `tertiary` colors.
- **Chat screen**: Session info card redesigned with pill-style badges. Empty state with styled icon container. Progress area with compact design. Agent typing indicator with avatar.
- **Home screen**: User avatar circle in app bar. Improved empty state with icon container and better spacing.
- **Message widget**: User messages now support Markdown. Added timestamps to agent messages. Improved code block styling with `surfaceContainerHighest`.
- **Group settings**: Added discussion mode `SegmentedButton` toggle alongside rounds slider. Improved visual hierarchy with labeled sections.
- **Drawer**: Organized into labeled sections. Compact density. Collapsible group members list.
- **Overall**: Better spacing, color consistency, and visual hierarchy throughout.

---

## Known Issues & Future Work

- [ ] Message pagination for long sessions (currently loads all at once)
- [ ] No message search functionality
- [ ] Firestore composite indexes not explicitly defined
- [ ] Concurrent mode message order depends on response arrival time
- [ ] No `intl` package for proper i18n (currently using manual getter-based approach)
