import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/saved_scan.dart';
import '../models/car_identification.dart';
import '../models/vehicle_valuation.dart';

class SavedScanService {
  static final SavedScanService _instance = SavedScanService._internal();
  factory SavedScanService() => _instance;
  SavedScanService._internal();

  CollectionReference _scansCollection(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_scans');

  Future<String> saveScan({
    required String uid,
    required CarIdentification identification,
    VehicleValuation? valuation,
  }) async {
    final scan = SavedScan(
      id: '',
      identification: identification,
      valuation: valuation,
      savedAt: DateTime.now(),
    );
    final docRef = await _scansCollection(uid).add(scan.toFirestore());
    return docRef.id;
  }

  Future<void> toggleFavourite(String uid, String scanId, bool value) async {
    await _scansCollection(uid).doc(scanId).update({'is_favourite': value});
  }

  Future<void> deleteScan(String uid, String scanId) async {
    await _scansCollection(uid).doc(scanId).delete();
  }

  Future<void> deleteAllScans(String uid) async {
    final snapshots = await _scansCollection(uid).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<List<SavedScan>> watchScans(String uid) {
    return _scansCollection(uid)
        .orderBy('saved_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SavedScan.fromFirestore(doc)).toList());
  }

  Stream<List<SavedScan>> watchFavourites(String uid) {
    return _scansCollection(uid)
        .where('is_favourite', isEqualTo: true)
        .orderBy('saved_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SavedScan.fromFirestore(doc)).toList());
  }

  /// Remove scans older than the retention period.
  Future<int> purgeExpiredScans(String uid) async {
    final cutoff = DateTime.now().subtract(
      const Duration(days: SavedScan.retentionDays),
    );
    final expired = await _scansCollection(uid)
        .where('saved_at', isLessThan: Timestamp.fromDate(cutoff))
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in expired.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return expired.docs.length;
  }
}
