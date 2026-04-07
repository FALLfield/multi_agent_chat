import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const _prefKey = 'app_locale';

  bool _isChinese = true;
  bool get isChinese => _isChinese;

  LocaleService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isChinese = prefs.getBool(_prefKey) ?? true;
    notifyListeners();
  }

  Future<void> setLocale(bool isChinese) async {
    _isChinese = isChinese;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isChinese);
  }

  // ── Strings ────────────────────────────────────────────────────────────────

  // Auth
  String get login => _isChinese ? '登录' : 'Login';
  String get register => _isChinese ? '注册' : 'Register';
  String get nickname => _isChinese ? '昵称' : 'Nickname';
  String get email => _isChinese ? '邮箱' : 'Email';
  String get password => _isChinese ? '密码' : 'Password';
  String get appSubtitle =>
      _isChinese ? '多智能体讨论平台' : 'Multi-Agent Discussion Platform';

  // Home
  String get groups => _isChinese ? '群组' : 'Groups';
  String get noGroupsYet => _isChinese ? '暂无群组' : 'No Groups Yet';
  String get noGroupsHint => _isChinese
      ? '创建或加入群组开始协作。'
      : 'Create or join a group to start collaborating.';
  String get joinGroup => _isChinese ? '加入群组' : 'Join Group';
  String get createGroup => _isChinese ? '创建群组' : 'Create Group';
  String get newGroup => _isChinese ? '新建群组' : 'New Group';
  String get members => _isChinese ? '成员' : 'members';
  String get leader => _isChinese ? '群主' : 'Leader';
  String get retry => _isChinese ? '重试' : 'Retry';
  String get logout => _isChinese ? '退出登录' : 'Logout';

  // Create / Join Group Dialog
  String get createNewGroup => _isChinese ? '创建新群组' : 'Create New Group';
  String get groupName => _isChinese ? '群组名称' : 'Group Name';
  String get groupNameRequired =>
      _isChinese ? '群组名称不能为空' : 'Group name is required';
  String get cancel => _isChinese ? '取消' : 'Cancel';
  String get create => _isChinese ? '创建' : 'Create';
  String get join => _isChinese ? '加入' : 'Join';
  String get inviteCode => _isChinese ? '邀请码' : 'Invite Code';
  String get inviteCodeHint =>
      _isChinese ? '输入6位邀请码' : 'Enter 6-character code';
  String get inviteCodeRequired =>
      _isChinese ? '邀请码不能为空' : 'Invite code is required';
  String get failedToCreateGroup =>
      _isChinese ? '创建群组失败' : 'Failed to create group';
  String get failedToJoinGroup =>
      _isChinese ? '加入群组失败' : 'Failed to join group';

  // Chat Screen
  String get newDiscussion => _isChinese ? '新建讨论' : 'New Discussion';
  String get exportChat => _isChinese ? '导出对话' : 'Export Chat';
  String get toggleTheme => _isChinese ? '切换主题' : 'Toggle Theme';
  String get groupSettings => _isChinese ? '群组设置' : 'Group Settings';
  String get nothingToExport =>
      _isChinese ? '暂无内容可导出。' : 'Nothing to export yet.';
  String get chatExported =>
      _isChinese ? '对话已导出 — 请查看下载文件夹' : 'Chat exported — check Downloads';
  String get exportFailed => _isChinese ? '导出失败：' : 'Export failed: ';
  String get helloGreeting => _isChinese ? '你好，' : 'Hello, ';
  String get discussToday =>
      _isChinese ? '\n今天想讨论什么？' : '\nWhat can we discuss today?';
  String get sessionInfo => _isChinese ? '会话信息' : 'Session Info';
  String get modeLabel => _isChinese ? '模式：' : 'Mode: ';
  String get sequential => _isChinese ? '顺序' : 'Sequential';
  String get concurrent => _isChinese ? '并发' : 'Concurrent';
  String get rounds => _isChinese ? '轮次：' : 'Rounds: ';
  String get activeAgents => _isChinese ? '参与 Agent：' : 'Active Agents: ';
  String get switchedToMode => _isChinese ? '已切换至' : 'Switched to ';
  String get modeText => _isChinese ? '模式' : ' Mode';
  String get discussing => _isChinese ? '正在讨论中...' : 'Discussing...';
  String get askQuestion => _isChinese ? '提问...' : 'Ask a question...';
  String get debatePromptPrefix => _isChinese
      ? '针对以下观点发起深度辩论：\n\n『'
      : 'Start an in-depth debate on the following point:\n\n"';
  String get debatePromptSuffix => _isChinese
      ? '』\n\n请就此发表看法或提出反驳意见：\n'
      : '"\n\nPlease share your view or counter-argument:\n';

  // Drawer
  String get noDiscussionHistory =>
      _isChinese ? '暂无讨论记录。' : 'No discussion history.';
  String get rename => _isChinese ? '重命名' : 'Rename';
  String get renameDiscussion => _isChinese ? '重命名讨论' : 'Rename Discussion';
  String get newName => _isChinese ? '新名称' : 'New name';
  String get save => _isChinese ? '保存' : 'Save';
  String get deleteConversation => _isChinese ? '删除对话' : 'Delete Conversation';
  String get deleteConversationConfirm =>
      _isChinese ? '确定要删除「' : 'Are you sure you want to delete "';
  String get deleteConversationConfirmSuffix =>
      _isChinese ? '」吗？此操作不可撤销。' : '"? This cannot be undone.';
  String get delete => _isChinese ? '删除' : 'Delete';
  String get clearHistory => _isChinese ? '清空历史记录' : 'Clear History';
  String get clearHistoryConfirm => _isChinese
      ? '确定要删除所有聊天记录吗？此操作不可撤销。'
      : 'Are you sure you want to delete all chat history? This cannot be undone.';
  String get clear => _isChinese ? '清空' : 'Clear';
  String get groupMembers => _isChinese ? '群组成员' : 'Group Members';
  String get agentRoster => _isChinese ? 'Agent 配置' : 'Agent Roster';
  String get leaveDeleteGroup =>
      _isChinese ? '退出 / 解散群组' : 'Leave / Delete Group';
  String get leaveGroup => _isChinese ? '退出群组' : 'Leave Group';
  String get leaveGroupLeaderConfirm => _isChinese
      ? '确定要解散此群组吗？此操作将移除所有成员的群组访问权限。'
      : 'Are you sure you want to dismiss this group? This action will remove the group for all members.';
  String get leaveGroupMemberConfirm =>
      _isChinese ? '确定要退出此群组吗？' : 'Are you sure you want to leave this group?';
  String get processing => _isChinese ? '处理中...' : 'Processing...';
  String get confirm => _isChinese ? '确认' : 'Confirm';
  String get operationFailed => _isChinese ? '操作失败' : 'Operation failed';

  // Group Settings Dialog
  String get groupSettingsTitle => _isChinese ? '群组设置 ⚙️' : 'Group Settings ⚙️';
  String get onlyLeaderCanEdit =>
      _isChinese ? '只有群主可以编辑设置。' : 'Only the group leader can edit settings.';
  String get inviteCodeCopied => _isChinese ? '邀请码已复制！' : 'Invite code copied!';
  String get copyInviteCode => _isChinese ? '复制邀请码' : 'Copy Invite Code';
  String get discussionSettings => _isChinese ? '讨论设置' : 'Discussion Settings';
  String get discussionMode => _isChinese ? '讨论模式' : 'Discussion Mode';
  String get sequentialRounds =>
      _isChinese ? '顺序模式轮次：' : 'Sequential Mode Rounds: ';
  String get close => _isChinese ? '关闭' : 'Close';
  String get doubaoEndpointHint =>
      _isChinese ? '例如：ep-2024...' : 'e.g., ep-2024...';
  String get doubaoEndpointHelper => _isChinese
      ? '火山引擎需填入具体接入点ID'
      : 'Volcengine requires a specific endpoint ID';

  // Settings Dialog
  String get apiSettings => _isChinese ? 'API 设置' : 'API Settings';
  String get language => _isChinese ? '语言' : 'Language';
  String get chinese => _isChinese ? '中文' : 'Chinese';
  String get english => _isChinese ? 'English' : 'English';

  // Agent List
  String get agentRosterConfig =>
      _isChinese ? 'Agent 配置' : 'Agent Roster Configuration';
  String get newAgent => _isChinese ? '新建 Agent' : 'New Agent';
  String get noAgents =>
      _isChinese ? '暂无 Agent，请添加。' : 'No agents configured. Add one below.';
  String get cannotDeleteLastAgent =>
      _isChinese ? '不能删除最后一个 Agent！' : 'Cannot delete the last agent!';
  String get edit => _isChinese ? '编辑' : 'Edit';

  // Agent Edit Dialog
  String get createNewAgent =>
      _isChinese ? '创建新 Agent' : 'Create New Agent';
  String get editAgent => _isChinese ? '编辑 Agent' : 'Edit Agent';
  String get agentName => _isChinese ? 'Agent 名称' : 'Agent Name';
  String get agentNameHint =>
      _isChinese ? '例如：前端专家' : 'e.g. Frontend Expert';
  String get providerProtocol =>
      _isChinese ? '供应商协议' : 'Provider Protocol';
  String get modelName => _isChinese ? '模型名称' : 'Model Name';
  String get modelNameHint =>
      _isChinese ? '例如：deepseek-chat' : 'e.g. deepseek-chat';
  String get modelNameHelper => _isChinese
      ? '必须与供应商 API 的模型 ID 完全匹配'
      : "Must exactly match the provider's API model ID";
  String get apiKey => _isChinese ? 'API Key' : 'API Key';
  String get apiKeyHint => _isChinese ? 'sk-...' : 'sk-...';
  String get doubaoEndpointId =>
      _isChinese ? '豆包接入点 ID' : 'Doubao Endpoint ID';
  String get systemInstruction =>
      _isChinese ? '系统指令（提示上下文）' : 'System Instruction (Prompt Context)';
  String get systemInstructionHint => _isChinese
      ? '描述此 AI 的性格、专业领域和行为方式...'
      : "Describe this AI's personality, expertise, and how it should behave...";
  String get saveAgent =>
      _isChinese ? '保存 Agent' : 'Save Agent';
  String get validationEmptyFields => _isChinese
      ? '名称、模型名称和 API Key 不能为空'
      : 'Name, Model Name and API Key cannot be empty';
  String get recommendedTemplates =>
      _isChinese ? '推荐模板' : 'Recommended Templates';

  // Agent Templates
  String get templateAnalyst =>
      _isChinese ? '理性分析师' : 'Rational Analyst';
  String get templateAnalystDesc => _isChinese
      ? '你是一位严谨的理性分析师。你擅长用数据、逻辑和事实来支撑论点，善于发现论证中的漏洞和矛盾。发言时保持客观中立，避免情绪化表达，每次发言聚焦于最核心的一个论点。'
      : 'You are a rigorous rational analyst. You excel at supporting arguments with data, logic, and facts, and are skilled at identifying flaws and contradictions in reasoning. Maintain objectivity, avoid emotional expression, and focus each response on the single most core argument.';
  String get templateCreative =>
      _isChinese ? '创意先锋' : 'Creative Pioneer';
  String get templateCreativeDesc => _isChinese
      ? '你是一位充满创意的思想先锋。你喜欢打破常规，提出颠覆性的想法和非主流视角。你鼓励大胆假设，不怕犯错，善于用类比和故事来阐述观点。发言时充满热情，富有感染力。'
      : 'You are a creative thought pioneer full of innovative ideas. You enjoy breaking conventions, proposing disruptive ideas and unconventional perspectives. You encourage bold hypotheses, are unafraid of mistakes, and excel at using analogies and stories to illustrate points. Speak with passion and infectious enthusiasm.';
  String get templateCritic =>
      _isChinese ? '批判者' : 'Critic';
  String get templateCriticDesc => _isChinese
      ? '你是一位犀利的批判者。你的职责是质疑一切假设，挑战现有观点的合理性。你善于找出论点的弱点、潜在风险和被忽视的反例。发言直接、尖锐，但始终基于逻辑而非情绪。'
      : 'You are a sharp critic. Your role is to question all assumptions and challenge the validity of existing viewpoints. You excel at identifying weaknesses in arguments, potential risks, and overlooked counterexamples. Be direct and incisive, but always grounded in logic rather than emotion.';
  String get templatePragmatist =>
      _isChinese ? '实用主义者' : 'Pragmatist';
  String get templatePragmatistDesc => _isChinese
      ? '你是一位务实的实用主义者。你关注的是"这个方案在现实中能否落地"。你会从执行成本、时间、资源和可行性角度评估每个观点，并倾向于提出具体、可操作的改进建议。'
      : 'You are a pragmatic realist. Your focus is on whether a solution can actually be implemented in practice. You evaluate each viewpoint from the perspective of execution cost, time, resources, and feasibility, and tend to propose specific, actionable improvement suggestions.';
  String get templateHumanist =>
      _isChinese ? '人文关怀者' : 'Humanist';
  String get templateHumanistDesc => _isChinese
      ? '你是一位注重人文关怀的思考者。你从人的情感、伦理、社会影响和弱势群体的角度审视问题。你提醒大家不要只看效率和利益，还要关注方案对人的尊严、公平和心理健康的影响。'
      : 'You are a thinker who values humanistic care. You examine issues from the perspective of human emotions, ethics, social impact, and vulnerable groups. You remind everyone not to focus solely on efficiency and profit, but also to consider the impact on human dignity, fairness, and mental well-being.';

  // Chat Screen
  String get stopGeneration => _isChinese ? '停止' : 'Stop';
  String get selectAgents => _isChinese ? '选择 Agent' : 'Select Agents';
  String get allAgentsSelected => _isChinese ? '全部参与' : 'All participating';
  String get typingIndicator => _isChinese ? '正在思考...' : 'is thinking...';
  String get agentCountLabel =>
      _isChinese ? ' 位 Agent 将参与回复' : ' agents will respond';
  String get selectAgentsHint => _isChinese
      ? '输入问题，@提及或点选上方 Agent'
      : 'Ask a question. @mention or select agents above.';
  String get discussionHistory => _isChinese ? '讨论记录' : 'Discussion History';
  String get management => _isChinese ? '管理' : 'Management';

  // Output Length
  String get outputLengthLimit =>
      _isChinese ? '输出长度' : 'Output Length';
  String get outputConcise =>
      _isChinese ? '简短' : 'Concise';
  String get outputMedium =>
      _isChinese ? '适中' : 'Medium';
  String get outputDetailed =>
      _isChinese ? '详细' : 'Detailed';
  String get outputUnlimited =>
      _isChinese ? '不限' : 'Unlimited';

  // Chat Message Widget
  String get user => _isChinese ? '用户' : 'User';
  String get thinking => _isChinese ? '正在思考...' : 'Thinking...';
  String get copied => _isChinese ? '已复制' : 'Copied';
  String get copy => _isChinese ? '复制' : 'Copy';
  String get finalSummary =>
      _isChinese ? '最终总结' : 'FINAL SUMMARY';
  String get debate => _isChinese ? '辩论' : 'Debate';
  String get userFallback => _isChinese ? '用户' : 'there';
}
