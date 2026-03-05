import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final Map<String, TextEditingController> _controllers = {
    'kimi': TextEditingController(),
    'doubao': TextEditingController(),
    'deepseek': TextEditingController(),
  };
  final TextEditingController _doubaoEndpointController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load existing keys from ChatService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = Provider.of<ChatService>(context, listen: false);
      _controllers['kimi']?.text = chatService.getApiKey('kimi');
      _controllers['doubao']?.text = chatService.getApiKey('doubao');
      _controllers['deepseek']?.text = chatService.getApiKey('deepseek');
      _doubaoEndpointController.text = chatService.doubaoEndpoint;
    });
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _doubaoEndpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildApiKeyField('Kimi API Key', 'kimi'),
            const SizedBox(height: 12),
            _buildApiKeyField('DeepSeek API Key', 'deepseek'),
            const Divider(height: 32),
            _buildApiKeyField('Doubao API Key', 'doubao'),
            const SizedBox(height: 12),
            TextField(
              controller: _doubaoEndpointController,
              decoration: const InputDecoration(
                labelText: 'Doubao Endpoint ID (ep-xxx)',
                border: OutlineInputBorder(),
                isDense: true,
                helperText: '火山引擎需填入具体接入点ID',
              ),
              onChanged: (value) {
                final chatService = Provider.of<ChatService>(
                  context,
                  listen: false,
                );
                chatService.updateDoubaoEndpoint(value);
              },
            ),
            const Divider(height: 32),
            const Text(
              'Discussion Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Consumer<ChatService>(
              builder: (context, chatService, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sequential Mode Rounds: ${chatService.discussionRounds}',
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
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildApiKeyField(String label, String key) {
    return TextField(
      controller: _controllers[key],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      obscureText: true,
      onChanged: (value) {
        final chatService = Provider.of<ChatService>(context, listen: false);
        chatService.updateApiKey(key, value);
      },
    );
  }
}
