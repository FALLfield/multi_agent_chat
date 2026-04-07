# Multi-Agent Chat — PPT 制作指导

> 基于项目 Development.md 和 README.md 整理，供答辩/演示 PPT 参考。

---

## Slide 1 — Project Title & Brief Overview

### 建议标题

**Multi-Agent Chat: A Pluralistic AI Discussion Platform**
副标题：让多个 AI Agent 以不同人格围绕同一话题辩论

### 一句话介绍

一个基于 Flutter + Firebase 的跨平台应用，用户配置多个拥有不同人格和专业背景的 AI Agent，让它们就同一问题展开多轮辩论，所有结果实时同步给群组成员。

### 关键词标签

- Flutter + Firebase（技术栈）
- Multi-Agent Discussion（核心概念）
- Real-time Collaboration（协作特性）
- Cross-platform（Web / iOS / Android）

### 视觉建议

放一张 App 运行截图或一个简洁的架构缩略图，让听众一眼知道这是什么。

---

## Slide 2 — Motivation

### 核心论点

现有 AI 工具都是"单模型对话"，缺少多元视角的碰撞。

### 三个递进层次

**1. 现状问题**

- 主流 AI 聊天工具（ChatGPT、Gemini、Claude）都是用户与单个模型一对一交互
- 单一模型再强大，也只代表一种推理路径，容易产生"确认偏差"（confirmation bias）
- 缺少一个让不同"思维方式"正面交锋的机制

**2. 核心假设**

> 如果让多个拥有不同认识论立场的 Agent（分析师、批判者、创意者、实用主义者……）就同一个问题辩论，产出会比任何单个模型更丰富、更平衡。

**3. 应用场景**

- 研究头脑风暴：快速收集多学科视角
- 创意决策：让"保守派"和"激进派"互相对冲
- 结构化辩论：模拟陪审团/圆桌讨论，帮助人类决策者看到盲区

### 视觉建议

左右对比图——左边"传统：1个用户 ↔ 1个AI"，右边"本项目：1个用户 ↔ N个AI Agent 辩论"。用箭头和角色图标表现。

---

## Slide 3 — Requirements & Design Summary

### 需求摘要（Requirements Summary）

|                      1                      |                  2                  |                            3                             |                                4                                 |                            5                             |
| :-----------------------------------------: | :---------------------------------: | :------------------------------------------------------: | :--------------------------------------------------------------: | :------------------------------------------------------: |
|              **User Roles** 👤              |     **Agent Configuration** ⚙️      |                 **Discussion Modes** 🔄                  |                     **Smart Interaction** 🎯                     |                  **Real-time Sync** 🔥                   |
|  Group Leader:<br>Manage agents & settings  | Name & Persona Prompt<br>per agent  | Sequential Mode:<br>N-round debate +<br>conclusion phase |        @AgentName:<br>Direct trigger to<br>specific agent        |            Firestore-driven<br>real-time sync            |
| Group Member:<br>Participate in discussions | LLM Provider selection<br>per agent | Concurrent Mode:<br>All agents respond<br>simultaneously |      @UserName:<br>Inject user context<br>(last 3 messages)      | Millisecond-level<br>propagation to<br>all group members |
|                                             |  Independent API Key<br>per agent   |                                                          | Streaming output:<br>Real-time character-<br>by-character render |                                                          |

<details>
<summary>📐 LaTeX 格式（适用于 Beamer/学术幻灯片）</summary>

```latex
\begin{table}[h]
\centering
\small
\begin{tabular}{|c|c|c|c|c|}
\hline
\textbf{User Roles} & \textbf{Agent Config} & \textbf{Discussion Mode} & \textbf{Smart Interaction} & \textbf{Real-time Sync} \\
\hline
\makecell{Group Leader:\\Manage agents\\\& settings} &
\makecell{Name \& Persona\\Prompt per agent\\LLM Provider\\Independent API Key} &
\makecell{Sequential:\\N-round debate\\+ conclusion\\Concurrent:\\All respond at once} &
\makecell{@AgentName:\\Direct trigger\\@UserName:\\Inject context\\Streaming output} &
\makecell{Firestore-driven\\Millisecond sync\\All members see\\changes instantly} \\
\hline
\end{tabular}
\caption{Requirements Summary}
\end{table}
```

