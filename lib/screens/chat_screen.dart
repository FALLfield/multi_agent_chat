import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../services/export_helper.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../theme/theme_service.dart';
import '../services/chat_service.dart';
import '../widgets/chat_message_widget.dart';
import '../models/user_persona.dart';
import 'settings_dialog.dart';
import 'agent_list_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
      _checkFirstUser();
    });
  }

  void _checkFirstUser() {
    if (_hasCheckedUser) return;
    _hasCheckedUser = true;
    final chatService = Provider.of<ChatService>(context, listen: false);
    if (chatService.users.length == 1 &&
        chatService.users[0].name == 'User 1') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _WelcomeUserDialog(),
      );
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
    if (chatService.messages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to export yet.')));
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
            const SnackBar(content: Text('Chat exported — check Downloads')),
          );
        }
      } else {
        final savedPath = await exportTextNative(markdown, filename);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Exported to: $savedPath')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleReply(String text) {
    setState(() {
      _textController.text = "针对以下观点发起深度辩论：\n\n『$text』\n\n请就此发表看法或提出反驳意见：\n";
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Discussion'),
        centerTitle: false,
        actions: [
          Consumer<ChatService>(
            builder: (context, chatService, child) {
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
                        'Switched to ${isSequential ? 'Concurrent' : 'Sequential'} Mode',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Mode: ${isSequential ? 'Sequential' : 'Concurrent'}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportChat,
            tooltip: 'Export Chat',
          ),
          IconButton(
            icon: Icon(
              themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: themeService.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const SettingsDialog(),
              );
            },
            tooltip: 'API Settings',
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
                          'Hello, ${chatService.currentUser?.name ?? "User"}.\nWhat can we discuss today?',
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
                    return ChatMessageWidget(
                          key: ValueKey(messages[index - 1].id),
                          message: messages[index - 1],
                          onReply: _handleReply,
                        )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(
                          begin: 0.1,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
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
          const Text(
            'Session Info',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Mode: ${chatService.discussionMode == DiscussionMode.sequential ? 'Sequential' : 'Concurrent'}',
          ),
          if (chatService.discussionMode == DiscussionMode.sequential)
            Text('Rounds: ${chatService.discussionRounds}'),
          Text('Active Agents: ${chatService.participatingAgentIds.length}'),
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
                  Text(
                    '正在讨论中...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_comment),
              title: const Text('New Discussion'),
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
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No discussion history.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }
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
              title: const Text(
                'Clear History',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear History'),
                    content: const Text(
                      'Are you sure you want to delete all chat history? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          final chatService = Provider.of<ChatService>(
                            context,
                            listen: false,
                          );
                          chatService.clearAllHistory();
                          Navigator.pop(context); // close dialog
                          Navigator.pop(context); // close drawer
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt),
              title: const Text('Agent Roster'),
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
            // User section
            Consumer<ChatService>(
              builder: (context, chatService, child) {
                if (chatService.users.isEmpty) return const SizedBox.shrink();
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('Current: ${chatService.currentUser?.name}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () {
                      if (chatService.currentUser != null) {
                        chatService.deleteUser(chatService.currentUser!.id);
                      }
                    },
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person_add, size: 16),
              ),
              title: const Text('Add New User'),
              subtitle: const Text('Create a new sender identity'),
              onTap: () {
                Navigator.pop(context); // close drawer
                showDialog(
                  context: context,
                  builder: (context) => const _NewUserDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NewUserDialog extends StatefulWidget {
  const _NewUserDialog();

  @override
  State<_NewUserDialog> createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<_NewUserDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New User Persona'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Enter your new identity...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Provider.of<ChatService>(
                context,
                listen: false,
              ).addUser(_controller.text.trim());
            }
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
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
            Consumer<ChatService>(
              builder: (context, chatService, child) {
                if (chatService.users.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserPersona>(
                      value: chatService.currentUser,
                      icon: const Icon(Icons.arrow_drop_down, size: 16),
                      items: chatService.users.map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text(
                            u.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (UserPersona? newUser) {
                        if (newUser != null) {
                          chatService.setCurrentUser(newUser);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
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
                    hintText: 'Ask a question...',
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

class _WelcomeUserDialog extends StatefulWidget {
  const _WelcomeUserDialog();

  @override
  State<_WelcomeUserDialog> createState() => _WelcomeUserDialogState();
}

class _WelcomeUserDialogState extends State<_WelcomeUserDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('欢迎！请设置你的名称'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Enter your identity...',
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Provider.of<ChatService>(
                context,
                listen: false,
              ).addUser(_controller.text.trim());
              Navigator.pop(context);
            }
          },
          child: const Text('Let\'s Go'),
        ),
      ],
    );
  }
}
