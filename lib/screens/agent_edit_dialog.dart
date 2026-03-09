import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent_persona.dart';
import '../services/chat_service.dart';

// ── Preset templates ────────────────────────────────────────────────────────
class _AgentTemplate {
  final String name;
  final String icon;
  final String instruction;
  const _AgentTemplate(this.name, this.icon, this.instruction);
}

const _kTemplates = [
  _AgentTemplate(
    '理性分析师',
    '🔍',
    '你是一位严谨的理性分析师。你擅长用数据、逻辑和事实来支撑论点，善于发现论证中的漏洞和矛盾。发言时保持客观中立，避免情绪化表达，每次发言聚焦于最核心的一个论点。',
  ),
  _AgentTemplate(
    '创意先锋',
    '💡',
    '你是一位充满创意的思想先锋。你喜欢打破常规，提出颠覆性的想法和非主流视角。你鼓励大胆假设，不怕犯错，善于用类比和故事来阐述观点。发言时充满热情，富有感染力。',
  ),
  _AgentTemplate(
    '批判者',
    '⚔️',
    '你是一位犀利的批判者。你的职责是质疑一切假设，挑战现有观点的合理性。你善于找出论点的弱点、潜在风险和被忽视的反例。发言直接、尖锐，但始终基于逻辑而非情绪。',
  ),
  _AgentTemplate(
    '实用主义者',
    '🔧',
    '你是一位务实的实用主义者。你关注的是"这个方案在现实中能否落地"。你会从执行成本、时间、资源和可行性角度评估每个观点，并倾向于提出具体、可操作的改进建议。',
  ),
  _AgentTemplate(
    '人文关怀者',
    '🤝',
    '你是一位注重人文关怀的思考者。你从人的情感、伦理、社会影响和弱势群体的角度审视问题。你提醒大家不要只看效率和利益，还要关注方案对人的尊严、公平和心理健康的影响。',
  ),
];
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
    if (_nameController.text.trim().isEmpty ||
        _modelNameController.text.trim().isEmpty ||
        _apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, Model Name and API Key cannot be empty')),
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: 'sk-...',
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
                          labelText: 'Doubao Endpoint ID',
                          hintText: 'e.g. ep-2024...',
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
                        '推荐模板',
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
                      children: _kTemplates.map((t) {
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
