import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum MessagePriority { normal, high, urgent }

class Message {
  final String id;
  // Legacy fields
  final String userId;
  final String userEmail;
  final String userName;
  // New threading fields (matching web inbox schema)
  final String? fromUid;
  final String? fromName;
  final String? fromEmail;
  final String? toUid;
  final String? toEmail;
  final String? threadId;
  final bool read;
  final bool isAdminMsg;
  final List<String> deletedBy;
  // Content
  final String subject;
  final String body;
  final MessagePriority priority;
  final DateTime createdAt;
  // Legacy admin reply (older messages)
  final String? adminReply;
  final DateTime? repliedAt;
  final String? repliedBy;

  Message({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.fromUid,
    this.fromName,
    this.fromEmail,
    this.toUid,
    this.toEmail,
    this.threadId,
    this.read = false,
    this.isAdminMsg = false,
    this.deletedBy = const [],
    required this.subject,
    required this.body,
    required this.priority,
    required this.createdAt,
    this.adminReply,
    this.repliedAt,
    this.repliedBy,
  });

  bool get hasReply => adminReply != null && adminReply!.isNotEmpty;

  /// The effective thread ID — use threadId if set, otherwise the message id.
  String get effectiveThreadId => threadId ?? id;

  /// Whether this message has been soft-deleted by the given user.
  bool isDeletedBy(String uid) => deletedBy.contains(uid);

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return Message(
      id: doc.id,
      userId: data['user_id'] ?? data['from_uid'] ?? '',
      userEmail: data['user_email'] ?? data['from_email'] ?? '',
      userName: data['user_name'] ?? data['from_name'] ?? '',
      fromUid: data['from_uid'],
      fromName: data['from_name'],
      fromEmail: data['from_email'],
      toUid: data['to_uid'],
      toEmail: data['to_email'],
      threadId: data['thread_id'],
      read: data['read'] as bool? ?? false,
      isAdminMsg: data['is_admin_msg'] as bool? ?? false,
      deletedBy: data['deleted_by'] != null
          ? List<String>.from(data['deleted_by'] as List)
          : [],
      subject: data['subject'] ?? '',
      body: data['body'] ?? '',
      priority: MessagePriority.values.firstWhere(
        (p) => p.name == (data['priority'] ?? 'normal'),
        orElse: () => MessagePriority.normal,
      ),
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adminReply: data['admin_reply'],
      repliedAt: (data['replied_at'] as Timestamp?)?.toDate(),
      repliedBy: data['replied_by'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'user_email': userEmail,
      'user_name': userName,
      'from_uid': fromUid,
      'from_name': fromName,
      'from_email': fromEmail,
      'to_uid': toUid,
      'to_email': toEmail,
      if (threadId != null) 'thread_id': threadId,
      'read': read,
      'is_admin_msg': isAdminMsg,
      'subject': subject,
      'body': body,
      'priority': priority.name,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final CollectionReference _messagesCollection =
      FirebaseFirestore.instance.collection('messages');

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  Future<String> sendMessage({
    required String subject,
    required String body,
    MessagePriority priority = MessagePriority.normal,
    String? threadId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final message = Message(
      id: '',
      userId: user.uid,
      userEmail: user.email ?? '',
      userName: user.displayName ?? '',
      fromUid: user.uid,
      fromName: user.displayName ?? '',
      fromEmail: user.email ?? '',
      toUid: 'admin',
      subject: subject,
      body: body,
      priority: priority,
      createdAt: DateTime.now(),
      threadId: threadId,
    );

    final docRef = await _messagesCollection.add(message.toFirestore());
    return docRef.id;
  }

  /// Watch inbox: messages sent TO this user.
  Stream<List<Message>> watchInbox() {
    final currentUid = uid;
    if (currentUid == null) return Stream.value([]);

    return _messagesCollection
        .where('to_uid', isEqualTo: currentUid)
        .orderBy('created_at', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Message.fromFirestore(d)).toList());
  }

  /// Watch sent: messages sent BY this user.
  Stream<List<Message>> watchSent() {
    final currentUid = uid;
    if (currentUid == null) return Stream.value([]);

    return _messagesCollection
        .where('from_uid', isEqualTo: currentUid)
        .orderBy('created_at', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Message.fromFirestore(d)).toList());
  }

  /// Legacy: watch messages using old user_id field (backward compat).
  Stream<List<Message>> watchLegacy() {
    final currentUid = uid;
    if (currentUid == null) return Stream.value([]);

    return _messagesCollection
        .where('user_id', isEqualTo: currentUid)
        .orderBy('created_at', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Message.fromFirestore(d))
            .where((m) => m.fromUid == null && m.toUid == null)
            .toList());
  }

  /// Kept for backward compatibility.
  Stream<List<Message>> watchMyMessages() => watchInbox();

  /// Mark a message as read.
  Future<void> markRead(String messageId) async {
    await _messagesCollection.doc(messageId).update({'read': true});
  }

  /// Soft-delete (move to bin) or restore a message for this user.
  Future<void> toggleDelete(String messageId, {required bool delete}) async {
    final currentUid = uid;
    if (currentUid == null) return;

    await _messagesCollection.doc(messageId).update({
      'deleted_by': delete
          ? FieldValue.arrayUnion([currentUid])
          : FieldValue.arrayRemove([currentUid]),
    });
  }

  /// Get all messages in a thread.
  Future<List<Message>> getThread(String threadId) async {
    final snap = await _messagesCollection
        .where('thread_id', isEqualTo: threadId)
        .orderBy('created_at', descending: false)
        .get();

    // Also get the original message (which has no thread_id but is the thread root)
    final original = await _messagesCollection.doc(threadId).get();

    final messages =
        snap.docs.map((d) => Message.fromFirestore(d)).toList();

    if (original.exists) {
      final origMsg = Message.fromFirestore(original);
      if (!messages.any((m) => m.id == origMsg.id)) {
        messages.insert(0, origMsg);
      }
    }

    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }
}
