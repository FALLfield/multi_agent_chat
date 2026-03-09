import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/locale_service.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    return AlertDialog(
      title: Text(locale.apiSettings),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text(locale.discussionSettings, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Consumer<ChatService>(
              builder: (context, chatService, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${locale.sequentialRounds}${chatService.discussionRounds}'),
                    Slider(
                      value: chatService.discussionRounds.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: chatService.discussionRounds.toString(),
                      onChanged: (val) => chatService.setDiscussionRounds(val.toInt()),
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
