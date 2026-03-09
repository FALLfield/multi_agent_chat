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
        buf.writeln('### 👤 $sender');
        buf.writeln();
        buf.writeln(msg.text);
      } else {
        final agentName = msg.agent?.name ?? 'Agent';
        final label = msg.isConclusion
            ? '$agentName — Final Summary'
            : agentName;
        buf.writeln('### 🤖 $label');
        if (msg.replyTo != null) {
          buf.writeln();
          buf.writeln('> ↩ Replying to @${msg.replyTo}');
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(locale.chatExported)),
          );
        }
      } else {
        final savedPath = await exportTextNative(markdown, filename);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${locale.exportFailed}$savedPath')));
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
        title: Text(widget.group?.name ?? Provider.of<LocaleService>(context, listen: false).newDiscussion),
        centerTitle: false,
        actions: [
          Consumer2<ChatService, LocaleService>(
            builder: (context, chatService, locale, child) {
              final isSequential =
                  chatService.discussionMode == DiscussionMode.sequential;
              return IconButton(
                icon: Icon(
                  isSequential ? Icons.linear_scale : Icons.scatter_plot,
                ),
                onPressed: () {
                  chatService.setDiscussionMode(
                    isSequential
                        ? DiscussionMode.concurrent
                        : DiscussionMode.sequential,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${locale.switchedToMode} ${isSequential ? locale.concurrent : locale.sequential}${locale.modeText}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip:
                    '${locale.modeLabel}${isSequential ? locale.sequential : locale.concurrent}',
              );
            },
          ),
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
            tooltip: Provider.of<LocaleService>(context, listen: false).toggleTheme,
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
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${locale.helloGreeting}$displayName.${locale.discussToday}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
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
              return _ChatInputArea(controller: _textController);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoCard(ChatService chatService) {
    final locale = Provider.of<LocaleService>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locale.sessionInfo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${locale.modeLabel}${chatService.discussionMode == DiscussionMode.sequential ? locale.sequential : locale.concurrent}',
          ),
          if (chatService.discussionMode == DiscussionMode.sequential)
            Text('${locale.rounds}${chatService.discussionRounds}'),
          Text('${locale.activeAgents}${chatService.participatingAgentIds.length}'),
        ],
      ),
    );
  }

  Widget _buildProgressArea(ChatService chatService) {
    return Padding(
      padding: const EdgeInsets.all(
        16.0,
      ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.black12,
          ),
        ),
        child: Row(
            children: [
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DiscussingText(),
                    SizedBox(height: 8),
                    LinearProgressIndicator(),
                  ],
                ),
              ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red, size: 32),
              onPressed: () => chatService.stopGeneration(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatDrawer extends StatelessWidget {
  const _ChatDrawer();

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_comment),
              title: Text(locale.newDiscussion),
              onTap: () {
                final chatService = Provider.of<ChatService>(
                  context,
                  listen: false,
                );
                chatService.createNewSession();
                Navigator.pop(context);
              },
            ),
            const Divider(),
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
                          style: const TextStyle(color: Colors.grey),
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
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isActive,
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
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: Text(
                locale.clearHistory,
                style: const TextStyle(color: Colors.redAccent),
              ),
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
            Consumer<GroupService>(
              builder: (context, groupService, child) {
                final group = groupService.activeGroup;
                if (group == null) return const SizedBox.shrink();

                // Stream the raw group doc to get live memberNames updates
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
                      initiallyExpanded: true,
                      leading: const Icon(Icons.group, color: Colors.green),
                      title: Text(
                        '${locale.groupMembers} (${members.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: members
                          .map(
                            (name) => ListTile(
                              leading: const Icon(
                                Icons.circle,
                                size: 10,
                                color: Colors.green,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontSize: 14),
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
              leading: const Icon(Icons.people_alt),
              title: Text(locale.agentRoster),
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AgentListScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: Text(
                locale.leaveDeleteGroup,
                style: const TextStyle(color: Colors.orange),
              ),
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(
        16.0,
      ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202124) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(32),
          // Slight soft shadow for floating effect
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
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: isDark ? Colors.white54 : Colors.black54,
              onPressed: () {},
              padding: const EdgeInsets.only(bottom: 8.0),
              constraints: const BoxConstraints(),
            ),
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
                    hintText: Provider.of<LocaleService>(context, listen: false).askQuestion,
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
/// Only uses FadeTransition (no position transform) to avoid
/// shifted_box.dart layout assertion errors on the Web renderer.
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

class _DiscussingText extends StatelessWidget {
  const _DiscussingText();

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    return Text(
      locale.discussing,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}
