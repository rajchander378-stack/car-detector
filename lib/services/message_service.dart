import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum MessagePriority { normal, high, urgent }

class Message {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String subject;
  final String body;
  final MessagePriority priority;
  final DateTime createdAt;
  final String? adminReply;
  final DateTime? repliedAt;
  final String? repliedBy;

  Message({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.subject,
    required this.body,
    required this.priority,
    required this.createdAt,
    this.adminReply,
    this.repliedAt,
    this.repliedBy,
  });

  bool get hasReply => adminReply != null && adminReply!.isNotEmpty;

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return Message(
      id: doc.id,
      userId: data['user_id'] ?? '',
      userEmail: data['user_email'] ?? '',
      userName: data['user_name'] ?? '',
      subject: data['subject'] ?? '',
      body: data['body'] ?? '',
      priority: MessagePriority.values.firstWhere(
        (p) => p.name == (data['priority'] ?? 'normal'),
        orElse: () => MessagePriority.normal,
      ),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'subject': subject,
      'body': body,
      'priority': priority.name,
      'created_at': FieldValue.serverTimestamp(),
      'admin_reply': null,
      'replied_at': null,
      'replied_by': null,
    };
  }
}

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final CollectionReference _messagesCollection =
      FirebaseFirestore.instance.collection('messages');

  Future<String> sendMessage({
    required String subject,
    required String body,
    MessagePriority priority = MessagePriority.normal,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final message = Message(
      id: '',
      userId: user.uid,
      userEmail: user.email ?? '',
      userName: user.displayName ?? '',
      subject: subject,
      body: body,
      priority: priority,
      createdAt: DateTime.now(),
    );

    final docRef = await _messagesCollection.add(message.toFirestore());
    return docRef.id;
  }

  Stream<List<Message>> watchMyMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _messagesCollection
        .where('user_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }
}
