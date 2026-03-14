import 'package:cloud_firestore/cloud_firestore.dart';

class UsageRecord {
  final String monthKey;
  final int valuationScans;
  final int overageScans;
  final int aiOnlyScans;
  final DateTime? lastScanAt;

  UsageRecord({
    required this.monthKey,
    this.valuationScans = 0,
    this.overageScans = 0,
    this.aiOnlyScans = 0,
    this.lastScanAt,
  });

  int get totalScans => valuationScans + aiOnlyScans;

  factory UsageRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UsageRecord(
      monthKey: doc.id,
      valuationScans: data['valuation_scans'] ?? 0,
      overageScans: data['overage_scans'] ?? 0,
      aiOnlyScans: data['ai_only_scans'] ?? 0,
      lastScanAt: data['last_scan_at'] != null
          ? (data['last_scan_at'] as Timestamp).toDate()
          : null,
    );
  }

  factory UsageRecord.empty(String monthKey) {
    return UsageRecord(monthKey: monthKey);
  }
}
