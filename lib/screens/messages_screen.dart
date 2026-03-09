import 'package:flutter/material.dart';
import '../services/message_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final MessageService _messageService = MessageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeDialog,
        child: const Icon(Icons.edit),
      ),
      body: StreamBuilder<List<Message>>(
        stream: _messageService.watchMyMessages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.message_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'No messages yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the compose button to send a message to the admin team.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) =>
                _MessageCard(message: messages[index]),
          );
        },
      ),
    );
  }

  Future<void> _showComposeDialog() async {
    final subjectCtl = TextEditingController();
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
                    const Text('New Message',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: subjectCtl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 5,
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
                          label: Text('Normal'),
                        ),
                        ButtonSegment(
                          value: MessagePriority.high,
                          label: Text('High'),
                        ),
                        ButtonSegment(
                          value: MessagePriority.urgent,
                          label: Text('Urgent'),
                        ),
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
                              if (subjectCtl.text.trim().isEmpty ||
                                  bodyCtl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please fill in both subject and message')),
                                );
                                return;
                              }
                              try {
                                await _messageService.sendMessage(
                                  subject: subjectCtl.text.trim(),
                                  body: bodyCtl.text.trim(),
                                  priority: priority,
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

    subjectCtl.dispose();
    bodyCtl.dispose();

    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent')),
      );
    }
  }
}

class _MessageCard extends StatelessWidget {
  final Message message;

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = switch (message.priority) {
      MessagePriority.urgent => Colors.red,
      MessagePriority.high => Colors.orange,
      MessagePriority.normal => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.subject,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    message.priority.name,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: priorityColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.body,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(message.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (message.hasReply) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.reply, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Admin reply',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message.adminReply!,
                style: const TextStyle(fontSize: 14),
              ),
              if (message.repliedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatDate(message.repliedAt!),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Awaiting reply...',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[400]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$min';
  }
}
