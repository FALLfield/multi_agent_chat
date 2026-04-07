import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/locale_service.dart';
import 'agent_edit_dialog.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../services/group_service.dart';

class AgentListScreen extends StatelessWidget {
  const AgentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final locale = Provider.of<LocaleService>(context);
    final isLeader =
        groupService.activeGroup?.isLeader(
          FirebaseAuth.instance.currentUser?.uid ?? '',
        ) ??
        false;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(locale.agentRosterConfig), elevation: 0),
      floatingActionButton: isLeader
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AgentEditDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(locale.newAgent),
            )
          : null,
      body: Consumer<ChatService>(
        builder: (context, chatService, child) {
          final agents = chatService.activeAgents;

          if (agents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 36,
                      color: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locale.noAgents,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final agent = agents[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF282A2D)
                      : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Agent avatar
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _getAvatarColor(agent.name, isDark),
                        child: _getAvatarIcon(agent.name),
                      ),
                      const SizedBox(width: 14),
                      // Agent info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agent.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${agent.provider.toUpperCase()} · ${agent.modelName}',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              agent.systemInstruction,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit/Delete buttons (leader only)
                      if (isLeader) ...[
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      AgentEditDialog(existingAgent: agent),
                                );
                              },
                              tooltip: locale.edit,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                            if (agents.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  chatService.deleteAgent(agent.id);
                                },
                                tooltip: locale.delete,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String name, bool isDark) {
    final lower = name.toLowerCase();
    if (lower.contains('kimi')) return const Color(0xFFE35454);
    if (lower.contains('qwen')) return const Color(0xFF6A4CFA);
    if (lower.contains('doubao')) return const Color(0xFF007BFF);
    if (lower.contains('deepseek')) return const Color(0xFF32B97A);
    return isDark ? Colors.white24 : Colors.black26;
  }

  Widget _getAvatarIcon(String name) {
    final lower = name.toLowerCase();
    IconData? iconData;
    if (lower.contains('kimi')) {
      iconData = Icons.auto_awesome;
    } else if (lower.contains('qwen')) {
      iconData = Icons.psychology;
    } else if (lower.contains('doubao')) {
      iconData = Icons.smart_toy;
    } else if (lower.contains('deepseek')) {
      iconData = Icons.explore;
    }
    if (iconData != null) {
      return Icon(iconData, color: Colors.white, size: 20);
    }
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'A',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }
}
