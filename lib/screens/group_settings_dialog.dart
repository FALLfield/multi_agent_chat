import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../services/chat_service.dart';
import '../services/locale_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupSettingsDialog extends StatefulWidget {
  final Group group;

  const GroupSettingsDialog({super.key, required this.group});

  @override
  State<GroupSettingsDialog> createState() => _GroupSettingsDialogState();
}

class _GroupSettingsDialogState extends State<GroupSettingsDialog> {
  final _kimiController = TextEditingController();
  final _doubaoController = TextEditingController();
  final _deepseekController = TextEditingController();
  final _doubaoEndpointController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _kimiController.text = widget.group.apiKeys['kimi'] ?? '';
    _doubaoController.text = widget.group.apiKeys['doubao'] ?? '';
    _deepseekController.text = widget.group.apiKeys['deepseek'] ?? '';
    _doubaoEndpointController.text = widget.group.doubaoEndpoint;
  }

  @override
  void dispose() {
    _kimiController.dispose();
    _doubaoController.dispose();
    _deepseekController.dispose();
    _doubaoEndpointController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final service = Provider.of<GroupService>(context, listen: false);
    final success = await service.updateGroupApiKeys(
      groupId: widget.group.id,
      apiKeys: {
        'kimi': _kimiController.text.trim(),
        'doubao': _doubaoController.text.trim(),
        'deepseek': _deepseekController.text.trim(),
      },
      doubaoEndpoint: _doubaoEndpointController.text.trim(),
    );
    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LocaleService>(context, listen: false).apiKeysSaved,
            ),
          ),
        );
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    final isLeader = widget.group.isLeader(
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
            if (!isLeader)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(8),
                color: Colors.red.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locale.onlyLeaderCanEdit,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              locale.inviteCode,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.group.inviteCode,
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
                      Clipboard.setData(
                        ClipboardData(text: widget.group.inviteCode),
                      );
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
            Text(
              locale.sharedApiKeysSection,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              locale.sharedApiKeysDesc,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kimiController,
              readOnly: !isLeader,
              decoration: const InputDecoration(
                labelText: 'Kimi API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deepseekController,
              readOnly: !isLeader,
              decoration: const InputDecoration(
                labelText: 'DeepSeek API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _doubaoController,
              readOnly: !isLeader,
              decoration: const InputDecoration(
                labelText: 'Doubao API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _doubaoEndpointController,
              readOnly: !isLeader,
              decoration: InputDecoration(
                labelText: 'Doubao Endpoint ID',
                border: const OutlineInputBorder(),
                hintText: locale.doubaoEndpointHint,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              locale.discussionSettings,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Consumer<ChatService>(
              builder: (context, chatService, child) {
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
                          ? (val) {
                              chatService.setDiscussionRounds(val.toInt());
                            }
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
        if (isLeader)
          ElevatedButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(locale.save),
          ),
      ],
    );
  }
}
