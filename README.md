# 多智能体讨论平台

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-^3.10-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Cloud_Firestore-FFCA28?logo=firebase)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-lightgrey)

一个基于 Flutter + Firebase 构建的多智能体讨论平台

创建群组，配置多个具有不同人格和专业背景的 AI Agent，让它们围绕同一个话题展开多轮辩论，最终由主持人 Agent 综合各方观点给出结论。

[快速开始](#快速开始) • [功能特性](#功能特性) • [技术架构](#技术架构) • [部署指南](#部署指南)

</div>

---

## 功能特性

### 🎯 群组协作

- **邀请码系统**：每个群组拥有唯一的 6 位邀请码，一键分享即可邀请他人加入
- **权限管理**：群主拥有完整管理权限，成员可参与讨论和配置 Agent
- **实时同步**：基于 Firestore 实时流，群组成员、会话、消息状态毫秒级同步

### 🤖 智能 Agent 配置

- **多提供商支持**：Kimi（Moonshot）、DeepSeek、豆包（火山引擎）、通义千问（阿里云）
- **独立配置**：每个 Agent 独立配置人格、模型、API Key，互不干扰
- **预设模板**：提供 5 种推荐人格模板（理性分析师、创意先锋、批判者、实用主义者、人文关怀者）
- **灵活选择**：每位成员可独立勾选参与讨论的 Agent

### 💬 多模式讨论

- **顺序模式**：Agent 依次发言，支持 1-5 轮可调辩论，每轮基于上下文生成针对性反驳或补充
- **并发模式**：所有 Agent 同时独立回答，快速收集多元视角
- **结论阶段**：顺序模式专属，每个 Agent 给出最终立场，由中立主持人综合生成全面结论

### 🎨 智能交互

- **@ 提及系统**：
  - `@AgentName` 定向触发特定 Agent 回复
  - `@用户名` 自动注入该用户最近 3 条发言作为上下文
- **回复归因**：Agent 回复若主要针对某人，自动标注并展示引用关系
- **流式输出**：所有 AI 回复实时流式渲染，逐字显示
- **随时停止**：讨论进行中可随时中断

### 📁 会话管理

- **多会话支持**：群主可创建多个讨论会话，独立保存消息记录
- **智能标题**：会话标题自动取第一条消息前 20 字
- **自动摘要**：10 条消息后自动生成摘要，用于长对话上下文压缩
- **导出功能**：支持导出对话为 Markdown 文件

### 🌐 多平台支持

- **Web、iOS、Android** 三端一致体验
- **深色/浅色主题**自由切换
- **中英文界面**无缝切换

---

## 截图

<!-- 添加应用截图 -->

---

## 快速开始

### 前置要求

- Flutter SDK `^3.10`
- Firebase 项目（已启用 Authentication 和 Firestore）
- 至少一个支持的 LLM 提供商 API Key

### 安装依赖

```bash
git clone https://github.com/yourusername/multi_agent_chat.git
cd multi_agent_chat
flutter pub get
```

### Firebase 配置

1. 在 [Firebase Console](https://console.firebase.google.com) 创建项目
2. 启用 **Email/Password** 登录方式
3. 创建 **Firestore Database**
4. 运行以下命令生成 Firebase 配置文件：

```bash
flutterfire configure
```

### 配置 Firestore 安全规则

在 Firebase Console 的 Firestore 规则页面添加以下规则：

```javascript
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

**规则说明**：
- `groups` 集合：成员可读写，仅群主可删除
- `agents`、`sessions`、`messages`、`users` 集合：所有认证用户可读写
- 所有集合均为顶级集合，非子集合

### 运行应用

```bash
# Web
flutter run -d chrome

# iOS
flutter run -d ios

# Android
flutter run -d android
```

---

## 技术架构

### 状态管理

使用 [Provider](https://pub.dev/packages/provider) 模式，全局注册 5 个 `ChangeNotifier`：

| Provider | 职责 |
|---|---|
| `AuthService` | Firebase Auth 状态监听与用户认证 |
| `ChatService` | 讨论引擎核心：消息、会话、Agent 管理、LLM 调用编排 |
| `GroupService` | 群组 CRUD、邀请码生成、成员管理、设置同步 |
| `LocaleService` | 国际化字符串管理（中英文切换） |
| `ThemeService` | 深色/浅色主题切换 |

### 数据存储

- **Firebase Firestore**：云端数据存储，支持实时同步
- **数据模型**：
  - `groups`：群组元数据、成员列表、设置
  - `agents`：Agent 配置（人格、提供商、API Key）
  - `sessions`：讨论会话、摘要
  - `messages`：消息记录、回复关系
  - `users`：用户配置

### LLM 集成

支持 OpenAI 兼容格式的 SSE 流式请求：

| 提供商 | 端点 |
|---|---|
| Kimi (Moonshot) | `api.moonshot.cn/v1` |
| DeepSeek | `api.deepseek.com` |
| 豆包 (火山引擎) | `ark.cn-beijing.volces.com/api/v3` |
| 通义千问 (阿里云) | `dashscope.aliyuncs.com/compatible-mode/v1` |

每个 Agent 携带独立 API Key，调用时直接使用，无共享密钥风险。

### 上下文构建

采用滑动窗口策略：
1. 注入会话摘要（如有）作为 system 消息
2. 注入最近 6 条消息作为对话历史
3. 注入当前轮次完整讨论积累作为 user prompt

---

## 技术栈

| 类别 | 技术 |
|---|---|
| **前端框架** | Flutter 3.10+ |
| **状态管理** | Provider |
| **后端服务** | Firebase (Auth + Firestore) |
| **LLM 提供商** | Kimi / DeepSeek / 豆包 / 通义千问 |
| **Markdown 渲染** | flutter_markdown |
| **本地存储** | shared_preferences, sqflite |
| **网络请求** | http (SSE 流式) |
| **国际化** | 自建 LocaleService |
| **动画** | flutter_animate |

---

## 部署指南

### Web 部署

```bash
flutter build web
# 将 build/web 目录部署到 Firebase Hosting 或其他静态托管服务
```

### iOS 部署

```bash
flutter build ios --release
# 使用 Xcode 进行进一步配置和上传到 App Store
```

### Android 部署

```bash
flutter build appbundle --release
# 上传 .aab 文件到 Google Play Console
```

---

## 贡献

欢迎贡献代码、报告问题或提出新功能建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: 添加某个功能'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

---

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 联系方式

- 项目主页：[GitHub Repository](https://github.com/yourusername/multi_agent_chat)
- 问题反馈：[Issues](https://github.com/yourusername/multi_agent_chat/issues)

---

<div align="center">

**用 Flutter 构建 ❤️**

</div>
