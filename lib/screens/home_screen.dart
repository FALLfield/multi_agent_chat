import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../services/locale_service.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupService>(context, listen: false).loadMyGroups();
    });
  }

  void _createGroup() {
    showDialog(
      context: context,
      builder: (context) => const _CreateGroupDialog(),
    );
  }

  void _joinGroup() {
    showDialog(
      context: context,
      builder: (context) => const _JoinGroupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final locale = Provider.of<LocaleService>(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(locale.groups),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                auth.currentUser?.displayName ?? 'User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
            tooltip: locale.logout,
          ),
        ],
      ),
      body: Consumer<GroupService>(
        builder: (context, groupService, _) {
          if (groupService.isLoading && groupService.myGroups.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (groupService.errorMessage != null &&
              groupService.myGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(groupService.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => groupService.loadMyGroups(),
                    child: Text(locale.retry),
                  ),
                ],
              ),
            );
          }

          if (groupService.myGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 80,
                    color: cs.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locale.noGroupsYet,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locale.noGroupsHint,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _joinGroup,
                        icon: const Icon(Icons.login),
                        label: Text(locale.joinGroup),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: _createGroup,
                        icon: const Icon(Icons.add),
                        label: Text(locale.createGroup),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: groupService.loadMyGroups,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupService.myGroups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _joinGroup,
                            icon: const Icon(Icons.login),
                            label: Text(locale.joinGroup),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final group = groupService.myGroups[index - 1];
                final isLeader = group.isLeader(auth.currentUser?.uid ?? '');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        group.name.isNotEmpty
                            ? group.name[0].toUpperCase()
                            : 'G',
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text('${group.memberUids.length} ${locale.members}'),
                          if (isLeader) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                locale.leader,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      groupService.setActiveGroup(group);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(group: group),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Consumer<GroupService>(
        builder: (context, groupService, _) {
          return groupService.myGroups.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.add),
                  label: Text(locale.newGroup),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _kimiController = TextEditingController();
  final _doubaoController = TextEditingController();
  final _deepseekController = TextEditingController();
  final _doubaoEndpointController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _kimiController.dispose();
    _doubaoController.dispose();
    _deepseekController.dispose();
    _doubaoEndpointController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final locale = Provider.of<LocaleService>(context, listen: false);
    if (name.isEmpty) {
      setState(() => _error = locale.groupNameRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final service = Provider.of<GroupService>(context, listen: false);
    final group = await service.createGroup(
      name: name,
      apiKeys: {
        'kimi': _kimiController.text.trim(),
        'doubao': _doubaoController.text.trim(),
        'deepseek': _deepseekController.text.trim(),
      },
      doubaoEndpoint: _doubaoEndpointController.text.trim(),
    );

    if (mounted) {
      if (group != null) {
        Navigator.pop(context);
      } else {
        setState(() {
          _isLoading = false;
          _error = service.errorMessage ?? locale.failedToCreateGroup;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    return AlertDialog(
      title: Text(locale.createNewGroup),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: locale.groupName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            Text(
              locale.sharedApiKeys,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              locale.sharedApiKeysHint,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kimiController,
              decoration: const InputDecoration(
                labelText: 'Kimi API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deepseekController,
              decoration: const InputDecoration(
                labelText: 'DeepSeek API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _doubaoController,
              decoration: const InputDecoration(
                labelText: 'Doubao API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _doubaoEndpointController,
              decoration: InputDecoration(
                labelText: 'Doubao Endpoint ID',
                border: const OutlineInputBorder(),
                hintText: locale.doubaoEndpointHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(locale.cancel),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(locale.create),
        ),
      ],
    );
  }
}

class _JoinGroupDialog extends StatefulWidget {
  const _JoinGroupDialog();

  @override
  State<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<_JoinGroupDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final locale = Provider.of<LocaleService>(context, listen: false);
    if (code.isEmpty) {
      setState(() => _error = locale.inviteCodeRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final service = Provider.of<GroupService>(context, listen: false);
    final group = await service.joinGroup(code);

    if (mounted) {
      if (group != null) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(group: group)),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = service.errorMessage ?? locale.failedToJoinGroup;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleService>(context);
    return AlertDialog(
      title: Text(locale.joinGroup),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: locale.inviteCode,
              hintText: locale.inviteCodeHint,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(locale.cancel),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(locale.join),
        ),
      ],
    );
  }
}