</details>

### 架构设计一句话总结

> Client-heavy, Serverless — 全部业务逻辑在 Flutter 客户端，Firebase 提供身份认证和实时文档存储，LLM 通过 OpenAI 兼容的 SSE 端点直接调用。

### 关键技术选型

```
UI:        Flutter (Material 3)
状态管理:   Provider (5 个 ChangeNotifier)
后端:       Firebase Auth + Firestore
LLM:       Kimi / DeepSeek / Qwen / Doubao (统一 SSE)
上下文:     滑动窗口 (6条消息) + 自动摘要
```

### 视觉建议

用架构图（Flutter Client → Firebase → LLM Providers）的简化版，三个层次用不同颜色的方框表示。

---

## Slide 4 — How AI Was Used (with Examples)

### 使用的 AI 工具一览

| 工具                 | 用途                                    | 阶段               |
| -------------------- | --------------------------------------- | ------------------ |
| Gemini Deep Research | 初始架构规划与分析                      | 项目启动           |
| Antigravity          | 快速原型生成、主要功能开发              | 2026-02-20 ~ 02-27 |
| Kiro                 | Antigravity 额度用完后继续开发、UX 优化 | 2026-02-27 ~ 04-05 |
| Claude Code          | 文档整理、代码质量审查                  | 2026-04-05         |

### 典型交互示例（选 2-3 个最有代表性的放在 PPT 上）

**<**示例 3：Bug 修复（Kiro）\*\*

- **Prompt：** "Fix: theme lost on restart, user messages not rendering Markdown, input loses focus..."
- **AI 输出：** 逐个修复：`SharedPreferences` 持久化、`MarkdownBody` 包裹、`requestFocus()` 调用
- **我的调整：** 补充了 AI 没发现的 2 个问题（废弃按钮、冗余参与复选框）
- **启发：** AI 擅长单点 bug 修复，但系统性的 UI 一致性问题仍需人工审查

### 协作模式总结

> AI 负责**生成与加速**，人类负责**验证、裁剪、架构决策**。

### 视觉建议

用时间轴（Timeline）展示 4 个工具的使用阶段，标注每个阶段的关键产出。或者用一个"Prompt → AI Response → My Refinement"的三列流程图展示一个完整交互循环。

---

## Slide 5 — Implementation Highlights

### 亮点 1：统一 SSE 流式引擎

一个 `_callLLMStream()` 方法兼容 4 家 LLM 提供商，仅通过 endpoint URL 区分。Doubao 专属的 endpoint ID 映射是唯一的分支逻辑。

```
用户提问 → ChatService.submitQuestion()
  → _callLLMStream(agent) → SSE 解析 → 逐字渲染
  → 顺序模式: for round → for agent → 流式输出
  → 并发模式: Future.wait([所有 agent 并行流式])
```

**为什么值得一提：** 大多数多模型应用为每个提供商写单独的适配器；本项目通过识别"OpenAI 兼容格式"这一共性，用 ~40 行代码统一了全部提供商。

### 亮点 2：滑动窗口上下文 + 自动摘要

```
_buildHistoryPayload(agent, windowSize=6)
  ├── [system] 会话摘要（如有，≤200字）
  ├── [user]   其他 Agent 的发言（"Agent X 说：..."）
  ├── [assistant] 本 Agent 之前说过的话
  └── [user]   用户消息（"[User: Name] 说：..."）
```

