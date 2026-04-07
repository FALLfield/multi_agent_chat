import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../services/locale_service.dart';

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
    final locale = Provider.of<LocaleService>(context);
    String? senderName = widget.message.senderName;
    if (senderName == null || senderName.trim().isEmpty) {
      senderName = locale.user;
    }
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 24, left: 48),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(
            24,
          ).copyWith(bottomRight: const Radius.circular(8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ),
            MarkdownBody(
              data: widget.message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 16,
                  height: 1.5,
                ),
                code: TextStyle(
                  backgroundColor: colorScheme.surface,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                codeblockDecoration: BoxDecoration(
                  color: colorScheme.surface,
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
                      // Header row: agent name + badges
                      Row(
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
                                    child: Text(
                                      Provider.of<LocaleService>(context).finalSummary,
                                      style: const TextStyle(
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
                          // Toolbar — visible on hover, placed after name in the same row
                          AnimatedOpacity(
                            opacity: _isHovered ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                // Copy button
                                _ToolbarButton(
                                  icon: _copied ? Icons.check : Icons.copy,
                                  label: _copied
                                      ? Provider.of<LocaleService>(context).copied
                                      : Provider.of<LocaleService>(context).copy,
                                  color: _copied ? Colors.green : null,
                                  onTap: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: widget.message.text),
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
                                    label: Provider.of<LocaleService>(context).debate,
                                    onTap: () =>
                                        widget.onReply!(widget.message.text),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Message content
                      if (widget.message.text == "Thinking...")
                        const _ThinkingText()
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
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(widget.message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
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

/// Pulsing "Thinking..." indicator using a plain AnimationController.
/// Avoids flutter_animate to prevent layout assertion errors on Web.
class _ThinkingText extends StatefulWidget {
  const _ThinkingText();

  @override
  State<_ThinkingText> createState() => _ThinkingTextState();
}

class _ThinkingTextState extends State<_ThinkingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        locale.thinking,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontStyle: FontStyle.italic,
          fontSize: 16,
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
