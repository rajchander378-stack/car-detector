import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usage_record.dart';

class ScanAllowance {
  final bool allowed;
  final bool isOverage;
  final bool valuationEnabled;
  final int remainingFree;
  final int monthlyLimit;
  final int overagePricePence;
  final String plan;

  ScanAllowance({
    required this.allowed,
    required this.isOverage,
    required this.valuationEnabled,
    required this.remainingFree,
    required this.monthlyLimit,
    required this.overagePricePence,
    required this.plan,
  });

  String get overagePriceFormatted =>
      '\u00a3${(overagePricePence / 100).toStringAsFixed(2)}';
}

class PlanConfig {
  final int monthlyScans;
  final int overagePricePence;
  final int pricePence;

  PlanConfig({
    required this.monthlyScans,
    required this.overagePricePence,
    required this.pricePence,
  });

  factory PlanConfig.fromMap(Map<String, dynamic> data) {
    return PlanConfig(
      monthlyScans: data['monthly_scans'] ?? 5,
      overagePricePence: data['overage_price_pence'] ?? 30,
      pricePence: data['price_pence'] ?? 0,
    );
  }

  static PlanConfig freeDefault() =>
      PlanConfig(monthlyScans: 5, overagePricePence: 0, pricePence: 0);

  static PlanConfig basicDefault() =>
      PlanConfig(monthlyScans: 10, overagePricePence: 90, pricePence: 999);

  static PlanConfig traderDefault() =>
      PlanConfig(monthlyScans: 75, overagePricePence: 85, pricePence: 5999);
}

class PlanService {
  static final PlanService _instance = PlanService._internal();
  factory PlanService() => _instance;
  PlanService._internal();

  final _firestore = FirebaseFirestore.instance;

  Map<String, PlanConfig>? _cachedConfigs;

  void clearCache() => _cachedConfigs = null;

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  DocumentReference _usageDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('usage').doc(_currentMonthKey());

  Future<Map<String, PlanConfig>> _getPlanConfigs() async {
    if (_cachedConfigs != null) return _cachedConfigs!;

    try {
      final doc = await _firestore.collection('config').doc('plans').get();
      if (doc.exists) {
        final data = doc.data()!;
        _cachedConfigs = {};
        if (data['free'] != null) {
          _cachedConfigs!['free'] = PlanConfig.fromMap(Map<String, dynamic>.from(data['free'] as Map));
        }
        if (data['basic'] != null) {
          _cachedConfigs!['basic'] = PlanConfig.fromMap(Map<String, dynamic>.from(data['basic'] as Map));
        }
        if (data['trader'] != null) {
          _cachedConfigs!['trader'] = PlanConfig.fromMap(Map<String, dynamic>.from(data['trader'] as Map));
        }
        return _cachedConfigs!;
      }
    } catch (_) {}

    // Fallback defaults
    _cachedConfigs = {
      'free': PlanConfig.freeDefault(),
      'basic': PlanConfig.basicDefault(),
      'trader': PlanConfig.traderDefault(),
    };
    return _cachedConfigs!;
  }

  Future<PlanConfig> getPlanConfig(String planName) async {
    final configs = await _getPlanConfigs();
    return configs[planName] ?? PlanConfig.freeDefault();
  }

  Future<UsageRecord> getCurrentUsage(String uid) async {
    final doc = await _usageDoc(uid).get();
    if (doc.exists) return UsageRecord.fromFirestore(doc);
    return UsageRecord.empty(_currentMonthKey());
  }

  Future<String> getUserPlan(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return 'free';
    final data = doc.data()!;
    return data['plan'] ?? 'free';
  }

  Future<ScanAllowance> checkValuationAllowance(String uid) async {
    final plan = await getUserPlan(uid);
    final config = await getPlanConfig(plan);
    final usage = await getCurrentUsage(uid);

    // Free plan users cannot use valuations at all
    final valuationEnabled = plan != 'free';
    final remaining = config.monthlyScans - usage.valuationScans;

    return ScanAllowance(
      allowed: valuationEnabled,
      isOverage: valuationEnabled && remaining <= 0,
      valuationEnabled: valuationEnabled,
      remainingFree: remaining > 0 ? remaining : 0,
      monthlyLimit: config.monthlyScans,
      overagePricePence: config.overagePricePence,
      plan: plan,
    );
  }

  Future<void> recordValuationScan(String uid) async {
    final plan = await getUserPlan(uid);
    final config = await getPlanConfig(plan);
    final usage = await getCurrentUsage(uid);

    final isOverage = usage.valuationScans >= config.monthlyScans;

    final updates = <String, dynamic>{
      'valuation_scans': FieldValue.increment(1),
      'last_scan_at': FieldValue.serverTimestamp(),
    };
    if (isOverage) {
      updates['overage_scans'] = FieldValue.increment(1);
    }

    await _usageDoc(uid).set(updates, SetOptions(merge: true));
  }

  Future<void> recordAiOnlyScan(String uid) async {
    await _usageDoc(uid).set({
      'ai_only_scans': FieldValue.increment(1),
      'last_scan_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteUsageData(String uid) async {
    final snapshots = await _firestore
        .collection('users')
        .doc(uid)
        .collection('usage')
        .get();
    final batch = _firestore.batch();
    for (final doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
