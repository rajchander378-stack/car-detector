import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LockoutService {
  static final LockoutService _instance = LockoutService._internal();
  factory LockoutService() => _instance;
  LockoutService._internal();

  final CollectionReference _lockoutCollection =
      FirebaseFirestore.instance.collection('lockout_events');

  Future<void> logLockout({
    required List<String> failureErrors,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    await _lockoutCollection.add({
      'user_id': user?.uid,
      'user_email': user?.email,
      'timestamp': FieldValue.serverTimestamp(),
      'device_info': _getDeviceInfo(),
      'failure_errors': failureErrors,
      'resolved': false,
      'resolved_by': null,
      'resolved_at': null,
    });
  }

  Map<String, String> _getDeviceInfo() {
    try {
      return {
        'os': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
      };
    } catch (_) {
      return {'os': 'unknown'};
    }
  }
}
