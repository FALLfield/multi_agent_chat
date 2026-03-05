import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import 'agent_edit_dialog.dart';

class AgentListScreen extends StatelessWidget {
  const AgentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Roster Configuration'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AgentEditDialog(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Agent'),
      ),
      body: Consumer<ChatService>(
        builder: (context, chatService, child) {
          final agents = chatService.activeAgents;

          if (agents.isEmpty) {
            return const Center(
              child: Text('No agents configured. Add one below.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final agent = agents[index];
              final isParticipating = chatService.isAgentParticipating(
                agent.id,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isParticipating
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: isParticipating ? 2 : 0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CheckboxListTile(
                    title: Text(
                      agent.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Provider: ${agent.provider.toUpperCase()} | Model: ${agent.modelName}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          agent.systemInstruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    value: isParticipating,
                    onChanged: (val) {
                      if (val != null) {
                        chatService.toggleAgentParticipation(agent.id, val);
                      }
                    },
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  AgentEditDialog(existingAgent: agent),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            if (agents.length <= 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot delete the last agent!',
                                  ),
                                ),
                              );
                              return;
                            }
                            chatService.deleteAgent(agent.id);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
