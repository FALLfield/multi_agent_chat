# Multi-Agent Chat

一个基于 Flutter + Firebase 构建的多智能体讨论平台。用户可以创建群组，配置多个具有不同人格和专业背景的 AI Agent，让它们围绕同一个话题展开多轮辩论，最终由主持人 Agent 综合各方观点给出结论。

---

## 产品功能

### 群组系统

- 注册/登录后可创建或加入群组
- 每个群组有唯一的 6 位邀请码，分享给他人即可加入
- 群主（Leader）拥有管理权限，普通成员只能参与讨论
- 侧边栏实时显示群组成员列表（基于 Firestore 实时流）
- 群主可解散群组，成员可退出群组

### Agent 配置

- 群主可自由创建、编辑、删除 AI Agent
- 每个 Agent 独立配置：
  - 名称与人格（System Instruction）
  - AI 提供商（Kimi / DeepSeek / Doubao / Qwen）
  - 模型名称（需与提供商 API 的 model ID 完全一致）
  - 独立 API Key（每个 Agent 使用自己的 Key，互不干扰）
  - Doubao 专属 Endpoint ID（火山引擎接入点）
- 提供 5 个推荐 Agent 模板，一键填充名称与 Prompt：
  - 🔍 理性分析师
  - 💡 创意先锋
  - ⚔️ 批判者
  - 🔧 实用主义者
  - 🤝 人文关怀者
- 每位成员可独立勾选参与本次讨论的 Agent

### 讨论模式

**顺序模式（Sequential）**

Agent 依次发言，支持多轮辩论（1–5 轮可调）。每一轮后续发言会基于前面所有发言内容，自动生成针对性的反驳或补充。

**并发模式（Concurrent）**

所有 Agent 同时独立回答，适合快速收集多元视角。

**结论阶段（多轮顺序模式专属）**

1. 每个 Agent 给出自己的最终立场（100 字以内）
2. 中立主持人 Agent 综合所有立场，输出一份全面的最终结论（200 字以内）

### 智能交互

- **@提及 Agent**：在消息中 `@AgentName` 可定向触发该 Agent 回复，其他 Agent 不参与
- **@提及用户**：`@用户名` 会自动注入该用户最近 3 条发言作为上下文，让 Agent 针对性讨论
- **回复归因**：Agent 回复若主要针对某人，会在首行标注 `@对方名字`，UI 中以引用气泡展示
- **流式输出**：所有 Agent 回复均为实时流式渲染，逐字显示
- **停止生成**：讨论进行中可随时点击停止按钮中断

### 会话管理

- 群主可创建多个讨论会话（Session），每个会话独立保存消息记录
- 会话标题自动取第一条消息的前 20 字
- 支持重命名会话
- 群主可删除单个会话
- 支持清空全部历史记录
- 会话自动生成摘要（10 条消息后触发，后台静默执行），用于长对话的上下文压缩

### 实时同步

- 所有消息、会话、Agent 配置均存储于 Firestore，群组内所有成员实时同步
- 讨论轮次、讨论模式等设置由群主修改后，所有成员端立即生效（无需刷新）

### 其他功能

- 导出对话为 Markdown 文件（Web 端直接下载，原生端保存至本地）
- 深色 / 浅色主题切换
- 中文 / 英文界面切换（持久化保存）
- 支持 Web、iOS、Android 多平台

---

## 技术架构

```
multi_agent_chat/
├── lib/
│   ├── main.dart                  # 应用入口，Provider 注册，Firebase 初始化
│   ├── models/
│   │   ├── agent_persona.dart     # Agent 数据模型
│   │   ├── chat_message.dart      # 消息数据模型
│   │   ├── chat_session.dart      # 会话数据模型
│   │   ├── group.dart             # 群组数据模型
│   │   └── user_persona.dart      # 用户数据模型
│   ├── services/
│   │   ├── auth_service.dart      # Firebase Auth 封装
│   │   ├── chat_service.dart      # 核心讨论引擎（状态管理 + LLM 调用）
│   │   ├── database_service.dart  # Firestore CRUD 操作封装
│   │   ├── group_service.dart     # 群组管理（创建/加入/退出/设置同步）
│   │   ├── locale_service.dart    # 国际化字符串管理
│   │   ├── export_helper.dart     # 对话导出入口（条件导入）
│   │   ├── export_helper_web.dart # Web 端导出实现
│   │   └── export_helper_stub.dart # 非 Web 端导出桩实现
│   ├── screens/
│   │   ├── auth_screen.dart       # 登录 / 注册页
│   │   ├── home_screen.dart       # 群组列表页
│   │   ├── chat_screen.dart       # 主聊天页（含侧边栏 Drawer）
│   │   ├── agent_list_screen.dart # Agent 管理列表页
│   │   ├── agent_edit_dialog.dart # Agent 创建 / 编辑弹窗
│   │   └── group_settings_dialog.dart # 群组设置弹窗
│   ├── widgets/
│   │   └── chat_message_widget.dart   # 消息气泡组件（含 Markdown 渲染）
│   └── theme/
│       └── theme_service.dart     # 主题管理（深色 / 浅色）
├── android/
├── ios/
└── pubspec.yaml
```

