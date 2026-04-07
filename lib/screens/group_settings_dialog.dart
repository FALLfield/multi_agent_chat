import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../services/chat_service.dart';
import '../services/locale_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupSettingsDialog extends StatelessWidget {
  final Group group;

  const GroupSettingsDialog({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    final isLeader = group.isLeader(
      FirebaseAuth.instance.currentUser?.uid ?? '',
    );
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text(locale.groupSettingsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language switcher
            Row(
              children: [
                Icon(Icons.language, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  locale.language,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(locale.chinese)),
                    ButtonSegment(value: false, label: Text(locale.english)),
                  ],
                  selected: {locale.isChinese},
                  onSelectionChanged: (val) => locale.setLocale(val.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Invite code
            Text(
              locale.inviteCode,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    group.inviteCode,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: colorScheme.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: group.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(locale.inviteCodeCopied)),
                      );
                    },
                    tooltip: locale.copyInviteCode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Discussion settings (leader only)
            Text(
              locale.discussionSettings,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!isLeader)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      locale.onlyLeaderCanEdit,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            Consumer<ChatService>(
              builder: (context, chatService, _) {
                final isSequential =
                    chatService.discussionMode == DiscussionMode.sequential;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Discussion mode toggle
                    Row(
                      children: [
                        Icon(
                          isSequential
                              ? Icons.linear_scale
                              : Icons.scatter_plot,
                          size: 18,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          locale.discussionMode,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const Spacer(),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: true,
                              label: Text(locale.sequential),
                              icon: const Icon(Icons.linear_scale, size: 16),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text(locale.concurrent),
                              icon: const Icon(Icons.scatter_plot, size: 16),
                            ),
                          ],
                          selected: {isSequential},
                          onSelectionChanged: isLeader
                              ? (val) => chatService.setDiscussionMode(
                                  val.first
                                      ? DiscussionMode.sequential
                                      : DiscussionMode.concurrent,
                                )
                              : null,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Rounds slider (sequential only)
                    if (isSequential)
                      Row(
                        children: [
                          Text(
                            '${locale.sequentialRounds}${chatService.discussionRounds}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (isSequential)
                      Slider(
                        value: chatService.discussionRounds.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: chatService.discussionRounds.toString(),
                        onChanged: isLeader
                            ? (val) =>
                                  chatService.setDiscussionRounds(val.toInt())
                            : null,
                      ),
                    const SizedBox(height: 12),
                    // Output length limit
                    Row(
                      children: [
                        Icon(
                          Icons.text_fields,
                          size: 18,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          locale.outputLengthLimit,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const Spacer(),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'concise',
                              label: Text(locale.outputConcise),
                            ),
                            ButtonSegment(
                              value: 'medium',
                              label: Text(locale.outputMedium),
                            ),
                            ButtonSegment(
                              value: 'detailed',
                              label: Text(locale.outputDetailed),
                            ),
                            ButtonSegment(
                              value: 'unlimited',
                              label: Text(locale.outputUnlimited),
                            ),
                          ],
                          selected: {chatService.outputLengthLimit},
                          onSelectionChanged: isLeader
                              ? (val) =>
                                  chatService.setOutputLengthLimit(val.first)
                              : null,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(locale.close),
        ),
      ],
    );
  }
}
