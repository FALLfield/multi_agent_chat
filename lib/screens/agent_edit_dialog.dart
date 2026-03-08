import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent_persona.dart';
import '../services/chat_service.dart';

class AgentEditDialog extends StatefulWidget {
  final AgentPersona? existingAgent;

  const AgentEditDialog({super.key, this.existingAgent});

  @override
  State<AgentEditDialog> createState() => _AgentEditDialogState();
}

class _AgentEditDialogState extends State<AgentEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _modelNameController;
  late TextEditingController _instructionController;
  String _selectedProvider = 'deepseek';

  final List<String> _providers = ['kimi', 'deepseek', 'doubao'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingAgent?.name ?? '',
    );
    _modelNameController = TextEditingController(
      text: widget.existingAgent?.modelName ?? '',
    );
    _instructionController = TextEditingController(
      text: widget.existingAgent?.systemInstruction ?? '',
    );
    if (widget.existingAgent != null &&
        _providers.contains(widget.existingAgent!.provider)) {
      _selectedProvider = widget.existingAgent!.provider;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelNameController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty ||
        _modelNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Model Name cannot be empty')),
      );
      return;
    }

    final chatService = Provider.of<ChatService>(context, listen: false);

    final agent = AgentPersona(
      id:
          widget.existingAgent?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      systemInstruction: _instructionController.text.trim(),
      provider: _selectedProvider,
      modelName: _modelNameController.text.trim(),
      groupId: chatService.activeGroupId ?? '',
    );

    if (widget.existingAgent == null) {
      chatService.addAgent(agent);
    } else {
      chatService.updateAgentDetails(agent);
    }

    // Automatically enable the new agent
    chatService.toggleAgentParticipation(agent.id, true);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        width: 450,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gorgeous Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.existingAgent == null
                        ? 'Create New Agent'
                        : 'Edit Agent',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Body Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Agent Name',
                        hintText: 'e.g. Frontend Expert',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProvider,
                      decoration: InputDecoration(
                        labelText: 'Provider Protocol',
                        prefixIcon: const Icon(Icons.api_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                      ),
                      items: _providers
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedProvider = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _modelNameController,
                      decoration: InputDecoration(
                        labelText: 'Model Name',
                        hintText: 'e.g. deepseek-chat',
                        prefixIcon: const Icon(Icons.memory_rounded),
                        helperText:
                            'Must exactly match the provider\'s API model ID',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _instructionController,
                      maxLines: 5,
                      minLines: 3,
                      decoration: InputDecoration(
                        labelText: 'System Instruction (Prompt Context)',
                        alignLabelWithHint: true,
                        hintText:
                            'Describe this AI\'s personality, expertise, and how it should behave...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey[50],
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Save Agent'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
