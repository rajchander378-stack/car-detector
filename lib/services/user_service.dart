import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import 'plan_service.dart';
import 'saved_scan_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  Future<AppUser> createOrUpdateUser(User firebaseUser) async {
    final docRef = _usersCollection.doc(firebaseUser.uid);
    final doc = await docRef.get();
    final now = DateTime.now();

    if (doc.exists) {
      // Existing user — update last login and refresh profile fields
      await docRef.update({
        'display_name': firebaseUser.displayName ?? '',
        'email': firebaseUser.email ?? '',
        'photo_url': firebaseUser.photoURL,
        'last_login_at': Timestamp.fromDate(now),
      });
    } else {
      // New user — create document
      final appUser = AppUser(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        createdAt: now,
        lastLoginAt: now,
      );
      await docRef.set(appUser.toJson());
    }

    final updatedDoc = await docRef.get();
    return AppUser.fromJson(updatedDoc.data()! as Map<String, dynamic>);
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(doc.data()! as Map<String, dynamic>);
  }

  Future<void> deleteUserData(String uid) async {
    final firestore = FirebaseFirestore.instance;

    // Delete AI reports submitted by this user
    final reports = await firestore
        .collection('ai_reports')
        .where('user_id', isEqualTo: uid)
        .get();
    for (final doc in reports.docs) {
      await doc.reference.delete();
    }

    // Delete saved scans
    await SavedScanService().deleteAllScans(uid);

    // Delete usage records
    await PlanService().deleteUsageData(uid);

    // Delete the user document
    await _usersCollection.doc(uid).delete();
  }
}