### 状态管理

使用 [Provider](https://pub.dev/packages/provider) 模式，全局注册 5 个 `ChangeNotifier`：

| Provider | 职责 |
|---|---|
| `AuthService` | Firebase Auth 状态监听 |
| `ChatService` | 讨论引擎核心：消息、会话、Agent、LLM 调用 |
| `GroupService` | 群组 CRUD、邀请码、成员管理 |
| `LocaleService` | 语言切换，所有 UI 字符串集中管理 |
| `ThemeService` | 深色/浅色主题切换 |

### 数据存储

- **Firebase Firestore**：云端数据存储，支持群组成员实时同步
- **SQLite**（`sqflite`）：本地缓存（通过 `DatabaseService` 管理）

```
groups/{groupId}
  ├── name, leaderUid, inviteCode
  ├── memberUids[], memberNames{}
  ├── discussionRounds, discussionMode
  └── agents/{agentId}
        ├── name, systemInstruction
        ├── provider, modelName
        ├── apiKey, doubaoEndpoint
        └── groupId

sessions/{sessionId}
  ├── title, groupId, createdAt
  ├── summary (自动生成的摘要)
  └── messages/{messageId}
        ├── text, isUser, createdAt
        ├── agent{}, senderName
        ├── replyTo, isConclusion
        └── sessionId, groupId
```

### LLM 调用

`ChatService._callLLMStream()` 统一封装了 OpenAI 兼容格式的 SSE 流式请求，支持以下提供商：

| 提供商 | API 端点 |
|---|---|
| Kimi (Moonshot) | `https://api.moonshot.cn/v1/chat/completions` |
| DeepSeek | `https://api.deepseek.com/chat/completions` |
| Doubao (火山引擎) | `https://ark.cn-beijing.volces.com/api/v3/chat/completions` |
| Qwen (阿里云百炼) | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` |

每个 Agent 携带自己的 `apiKey`，调用时直接使用，无共享密钥。

### 讨论上下文构建

每次 Agent 发言前，`_buildHistoryPayload()` 会构建一个滑动窗口上下文：

1. 注入当前会话的摘要（如有）作为 `system` 消息
2. 注入最近 6 条消息作为 `user` / `assistant` 对话历史
3. 注入当前轮次的完整讨论积累文本作为 `user` prompt

---

## 快速开始

### 前置要求

- Flutter SDK `^3.10`
- Firebase 项目（已启用 Authentication 和 Firestore）
- 至少一个支持的 LLM 提供商的 API Key

### 安装

```bash
git clone <repo-url>
cd multi_agent_chat
flutter pub get
```

### Firebase 配置

1. 在 [Firebase Console](https://console.firebase.google.com) 创建项目
2. 启用 **Email/Password** 登录方式
3. 创建 **Firestore Database**（生产模式或测试模式均可）
4. 运行 `flutterfire configure` 生成 `lib/firebase_options.dart`

### Firestore 安全规则（建议）

> 所有集合均为顶级集合（`groups`、`agents`、`sessions`、`messages`、`users`），非子集合。

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /groups/{groupId} {
      allow read: if request.auth != null
                   && request.auth.uid in resource.data.memberUids;
      allow create: if request.auth != null;
      allow update: if request.auth != null
                    && request.auth.uid in resource.data.memberUids;
      allow delete: if request.auth != null
                    && request.auth.uid == resource.data.leaderUid;
    }

    match /agents/{agentId} {
      allow read, write: if request.auth != null;
    }

    match /sessions/{sessionId} {
      allow read, write: if request.auth != null;
    }

    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }

    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 运行

```bash
# Web
flutter run -d chrome

# iOS
flutter run -d ios

# Android
flutter run -d android
```

---

## 主要依赖

| 包 | 用途 |
|---|---|
| `provider` | 状态管理 |
| `firebase_core` / `firebase_auth` / `cloud_firestore` | Firebase 集成 |
| `http` | LLM API 流式请求 |
| `flutter_markdown` | 消息内容 Markdown 渲染 |
| `shared_preferences` | 本地持久化（语言设置、讨论轮次等） |
| `sqflite` | SQLite 本地数据库 |
| `path_provider` / `path` | 文件路径与本地存储 |
| `web` | Web 平台导出支持 |
| `flutter_animate` | UI 动画 |
