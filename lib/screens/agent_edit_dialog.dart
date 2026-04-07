import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent_persona.dart';
import '../services/chat_service.dart';
import '../services/locale_service.dart';

// ── Preset templates ────────────────────────────────────────────────────────
class _AgentTemplate {
  final String name;
  final String icon;
  final String instruction;
  const _AgentTemplate(this.name, this.icon, this.instruction);
}

List<_AgentTemplate> _getTemplates(LocaleService locale) {
  return [
    _AgentTemplate(
      locale.templateAnalyst,
      '🔍',
      locale.templateAnalystDesc,
    ),
    _AgentTemplate(
      locale.templateCreative,
      '💡',
      locale.templateCreativeDesc,
    ),
    _AgentTemplate(
      locale.templateCritic,
      '⚔️',
      locale.templateCriticDesc,
    ),
    _AgentTemplate(
      locale.templatePragmatist,
      '🔧',
      locale.templatePragmatistDesc,
    ),
    _AgentTemplate(
      locale.templateHumanist,
      '🤝',
      locale.templateHumanistDesc,
    ),
  ];
}
// ────────────────────────────────────────────────────────────────────────────

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
  late TextEditingController _apiKeyController;
  late TextEditingController _doubaoEndpointController;
  String _selectedProvider = 'deepseek';

  final List<String> _providers = ['kimi', 'deepseek', 'doubao', 'qwen'];

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
    _apiKeyController = TextEditingController(
      text: widget.existingAgent?.apiKey ?? '',
    );
    _doubaoEndpointController = TextEditingController(
      text: widget.existingAgent?.doubaoEndpoint ?? '',
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
    _apiKeyController.dispose();
    _doubaoEndpointController.dispose();
    super.dispose();
  }

  void _save() {
    final locale = Provider.of<LocaleService>(context, listen: false);
    if (_nameController.text.trim().isEmpty ||
        _modelNameController.text.trim().isEmpty ||
        _apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.validationEmptyFields)),
      );
      return;
    }

    final chatService = Provider.of<ChatService>(context, listen: false);

    final agent = AgentPersona(
      id: widget.existingAgent?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      systemInstruction: _instructionController.text.trim(),
      provider: _selectedProvider,
      modelName: _modelNameController.text.trim(),
      groupId: chatService.activeGroupId ?? '',
      apiKey: _apiKeyController.text.trim(),
      doubaoEndpoint: _doubaoEndpointController.text.trim(),
    );

    if (widget.existingAgent == null) {
      chatService.addAgent(agent);
    } else {
      chatService.updateAgentDetails(agent);
    }

    chatService.toggleAgentParticipation(agent.id, true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = Provider.of<LocaleService>(context, listen: false);
    final templates = _getTemplates(locale);

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
                        ? locale.createNewAgent
                        : locale.editAgent,
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
                        labelText: locale.agentName,
                        hintText: locale.agentNameHint,
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
                        labelText: locale.providerProtocol,
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
                        labelText: locale.modelName,
                        hintText: locale.modelNameHint,
                        prefixIcon: const Icon(Icons.memory_rounded),
                        helperText: locale.modelNameHelper,
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
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: locale.apiKey,
                        hintText: locale.apiKeyHint,
                        prefixIcon: const Icon(Icons.key_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                      ),
                    ),
                    if (_selectedProvider == 'doubao') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _doubaoEndpointController,
                        decoration: InputDecoration(
                          labelText: locale.doubaoEndpointId,
                          hintText: locale.doubaoEndpointHint,
                          prefixIcon: const Icon(Icons.link_rounded),
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
                    const SizedBox(height: 24),
                    // ── Preset Templates ──────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        locale.recommendedTemplates,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: templates.map((t) {
                        return ActionChip(
                          avatar: Text(t.icon, style: const TextStyle(fontSize: 14)),
                          label: Text(t.name, style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _nameController.text = t.name;
                              _instructionController.text = t.instruction;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // ─────────────────────────────────────────────────────
                    TextField(
                      controller: _instructionController,
                      maxLines: 5,
                      minLines: 3,
                      decoration: InputDecoration(
                        labelText: locale.systemInstruction,
                        alignLabelWithHint: true,
                        hintText: locale.systemInstructionHint,
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
                      locale.cancel,
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
                    label: Text(locale.saveAgent),
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