- 每次发言只取最近 6 条消息，防止 token 溢出
- ≥10 条消息后后台静默生成摘要，合并到后续上下文
- 角色分配策略：本 Agent 的历史作为 `assistant`，其他 Agent 的作为 `user`——与 LLM 训练时的对话格式一致

**为什么值得一提：** 这是让多轮辩论保持连贯性的核心技术。简单拼接历史会导致上下文爆炸，完全不传历史又让 Agent 失去"记忆"。

### 亮点 3：群组级实时同步

- Firestore snapshot listeners 同时监听 4 个数据流（agents、sessions、messages、group settings）
- 群主修改讨论模式或轮次 → 所有成员端立即生效，无需刷新
- 6 位邀请码设计（排除 I/O/1/0 避免视觉歧义），碰撞检测确保唯一

### 亮点 4：@Mention 双通道交互

- **键盘通道：** `@AgentName` 定向触发 / `@UserName` 注入该用户最近 3 条消息
- **触控通道：** 输入框上方的水平滚动 Chip Bar，点选参与 Agent
- Agent 回复中的 `@Name` 归因自动解析，UI 以引用气泡展示

### 视觉建议

亮点 1-2 适合用流程图/代码片段展示；亮点 3-4 适合用截图 + 标注说明。可以考虑一页放 2 个亮点，每个亮点配一个图。

---

## Slide 6 — Challenges and Limitations of AI

### AI 辅助开发中遇到的核心挑战

**挑战 1：跨切面问题（Cross-cutting Concerns）**

AI 擅长生成单一功能的代码（一个表单、一个 API 调用），但在涉及多个模块协作时频繁出错：

- @mention 系统的初始实现会触发递归 Agent 调用（Agent 回复中的 @ 被再次解析为用户输入）
- 顺序模式中累积的讨论文本被一次性塞入 prompt，导致上下文窗口溢出
- Firestore 监听器的生命周期管理（何时取消订阅）AI 生成的代码存在内存泄漏

**挑战 2：上下文切换成本**

- 从 Antigravity 切换到 Kiro 时（Interaction 7），需要重新建立项目上下文，导致临时性的代码不一致
- AI 无法自动理解"上一个工具生成的代码有什么隐含的设计决策"，新工具会推翻之前的设计

**挑战 3：安全与生产级缺失**

AI 生成的代码默认不包含生产级的安全措施：

- API Key 以明文存储在 Firestore 中，未加密
- 未定义 Firestore 安全规则（测试模式）
- 无输入长度限制、无请求频率控制

**挑战 4：代码质量退化**

- `chat_screen.dart`（1,268 行）和 `chat_service.dart`（1,007 行）远超推荐文件大小
- AI 倾向于在已有文件中追加代码，而非主动建议拆分模块
- 缺少自动化测试——AI 生成的代码未经验证就直接合入

### 项目本身的局限性

| 局限             | 说明                                              |
| ---------------- | ------------------------------------------------- |
| 无自动化测试     | 仅手动测试，回归风险高                            |
| 无消息分页       | 长会话全部加载，可能影响性能                      |
| 并发模式消息顺序 | 依赖到达时间排序，非严格时序                      |
| i18n 方案简单    | 手动 getter 方式，扩展到更多语言时需重构为 `intl` |
| 安全规则缺失     | 需在生产部署前补全 Firestore 规则                 |

### 视觉建议

用"期望 vs 现实"对比表格或红绿灯标记（红=高风险、黄=中风险、绿=可接受）来展示局限性的严重程度。

---

## Slide 7 — Lessons Learned and Reflections

### 关于 AI 辅助开发

**1. 窄 Prompt > 宽 Prompt**

| Prompt 类型                          | 效果               |
| ------------------------------------ | ------------------ |
| "Fix this specific Doubao 400 error" | 立即可用，一次通过 |
| "Build the full backend"             | 产出需要大量返工   |

**经验：** 把大任务拆成小任务，每次只让 AI 做一件事。

