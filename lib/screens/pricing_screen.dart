import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/plan_service.dart';

const _apiUrl = 'https://car-detector-api-109977431110.europe-west2.run.app';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  String _currentPlan = 'free';
  ScanAllowance? _allowance;
  bool _loading = true;
  bool _isAdmin = false;
  String? _buyingPackId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([
      PlanService().getUserPlan(user.uid),
      PlanService().checkValuationAllowance(user.uid),
      _checkIsAdmin(user.email),
    ]);

    if (mounted) {
      setState(() {
        _currentPlan = results[0] as String;
        _allowance = results[1] as ScanAllowance;
        _isAdmin = results[2] as bool;
        _loading = false;
      });
    }
  }

  Future<bool> _checkIsAdmin(String? email) async {
    if (email == null) return false;
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('admin').get();
      final emails = List<String>.from(doc.data()?['admin_emails'] ?? []);
      return emails.map((e) => e.toLowerCase()).contains(email.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  Future<void> _buyPack(String packId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _buyingPackId = packId);
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/create-checkout-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pack_id': packId,
          'user_uid': user.uid,
          'user_email': user.email ?? '',
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] as String? ?? 'Purchase not available for this account.')),
          );
        }
        return;
      }

      if (response.statusCode != 200 || data['checkout_url'] == null) {
        throw Exception(data['error'] ?? 'Failed to create checkout session');
      }

      final url = Uri.parse(data['checkout_url'] as String);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open checkout');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start checkout: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _buyingPackId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Pricing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current plan status with live credit balance
                  if (_allowance != null && user != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final credits = (snapshot.data?.data() as Map<String, dynamic>?)?['scan_credits'] as int? ?? 0;
                        return _buildCurrentPlanCard(credits: credits);
                      },
                    ),
                  const SizedBox(height: 20),

                  // Plan comparison cards
                  _buildPlanCard(
                    name: 'Free',
                    price: '£0',
                    period: '/month',
                    isCurrent: _currentPlan == 'free',
                    color: Colors.grey,
                    features: const [
                      '5 vehicle scans per month',
                      'Automatic number plate recognition',
                      'Basic vehicle details',
                      'Save scan history',
                    ],
                    limitations: const ['No valuations'],
                  ),
                  const SizedBox(height: 12),
                  _buildPlanCard(
                    name: 'Basic',
                    price: '£9.99',
                    period: '/month',
                    isCurrent: _currentPlan == 'basic',
                    isPopular: true,
                    color: Colors.blue,
                    features: const [
                      '10 vehicle valuations per month',
                      'Unlimited number plate scanning',
                      'Full vehicle details',
                      'Save scan history',
                      'Top up with scan credit packs',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPlanCard(
                    name: 'Trader',
                    price: '£59.99',
                    period: '/month',
                    isCurrent: _currentPlan == 'trader',
                    color: Colors.amber[800]!,
                    features: const [
                      '75 full vehicle reports per month',
                      'Unlimited number plate scanning',
                      'MOT history, specs & tyre data',
                      'CSV, Excel & PDF export',
                      'Bulk upload (100+ images)',
                      'Smart charging & freshness analysis',
                      'Priority support',
                      'Top up with scan credit packs',
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Scan credit packs
                  const Text('Scan Credit Packs',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Top up your scan allowance — credits never expire.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildCreditPack('pack_10', '10 Scans', '£8.99', null)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildCreditPack('pack_50', '50 Scans', '£44.99', '22% off')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildCreditPack('pack_100', '100 Scans', '£84.99', '32% off')),
                    ],
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Purchases are disabled for admin accounts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard({required int credits}) {
    final a = _allowance!;
    final usagePercent = a.monthlyLimit > 0
        ? (a.monthlyLimit - a.remainingFree) / a.monthlyLimit
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Plan: ${_currentPlan[0].toUpperCase()}${_currentPlan.substring(1)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (credits > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$credits credits',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (a.valuationEnabled) ...[
            Text(
              '${a.remainingFree} of ${a.monthlyLimit} scans remaining this month',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usagePercent.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(
                    usagePercent > 1.0 ? Colors.orange : Colors.white),
              ),
            ),
            if (a.isOverage) ...[
              const SizedBox(height: 6),
              Text(
                'Monthly allowance used — ${a.availableCredits} credit${a.availableCredits == 1 ? '' : 's'} remaining',
                style: TextStyle(
                    color: a.availableCredits > 0 ? Colors.orange[200] : Colors.red[200],
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ] else
            Text(
              'Upgrade to Basic or Trader for vehicle valuations.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String name,
    required String price,
    required String period,
    required bool isCurrent,
    required Color color,
    required List<String> features,
    List<String> limitations = const [],
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? color : Colors.grey[300]!,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: const Text(
                'Most Popular',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const Spacer(),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Current',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price,
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(period,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600])),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(f,
                                  style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    )),
                ...limitations.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.cancel, size: 18, color: Colors.red[300]),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(l,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500]))),
                        ],
                      ),
                    )),
                if (!isCurrent) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Plan changes are managed via the web dashboard.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: color),
                      child: Text(name == 'Free' ? 'Downgrade' : 'Upgrade'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditPack(
      String packId, String name, String price, String? discount) {
    final isLoading = _buyingPackId == packId;
    final anyLoading = _buyingPackId != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLoading ? Colors.blue : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(price,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (discount != null) ...[
            const SizedBox(height: 2),
            Text(discount,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_isAdmin || anyLoading) ? null : () => _buyPack(packId),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Buy'),
            ),
          ),
        ],
      ),
    );
  }
}
