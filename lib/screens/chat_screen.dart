import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';
import '../services/export_helper.dart';

import '../theme/theme_service.dart';
import '../services/chat_service.dart';
import '../services/locale_service.dart';
import '../widgets/chat_message_widget.dart';
import '../models/group.dart';
import 'group_settings_dialog.dart';
import 'agent_list_screen.dart';

class ChatScreen extends StatefulWidget {
  final Group? group;

  const ChatScreen({super.key, this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _hasCheckedUser = false;
  bool _sessionInfoExpanded = true;

  static Color _getAvatarColor(String name, bool isDark) {
    final lower = name.toLowerCase();
    if (lower.contains('kimi')) return const Color(0xFFE35454);
    if (lower.contains('qwen')) return const Color(0xFF6A4CFA);
    if (lower.contains('doubao')) return const Color(0xFF007BFF);
    if (lower.contains('deepseek')) return const Color(0xFF32B97A);
    return isDark ? Colors.white24 : Colors.black26;
  }

  static IconData _getAvatarIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('kimi')) return Icons.auto_awesome;
    if (lower.contains('qwen')) return Icons.psychology;
    if (lower.contains('doubao')) return Icons.smart_toy;
    if (lower.contains('deepseek')) return Icons.explore;
    return Icons.person;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enterGroupMode();
    });
  }

  Future<void> _enterGroupMode() async {
    if (_hasCheckedUser) return;
    _hasCheckedUser = true;

    final group = widget.group;
    if (group != null) {
      final chatService = Provider.of<ChatService>(context, listen: false);
      await chatService.enterGroupMode(group);
    }
  }

  /// Builds a Markdown string from all current messages.
  String _buildMarkdown(ChatService chatService) {
    final session = chatService.sessions.firstWhere(
      (s) => s.id == chatService.activeSessionId,
      orElse: () => chatService.sessions.isNotEmpty
          ? chatService.sessions.first
          : throw StateError('no session'),
    );
    final buf = StringBuffer();
    buf.writeln('# ${session.title}');
    buf.writeln();
    buf.writeln(
      '> Exported on ${DateTime.now().toLocal().toString().split(".").first}',
    );
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
    for (final msg in chatService.messages) {
      if (msg.isUser) {
        final sender = msg.senderName ?? 'User';
        buf.writeln('### $sender');
        buf.writeln();
        buf.writeln(msg.text);
      } else {
        final agentName = msg.agent?.name ?? 'Agent';
        final label = msg.isConclusion
            ? '$agentName — Final Summary'
            : agentName;
        buf.writeln('### $label');
        if (msg.replyTo != null) {
          buf.writeln();
          buf.writeln('> Replying to @${msg.replyTo}');
        }
        buf.writeln();
        buf.writeln(msg.text);
      }
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
    }
    return buf.toString();
  }

  Future<void> _exportChat() async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final locale = Provider.of<LocaleService>(context, listen: false);
    if (chatService.messages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(locale.nothingToExport)));
      return;
    }
    try {
      final markdown = _buildMarkdown(chatService);
      final filename =
          'chat_export_${DateTime.now().millisecondsSinceEpoch}.md';
      if (kIsWeb) {
        await downloadTextWeb(
          markdown,
          filename,
          'text/markdown; charset=utf-8',
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(locale.chatExported)));
        }
      } else {
        final savedPath = await exportTextNative(markdown, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${locale.exportFailed}$savedPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${locale.exportFailed}$e')));
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleReply(String text) {
    final locale = Provider.of<LocaleService>(context, listen: false);
    setState(() {
      _textController.text =
          '${locale.debatePromptPrefix}$text${locale.debatePromptSuffix}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.group?.name ??
              Provider.of<LocaleService>(context, listen: false).newDiscussion,
        ),
        centerTitle: false,
        actions: [
          Consumer<LocaleService>(
            builder: (context, locale, _) => IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportChat,
              tooltip: locale.exportChat,
            ),
          ),
          IconButton(
            icon: Icon(
              themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: themeService.toggleTheme,
            tooltip: Provider.of<LocaleService>(
              context,
              listen: false,
            ).toggleTheme,
          ),
          if (widget.group != null)
            Consumer<LocaleService>(
              builder: (context, locale, _) => IconButton(
                icon: const Icon(Icons.settings_applications),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        GroupSettingsDialog(group: widget.group!),
                  );
                },
                tooltip: locale.groupSettings,
              ),
            ),
        ],
      ),
      drawer: const _ChatDrawer(),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatService>(
              builder: (context, chatService, child) {
                final messages = chatService.messages;
                if (messages.isEmpty) {
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  final locale = Provider.of<LocaleService>(
                    context,
                    listen: false,
                  );
                  final displayName =
                      authService.currentUser?.displayName ??
                      authService.currentUser?.email ??
                      'there';
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.forum_outlined,
                            size: 40,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${locale.helloGreeting}$displayName,',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          locale.discussToday,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSessionInfoCard(chatService);
                    }
                    return _AnimatedMessageEntry(
                      key: ValueKey(messages[index - 1].id),
                      child: ChatMessageWidget(
                        message: messages[index - 1],
                        onReply: _handleReply,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Consumer<ChatService>(
            builder: (context, chatService, child) {
              if (chatService.isProcessing) {
                return _buildProgressArea(chatService);
              }
              return _BottomArea(controller: _textController);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoCard(ChatService chatService) {
    final locale = Provider.of<LocaleService>(context, listen: false);
    final isSequential =
        chatService.discussionMode == DiscussionMode.sequential;
    final colorScheme = Theme.of(context).colorScheme;

    // Auto-collapse when there are messages
    if (chatService.messages.isNotEmpty && _sessionInfoExpanded) {
      _sessionInfoExpanded = false;
    }

    return GestureDetector(
      onTap: () => setState(() => _sessionInfoExpanded = !_sessionInfoExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                _InfoPill(
                  label:
                      '${locale.modeLabel}${isSequential ? locale.sequential : locale.concurrent}',
                  icon: isSequential ? Icons.linear_scale : Icons.scatter_plot,
                  colorScheme: colorScheme,
                ),
                if (isSequential) ...[
                  const SizedBox(width: 8),
                  _InfoPill(
                    label: '${locale.rounds}${chatService.discussionRounds}',
                    icon: Icons.repeat,
                    colorScheme: colorScheme,
                  ),
                ],
                const SizedBox(width: 8),
                _InfoPill(
                  label:
                      '${chatService.participatingAgentIds.length} ${locale.activeAgents}',
                  icon: Icons.smart_toy,
                  colorScheme: colorScheme,
                ),
                const Spacer(),
                Icon(
                  _sessionInfoExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
            if (_sessionInfoExpanded) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final agent in chatService.activeAgents)
                    if (chatService.isAgentParticipating(agent.id))
                      _InfoPill(
                        label: agent.name,
                        icon: _getAvatarIcon(agent.name),
                        colorScheme: colorScheme,
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressArea(ChatService chatService) {
    final locale = Provider.of<LocaleService>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final speakingAgent = chatService.currentSpeakingAgent;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          if (speakingAgent != null) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: _getAvatarColor(
                speakingAgent.name,
                Theme.of(context).brightness == Brightness.dark,
              ),
              child: Icon(
                _getAvatarIcon(speakingAgent.name),
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              speakingAgent != null
                  ? '${speakingAgent.name} ${locale.typingIndicator}'
                  : locale.discussing,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.stop_circle, color: colorScheme.error, size: 28),
            onPressed: () => chatService.stopGeneration(),
            tooltip: locale.stopGeneration,
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme colorScheme;

  const _InfoPill({
    required this.label,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatDrawer extends StatelessWidget {
  const _ChatDrawer();

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final groupService = Provider.of<GroupService>(context, listen: false);
    final isLeader = groupService.activeGroup?.isLeader(currentUid) ?? false;
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── Discussion History section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  locale.discussionHistory,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            if (isLeader)
              ListTile(
                leading: const Icon(Icons.add_comment, size: 20),
                title: Text(locale.newDiscussion),
                dense: true,
                onTap: () {
                  final chatService = Provider.of<ChatService>(
                    context,
                    listen: false,
                  );
                  chatService.createNewSession();
                  Navigator.pop(context);
                },
              ),
            Expanded(
              child: Consumer<ChatService>(
                builder: (context, chatService, child) {
                  final sessions = chatService.sessions;
                  if (sessions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          locale.noDiscussionHistory,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    );
                  }
                  final groupService = Provider.of<GroupService>(
                    context,
                    listen: false,
                  );
                  final currentUid =
                      FirebaseAuth.instance.currentUser?.uid ?? '';
                  final isLeader =
                      groupService.activeGroup?.isLeader(currentUid) ?? false;

                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive =
                          session.id == chatService.activeSessionId;
                      return ListTile(
                        leading: const Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                        ),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isActive,
                        dense: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: locale.rename,
                              onPressed: () {
                                final ctrl = TextEditingController(
                                  text: session.title,
                                );
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(locale.renameDiscussion),
                                    content: TextField(
                                      controller: ctrl,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        labelText: locale.newName,
                                        border: const OutlineInputBorder(),
                                      ),
                                      onSubmitted: (val) {
                                        chatService.renameSession(
                                          session.id,
                                          val,
                                        );
                                        Navigator.pop(ctx);
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(locale.cancel),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          chatService.renameSession(
                                            session.id,
                                            ctrl.text,
                                          );
                                          Navigator.pop(ctx);
                                        },
                                        child: Text(locale.save),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            if (isLeader)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                                tooltip: locale.deleteConversation,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(locale.deleteConversation),
                                      content: Text(
                                        '${locale.deleteConversationConfirm}${session.title}${locale.deleteConversationConfirmSuffix}',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text(locale.cancel),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            chatService.deleteSession(
                                              session.id,
                                            );
                                            Navigator.pop(ctx);
                                          },
                                          child: Text(
                                            locale.delete,
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        onTap: () {
                          chatService.loadSession(session.id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // ── Management section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  locale.management,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people_alt, size: 20),
              title: Text(locale.agentRoster),
              dense: true,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AgentListScreen(),
                  ),
                );
              },
            ),
            Consumer<GroupService>(
              builder: (context, groupService, child) {
                final group = groupService.activeGroup;
                if (group == null) return const SizedBox.shrink();

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(group.id)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || !snap.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    final data =
                        snap.data!.data() as Map<String, dynamic>? ?? {};
                    final rawNames = data['memberNames'];
                    final memberNames = rawNames is Map
                        ? Map<String, String>.from(
                            rawNames.map(
                              (k, v) => MapEntry(k.toString(), v.toString()),
                            ),
                          )
                        : <String, String>{};

                    if (memberNames.isEmpty) return const SizedBox.shrink();

                    final members = memberNames.values.toList()..sort();
                    return ExpansionTile(
                      initiallyExpanded: false,
                      dense: true,
                      leading: const Icon(
                        Icons.group,
                        size: 20,
                        color: Colors.green,
                      ),
                      title: Text(
                        '${locale.groupMembers} (${members.length})',
                        style: const TextStyle(fontSize: 14),
                      ),
                      children: members
                          .map(
                            (name) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.circle,
                                size: 8,
                                color: Colors.green,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.redAccent,
              ),
              title: Text(
                locale.clearHistory,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
              dense: true,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(locale.clearHistory),
                    content: Text(locale.clearHistoryConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(locale.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          final chatService = Provider.of<ChatService>(
                            context,
                            listen: false,
                          );
                          chatService.clearAllHistory();
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text(
                          locale.clear,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.exit_to_app,
                color: Colors.orange,
                size: 20,
              ),
              title: Text(
                locale.leaveDeleteGroup,
                style: const TextStyle(color: Colors.orange, fontSize: 14),
              ),
              dense: true,
              onTap: () {
                Navigator.pop(context);
                final chatService = Provider.of<ChatService>(
                  context,
                  listen: false,
                );
                final groupService = Provider.of<GroupService>(
                  context,
                  listen: false,
                );
                final group = groupService.activeGroup;

                if (group == null) return;

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(locale.leaveGroup),
                    content: Text(
                      group.isLeader(
                            FirebaseAuth.instance.currentUser?.uid ?? '',
                          )
                          ? locale.leaveGroupLeaderConfirm
                          : locale.leaveGroupMemberConfirm,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(locale.cancel),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(locale.processing)),
                          );

                          final success = await groupService.leaveOrDeleteGroup(
                            group,
                          );

                          if (success && context.mounted) {
                            chatService.exitGroupMode();
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  groupService.errorMessage ??
                                      locale.operationFailed,
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(locale.confirm),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows how many agents are currently selected to respond.
class _AgentCountHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
    final locale = Provider.of<LocaleService>(context);
    final count = chatService.participatingAgentIds.length;
    if (count == 0 || count == chatService.activeAgents.length) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$count${locale.agentCountLabel}',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Bottom area containing agent selector chips and the input field.
class _BottomArea extends StatelessWidget {
  final TextEditingController controller;

  const _BottomArea({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Agent selector chips
          _AgentSelector(),
          // Agent count text
          _AgentCountHint(),
          // Input area
          _ChatInputArea(controller: controller),
        ],
      ),
    );
  }
}

/// Horizontal scrollable row of agent chips for quick selection.
class _AgentSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
    final agents = chatService.activeAgents;
    final colorScheme = Theme.of(context).colorScheme;

    if (agents.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: agents.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final agent = agents[index];
          final isSelected = chatService.isAgentParticipating(agent.id);

          return GestureDetector(
            onTap: () {
              chatService.toggleAgentParticipation(agent.id, !isSelected);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.secondaryContainer
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: _getAvatarColor(
                      agent.name,
                      colorScheme.brightness == Brightness.dark,
                    ),
                    child: Icon(
                      _getAvatarIcon(agent.name),
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    agent.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String name, bool isDark) {
    final lower = name.toLowerCase();
    if (lower.contains('kimi')) return const Color(0xFFE35454);
    if (lower.contains('qwen')) return const Color(0xFF6A4CFA);
    if (lower.contains('doubao')) return const Color(0xFF007BFF);
    if (lower.contains('deepseek')) return const Color(0xFF32B97A);
    return isDark ? Colors.white24 : Colors.black26;
  }

  IconData _getAvatarIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('kimi')) return Icons.auto_awesome;
    if (lower.contains('qwen')) return Icons.psychology;
    if (lower.contains('doubao')) return Icons.smart_toy;
    if (lower.contains('deepseek')) return Icons.explore;
    return Icons.person;
  }
}

class _ChatInputArea extends StatefulWidget {
  final TextEditingController controller;

  const _ChatInputArea({required this.controller});

  @override
  State<_ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<_ChatInputArea> {
  late final FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.logicalKeysPressed.contains(
            LogicalKeyboardKey.shiftLeft,
          ) ||
          HardwareKeyboard.instance.logicalKeysPressed.contains(
            LogicalKeyboardKey.shiftRight,
          )) {
        return KeyEventResult.ignored; // Let it insert a new line
      } else {
        _submit();
        return KeyEventResult.handled; // Prevent new line
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.controller.text.trim().isEmpty) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.submitQuestion(widget.controller.text);

    widget.controller.clear();
    // Keep focus on the input field after sending
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202124) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 12.0,
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  maxLines: 5,
                  minLines: 1,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: Provider.of<LocaleService>(
                      context,
                      listen: false,
                    ).selectAgentsHint,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _hasText
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    color: _hasText
                        ? Theme.of(context).colorScheme.onPrimary
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                  onPressed: _hasText ? _submit : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Safe fade-in entry animation for message items.
class _AnimatedMessageEntry extends StatefulWidget {
  final Widget child;

  const _AnimatedMessageEntry({super.key, required this.child});

  @override
  State<_AnimatedMessageEntry> createState() => _AnimatedMessageEntryState();
}

class _AnimatedMessageEntryState extends State<_AnimatedMessageEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
