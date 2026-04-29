import 'package:flutter/material.dart';
import '../services/message_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.openCompose = false});

  final bool openCompose;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final MessageService _messageService = MessageService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.openCompose) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showComposeSheet());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Inbox'),
            Tab(text: 'Sent'),
            Tab(text: 'Bin'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeSheet,
        child: const Icon(Icons.edit),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InboxTab(service: _messageService, onOpenThread: _openThread),
          _SentTab(service: _messageService, onOpenThread: _openThread),
          _BinTab(service: _messageService),
        ],
      ),
    );
  }

  void _openThread(Message message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ThreadScreen(
          threadId: message.effectiveThreadId,
          subject: message.subject,
          service: _messageService,
        ),
      ),
    );
  }

  Future<void> _showComposeSheet({String? threadId, String? prefillSubject}) async {
    final subjectCtl = TextEditingController(text: prefillSubject ?? '');
    final bodyCtl = TextEditingController();
    MessagePriority priority = MessagePriority.normal;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      threadId != null ? 'Reply' : 'New Message',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (threadId == null)
                      TextField(
                        controller: subjectCtl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    if (threadId == null) const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 5,
                      autofocus: threadId != null,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Priority',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SegmentedButton<MessagePriority>(
                      segments: const [
                        ButtonSegment(
                            value: MessagePriority.normal,
                            label: Text('Normal')),
                        ButtonSegment(
                            value: MessagePriority.high,
                            label: Text('High')),
                        ButtonSegment(
                            value: MessagePriority.urgent,
                            label: Text('Urgent')),
                      ],
                      selected: {priority},
                      onSelectionChanged: (selected) {
                        setSheetState(() => priority = selected.first);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final subject = threadId != null
                                  ? (prefillSubject ?? 'Re:')
                                  : subjectCtl.text.trim();
                              if (subject.isEmpty ||
                                  bodyCtl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please fill in all fields')),
                                );
                                return;
                              }
                              try {
                                await _messageService.sendMessage(
                                  subject: subject,
                                  body: bodyCtl.text.trim(),
                                  priority: priority,
                                  threadId: threadId,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Failed to send. Please try again.')),
                                  );
                                }
                              }
                            },
                            child: const Text('Send'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      subjectCtl.dispose();
      bodyCtl.dispose();
    });

    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent')),
      );
    }
  }
}

// ──────────────────── Inbox Tab ────────────────────

class _InboxTab extends StatelessWidget {
  final MessageService service;
  final void Function(Message) onOpenThread;

  const _InboxTab({required this.service, required this.onOpenThread});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Message>>(
      stream: service.watchInbox(),
      builder: (context, inboxSnap) {
        return StreamBuilder<List<Message>>(
          stream: service.watchLegacy(),
          builder: (context, legacySnap) {
            if (inboxSnap.connectionState == ConnectionState.waiting &&
                legacySnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final inbox = inboxSnap.data ?? [];
            final legacy = legacySnap.data ?? [];
            final uid = service.uid ?? '';

            // Merge and deduplicate, filter out deleted
            final seen = <String>{};
            final all = <Message>[];
            for (final m in [...inbox, ...legacy]) {
              if (seen.contains(m.id) || m.isDeletedBy(uid)) continue;
              seen.add(m.id);
              all.add(m);
            }
            all.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            // Group by thread — show latest message per thread
            final threadLatest = _groupByThread(all);

            if (threadLatest.isEmpty) {
              return _emptyState('No messages in your inbox');
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: threadLatest.length,
              itemBuilder: (_, i) => _MessageCard(
                message: threadLatest[i],
                onTap: () => onOpenThread(threadLatest[i]),
                onDismissed: () =>
                    service.toggleDelete(threadLatest[i].id, delete: true),
              ),
            );
          },
        );
      },
    );
  }
}

// ──────────────────── Sent Tab ────────────────────

class _SentTab extends StatelessWidget {
  final MessageService service;
  final void Function(Message) onOpenThread;

  const _SentTab({required this.service, required this.onOpenThread});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Message>>(
      stream: service.watchSent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final uid = service.uid ?? '';
        final messages = (snapshot.data ?? [])
            .where((m) => !m.isDeletedBy(uid))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (messages.isEmpty) return _emptyState('No sent messages');

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (_, i) => _MessageCard(
            message: messages[i],
            showRecipient: true,
            onTap: () => onOpenThread(messages[i]),
          ),
        );
      },
    );
  }
}

// ──────────────────── Bin Tab ────────────────────

class _BinTab extends StatelessWidget {
  final MessageService service;

  const _BinTab({required this.service});