**2. AI 擅长什么，不擅长什么**

| AI 擅长的                     | AI 不擅长的                      |
| ----------------------------- | -------------------------------- |
| 表单验证、CRUD 弹窗、主题定义 | 跨模块状态管理、多步数据流       |
| 单点 bug 修复                 | 架构级设计决策                   |
| 代码模板与脚手架              | 安全与生产级配置                 |
| 文档审查与一致性检查          | 边缘情况处理（流取消、内存泄漏） |

**3. 工具切换是有代价的**

Antigravity → Kiro 的切换暴露了一个问题：AI 工具之间没有共享的"项目记忆"。切换后需要重新解释架构、数据模型、已有的设计决策。**经验：** 尽量在一个工具内完成一个完整的功能模块，避免中途换工具。

**4. 人工审查不可省略**

AI 生成的代码看似合理，但隐藏的问题（递归调用、内存泄漏、上下文溢出）只有通过人工测试和 code review 才能发现。**AI 是加速器，不是替代者。**

### 关于项目本身

- **Serverless 架构的正确选择：** 对原型阶段来说，Firebase 免去了所有运维负担，让开发精力集中在核心功能上
- **统一 SSE 格式的杠杆效应：** 识别"OpenAI 兼容"这一共性，用极少代码支持多家提供商——这是本项目最有效的技术决策
- **渐进式信息披露（Progressive Disclosure）：** 会话信息卡自动折叠、Agent 选择器 Chip Bar 等设计提升了可用性，这些是 AI 不会主动建议的 UX 细节

### 视觉建议

用"AI 能力雷达图"或"擅长/不擅长"对比矩阵来可视化 AI 的能力边界。教训部分可以用 numbered takeaways，每条配一个简短图标。

---

## Slide 8 — Demo or Screenshots

### 建议的演示流程

**Step 1：登录与群组（15 秒）**

- 展示登录界面
- 创建/加入群组，展示 6 位邀请码机制

**Step 2：Agent 配置（20 秒）**

- 打开 Agent 管理面板，展示 5 个预设模板
- 创建一个自定义 Agent（填入名称、Prompt、选择提供商和模型）

**Step 3：顺序模式辩论（核心演示，60 秒）**

- 提出一个有争议的问题（如"AI 是否应该拥有法律主体地位"）
- 选择 3-4 个 Agent，设置 2 轮辩论
- 展示流式输出效果、Agent 之间的 @归因回复
- 展示结论阶段（Agent 最终立场 + 主持人综合）

**Step 4：并发模式（15 秒）**

- 切换到并发模式，同一问题让所有 Agent 同时回答
- 对比两种模式的输出差异

**Step 5：实时同步（可选，15 秒）**

- 如果有两台设备，展示一端发送消息后另一端实时出现

**Step 6：其他功能快速展示（10 秒）**

- 导出为 Markdown
- 主题切换（深色/浅色）
- 语言切换（中文/英文）

### 需要准备的截图清单

| 截图                                        | 用途         | 对应 Slide |
| ------------------------------------------- | ------------ | ---------- |
| App 首屏 / 登录页                           | Slide 1 概览 | Slide 1    |
| 多 Agent 同时辩论的聊天界面                 | 核心功能展示 | Slide 3, 5 |
| Agent 配置弹窗（含预设模板）                | 个性化能力   | Slide 5    |
| 顺序模式结论阶段（Agent 立场 + 主持人综合） | 辩论完整性   | Slide 5, 8 |
| 并发模式 vs 顺序模式对比                    | 模式差异     | Slide 8    |
| 深色 / 浅色主题对比                         | UI 完成度    | Slide 8    |

### 视觉建议

- 录制一段 2-3 分钟的演示视频作为 backup，防止现场网络或 API 问题
- 截图用真实数据，不要用占位文本
- 如果时间有限，优先演示 Step 3（顺序模式辩论），这是最能体现项目价值的环节
