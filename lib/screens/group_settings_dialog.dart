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
                Icon(Icons.language, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(locale.language, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(locale.chinese)),
                    ButtonSegment(value: false, label: Text(locale.english)),
                  ],
                  selected: {locale.isChinese},
                  onSelectionChanged: (val) => locale.setLocale(val.first),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const Divider(height: 24),

            // Invite code
            Text(locale.inviteCode, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
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
            Text(locale.discussionSettings, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (!isLeader)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.grey, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      locale.onlyLeaderCanEdit,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Consumer<ChatService>(
              builder: (context, chatService, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${locale.sequentialRounds}${chatService.discussionRounds}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Slider(
                      value: chatService.discussionRounds.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: chatService.discussionRounds.toString(),
                      onChanged: isLeader
                          ? (val) => chatService.setDiscussionRounds(val.toInt())
                          : null,
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