  @override
  Widget build(BuildContext context) {
    // We need to check both inbox and sent for deleted messages
    return StreamBuilder<List<Message>>(
      stream: service.watchInbox(),
      builder: (context, inboxSnap) {
        return StreamBuilder<List<Message>>(
          stream: service.watchSent(),
          builder: (context, sentSnap) {
            if (inboxSnap.connectionState == ConnectionState.waiting &&
                sentSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final uid = service.uid ?? '';
            final seen = <String>{};
            final deleted = <Message>[];

            for (final m in [...(inboxSnap.data ?? []), ...(sentSnap.data ?? [])]) {
              if (seen.contains(m.id)) continue;
              seen.add(m.id);
              if (m.isDeletedBy(uid)) deleted.add(m);
            }
            deleted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (deleted.isEmpty) return _emptyState('Bin is empty');

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: deleted.length,
              itemBuilder: (_, i) => _MessageCard(
                message: deleted[i],
                onDismissed: () =>
                    service.toggleDelete(deleted[i].id, delete: false),
                dismissLabel: 'Restore',
                dismissIcon: Icons.restore_from_trash,
              ),
            );
          },
        );
      },
    );
  }
}

// ──────────────────── Thread Screen ────────────────────

class _ThreadScreen extends StatefulWidget {
  final String threadId;
  final String subject;
  final MessageService service;

  const _ThreadScreen({
    required this.threadId,
    required this.subject,
    required this.service,
  });

  @override
  State<_ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<_ThreadScreen> {
  List<Message>? _messages;
  bool _loading = true;
  final _replyCtl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  @override
  void dispose() {
    _replyCtl.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    final messages = await widget.service.getThread(widget.threadId);

    // Mark unread messages as read
    final uid = widget.service.uid;
    for (final m in messages) {
      if (m.toUid == uid && !m.read) {
        widget.service.markRead(m.id);
      }
    }

    if (mounted) setState(() { _messages = messages; _loading = false; });
  }

  Future<void> _sendReply() async {
    if (_replyCtl.text.trim().isEmpty) return;

    setState(() => _sending = true);
    try {
      await widget.service.sendMessage(
        subject: 'Re: ${widget.subject}',
        body: _replyCtl.text.trim(),
        threadId: widget.threadId,
      );
      _replyCtl.clear();
      await _loadThread();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reply')),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages == null || _messages!.isEmpty
                      ? const Center(child: Text('No messages in thread'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages!.length,
                          itemBuilder: (_, i) =>
                              _ThreadBubble(message: _messages![i]),
                        ),
                ),
                // Reply bar
                Container(
                  padding: EdgeInsets.fromLTRB(
                      12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyCtl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Type a reply...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendReply(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _sendReply,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ThreadBubble extends StatelessWidget {
  final Message message;

  const _ThreadBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.isAdminMsg ||
        (message.adminReply != null && message.fromUid == null);
    final theme = Theme.of(context);

    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isAdmin
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'AutoSpotter Support' : (message.fromName ?? 'You'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(message.body, style: const TextStyle(fontSize: 14)),
            // Show legacy admin reply inline
            if (message.hasReply && message.adminReply != null) ...[
              const Divider(height: 16),
              Text(
                'Admin reply:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 2),
              Text(message.adminReply!, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$d/$mo/${date.year} $h:$m';
  }
}

// ──────────────────── Shared Widgets ────────────────────

class _MessageCard extends StatelessWidget {
  final Message message;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;
  final bool showRecipient;
  final String dismissLabel;
  final IconData dismissIcon;

  const _MessageCard({
    required this.message,
    this.onTap,
    this.onDismissed,
    this.showRecipient = false,
    this.dismissLabel = 'Delete',
    this.dismissIcon = Icons.delete_outline,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (message.priority) {
      MessagePriority.urgent => Colors.red,
      MessagePriority.high => Colors.orange,
      MessagePriority.normal => Colors.grey,
    };

    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Unread dot
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: message.read ? Colors.transparent : Colors.blue,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.subject,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: message.read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (message.priority != MessagePriority.normal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message.priority.name,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: priorityColor),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message.body,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (showRecipient && message.toUid == 'admin')
                          Text('To: Support  ',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        Text(
                          _formatDate(message.createdAt),
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        if (message.hasReply) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.reply, size: 14, color: Colors.blue[400]),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );

    if (onDismissed != null) {
      return Dismissible(
        key: Key(message.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: dismissLabel == 'Restore' ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(dismissIcon, color: Colors.white),
        ),
        onDismissed: (_) => onDismissed!(),
        child: card,
      );
    }

    return card;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Group messages by thread and return the latest message per thread.
List<Message> _groupByThread(List<Message> messages) {
  final threadMap = <String, Message>{};
  for (final m in messages) {
    final tid = m.effectiveThreadId;
    if (!threadMap.containsKey(tid) ||
        m.createdAt.isAfter(threadMap[tid]!.createdAt)) {
      threadMap[tid] = m;
    }
  }
  final result = threadMap.values.toList();
  result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return result;
}

Widget _emptyState(String text) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.message_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(text,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500])),
      ],
    ),
  );
}
