import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/plan_service.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  String _currentPlan = 'free';
  ScanAllowance? _allowance;
  bool _loading = true;

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

    final plan = await PlanService().getUserPlan(user.uid);
    final allowance = await PlanService().checkValuationAllowance(user.uid);

    if (mounted) {
      setState(() {
        _currentPlan = plan;
        _allowance = allowance;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Pricing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current plan status
                  if (_allowance != null) _buildCurrentPlanCard(),
                  const SizedBox(height: 20),
                  // Plan comparison
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
                    limitations: const [
                      'No valuations',
                    ],
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
                      'Overage: 90p per additional scan',
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
                      'Overage: 85p per additional scan',
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Scan credit packs
                  const Text('Scan Credit Packs',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Top up your monthly allowance with credit packs.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _buildCreditPack('10 Pack', '£8.99', null)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildCreditPack(
                              '50 Pack', '£44.99', '22% off')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildCreditPack(
                              '100 Pack', '£84.99', '32% off')),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard() {
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
                'Overage pricing active: ${a.overagePricePence}p per scan',
                style: TextStyle(
                    color: Colors.orange[200],
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ] else
            Text(
              'Upgrade to Basic or Trader for vehicle valuations.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
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

  Widget _buildCreditPack(String name, String price, String? discount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(price,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (discount != null) ...[
            const SizedBox(height: 2),
            Text(discount,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}
