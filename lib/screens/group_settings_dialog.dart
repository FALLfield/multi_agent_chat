import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../services/chat_service.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group API Keys saved.')));
      } else {
        setState(() => _isLoading = false);
        // Error is shown in GroupService
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Group Settings ⚙️'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invite Code',
              style: TextStyle(fontWeight: FontWeight.bold),
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
                        const SnackBar(content: Text('Invite code copied!')),
                      );
                    },
                    tooltip: 'Copy Invite Code',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Shared API Keys',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'These keys are shared with all group members. Only the group leader can edit them.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kimiController,
              decoration: const InputDecoration(
                labelText: 'Kimi API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deepseekController,
              decoration: const InputDecoration(
                labelText: 'DeepSeek API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _doubaoController,
              decoration: const InputDecoration(
                labelText: 'Doubao API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _doubaoEndpointController,
              decoration: const InputDecoration(
                labelText: 'Doubao Endpoint ID',
                border: OutlineInputBorder(),
                hintText: 'e.g., ep-2024...',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Discussion Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Consumer<ChatService>(
              builder: (context, chatService, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sequential Mode Rounds: ${chatService.discussionRounds}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Slider(
                      value: chatService.discussionRounds.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: chatService.discussionRounds.toString(),
                      onChanged: (val) {
                        chatService.setDiscussionRounds(val.toInt());
                      },
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
