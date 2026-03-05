import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/chat_message.dart';

class ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final Function(String)? onReply;

  const ChatMessageWidget({super.key, required this.message, this.onReply});

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  bool _isHovered = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    if (widget.message.isUser) {
      return _buildUserMessage(context);
    } else {
      return _buildAgentMessage(context);
    }
  }

  Widget _buildUserMessage(BuildContext context) {
    final senderName = widget.message.senderName;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 24, left: 48),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(
            24,
          ).copyWith(bottomRight: const Radius.circular(8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            Text(
              widget.message.text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConclusion = widget.message.isConclusion;

    return GestureDetector(
      onLongPress: () => setState(() => _isHovered = !_isHovered),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32, right: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isConclusion
                  ? (isDark
                        ? Colors.amber.withValues(alpha: 0.1)
                        : Colors.amber.withValues(alpha: 0.15))
                  : (isDark
                        ? const Color(0xFF282A2D)
                        : const Color(0xFFF7F9FC)),
              borderRadius: BorderRadius.circular(
                24,
              ).copyWith(topLeft: const Radius.circular(8)),
              border: isConclusion
                  ? Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: _getAvatarColor(
                    widget.message.agent?.name,
                    isDark,
                  ),
                  child: _getAvatarIcon(widget.message.agent?.name, isDark),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // replyTo chip: shown when agent specifically replies to someone
                      if (widget.message.replyTo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply,
                                size: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '@${widget.message.replyTo}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Header row: agent name + badges + action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.message.agent?.name ?? 'Agent',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                if (isConclusion) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'FINAL SUMMARY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Toolbar — visible on hover or always on touch
                          Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Copy button
                                  _ToolbarButton(
                                    icon: _copied ? Icons.check : Icons.copy,
                                    label: _copied ? 'Copied' : 'Copy',
                                    color: _copied ? Colors.green : null,
                                    onTap: () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: widget.message.text,
                                        ),
                                      );
                                      setState(() => _copied = true);
                                      await Future.delayed(
                                        const Duration(seconds: 2),
                                      );
                                      if (mounted) {
                                        setState(() => _copied = false);
                                      }
                                    },
                                  ),
                                  // Debate button
                                  if (widget.onReply != null)
                                    _ToolbarButton(
                                      icon: Icons.gavel,
                                      label: 'Debate',
                                      onTap: () =>
                                          widget.onReply!(widget.message.text),
                                    ),
                                ],
                              )
                              .animate(target: _isHovered ? 1 : 0)
                              .fade(duration: 250.ms)
                              .slideX(
                                begin: 0.1,
                                end: 0,
                                duration: 250.ms,
                                curve: Curves.easeOutBack,
                              ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Message content
                      if (widget.message.text == "Thinking...")
                        Text(
                              "Thinking...",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                            )
                            .animate(
                              onPlay: (controller) =>
                                  controller.repeat(reverse: true),
                            )
                            .fade(duration: 800.ms, begin: 0.4, end: 1.0)
                      else
                        MarkdownBody(
                          data: widget.message.text,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              height: 1.5,
                            ),
                            code: TextStyle(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              fontFamily: 'monospace',
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String? name, bool isDark) {
    if (name == null) return isDark ? Colors.white10 : Colors.black12;
    final lowerName = name.toLowerCase();
    if (lowerName.contains('kimi')) {
      return const Color(0xFFE35454);
    }
    if (lowerName.contains('qianwen') || lowerName.contains('qwen')) {
      return const Color(0xFF6A4CFA);
    }
    if (lowerName.contains('doubao')) {
      return const Color(0xFF007BFF);
    }
    if (lowerName.contains('deepseek')) {
      return const Color(0xFF32B97A);
    }
    // Fallback
    return isDark ? Colors.white10 : Colors.black12;
  }

  Widget _getAvatarIcon(String? name, bool isDark) {
    if (name == null) {
      return Text(
        'A',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    final lowerName = name.toLowerCase();
    IconData? iconData;
    Color iconColor = Colors.white;

    if (lowerName.contains('kimi')) {
      iconData = Icons.auto_awesome;
    } else if (lowerName.contains('qianwen') || lowerName.contains('qwen')) {
      iconData = Icons.psychology;
    } else if (lowerName.contains('doubao')) {
      iconData = Icons.smart_toy;
    } else if (lowerName.contains('deepseek')) {
      iconData = Icons.explore;
    }

    if (iconData != null) {
      return Icon(iconData, color: iconColor, size: 20);
    }

    return Text(
      name.substring(0, 1).toUpperCase(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// A small icon button used inside the hover toolbar
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c =
        color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: 16, color: c),
        ),
      ),
    );
  }
}
