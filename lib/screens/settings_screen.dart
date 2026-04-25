import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/usage_record.dart';
import '../services/auth_service.dart';
import '../services/plan_service.dart';
import '../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appShareUrl = 'https://car-detector-833e5.web.app/';
  static const String _androidPackageName =
      'com.axiomforgesoftware.autospotter';
  static const String _playStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$_androidPackageName';
  String _version = '';
  String _plan = 'basic';
  UsageRecord? _usage;
  PlanConfig? _planConfig;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadPlanInfo();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  Future<void> _loadPlanInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final planService = PlanService();
    final allowance = await planService.checkValuationAllowance(user.uid);
    final usage = await planService.getCurrentUsage(user.uid);
    final appUser = await UserService().getUser(user.uid);

    if (mounted) {
      setState(() {
        _plan = appUser?.plan ?? 'basic';
        _usage = usage;
        _planConfig = PlanConfig(
          monthlyScans: allowance.monthlyLimit,
          overagePricePence: allowance.overagePricePence,
          pricePence: 0,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // User info
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? const Icon(Icons.person, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? 'User',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          user.email ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(),

          // Plan & Usage
          ListTile(
            leading: Icon(
              _plan == 'trader' ? Icons.diamond
                  : _plan == 'basic' ? Icons.workspace_premium
                  : Icons.person,
              color: _plan == 'trader' ? Colors.amber[700]
                  : _plan == 'basic' ? Colors.blue : null,
            ),
            title: Text(
              _plan == 'trader' ? 'Trader Plan'
                  : _plan == 'basic' ? 'Basic Plan'
                  : 'Free Plan',
            ),
            subtitle: _usage != null && _planConfig != null
                ? Text(_plan == 'free'
                    ? '${_usage!.aiOnlyScans} AI scans this month (no valuations)'
                    : '${_usage!.valuationScans} of ${_planConfig!.monthlyScans} '
                      'valuation scans used this month')
                : const Text('Loading usage...'),
            trailing: _plan != 'trader'
                ? TextButton(
                    onPressed: () => _showUpgradeSheet(context),
                    child: const Text('Upgrade'),
                  )
                : null,
            onTap: () => _showPlanDetails(context),
          ),
          if (_usage != null && _planConfig != null && _plan != 'free')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_usage!.valuationScans / _planConfig!.monthlyScans)
                      .clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: _usage!.valuationScans >= _planConfig!.monthlyScans
                      ? Colors.orange
                      : theme.colorScheme.primary,
                  minHeight: 6,
                ),
              ),
            ),
          if (_usage != null && _usage!.overageScans > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                '${_usage!.overageScans} overage scan${_usage!.overageScans == 1 ? '' : 's'} this month',
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          const SizedBox(height: 8),

          const Divider(),

          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About AutoSpotter'),
            subtitle: Text(
              _version.isNotEmpty
                  ? 'Version $_version'
                  : 'AI car identification for UK vehicles',
            ),
            onTap: () => _showAbout(context),
          ),

          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Tell a friend'),
            subtitle: const Text('Share AutoSpotter with someone else'),
            onTap: _shareApp,
          ),

          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate AutoSpotter'),
            subtitle: const Text('Leave a review on Google Play'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: _openStoreListing,
          ),

          // Privacy policy
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl('https://car-detector-833e5.web.app/privacy-policy.html'),
          ),

          // Terms
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms & Conditions'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl('https://car-detector-833e5.web.app/'),
          ),

          const Divider(),

          // Sign out
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => _confirmSignOut(context),
          ),

          // Delete account
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red[400]),
            title: Text('Delete account',
                style: TextStyle(color: Colors.red[400])),
            subtitle: const Text('Permanently delete your account and all data'),
            onTap: () => _confirmDeleteAccount(context),
          ),

          // Debug plan switcher — only in debug builds
          if (kDebugMode && user != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'DEBUG: Plan Switcher',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[400],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'free', label: Text('Free')),
                  ButtonSegment(value: 'basic', label: Text('Basic')),
                  ButtonSegment(value: 'trader', label: Text('Trader')),
                ],
                selected: {_plan},
                onSelectionChanged: (selection) =>
                    _switchPlan(user.uid, selection.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Switches your plan instantly. No payment required.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
          ],

          // Version footer
          if (_version.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'AutoSpotter v$_version\n\u00a9 2026 Axiom Forge Software',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _switchPlan(String uid, String newPlan) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'plan': newPlan}, SetOptions(merge: true));
    // Clear cached plan configs so they reload
    PlanService().clearCache();
    setState(() => _plan = newPlan);
    await _loadPlanInfo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${newPlan.toUpperCase()} plan')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
        'I just identified a car with AutoSpotter. Try it here: $_appShareUrl',
        subject: 'Try AutoSpotter',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the share sheet. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openStoreListing() async {
    final storeUri = Uri.parse('market://details?id=$_androidPackageName');
    final webUri = Uri.parse(_playStoreWebUrl);

    try {
      if (await canLaunchUrl(storeUri)) {
        await launchUrl(storeUri, mode: LaunchMode.externalApplication);
        return;
      }

      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // Fall through to user-facing error below.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the Google Play listing right now.'),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AutoSpotter',
      applicationVersion: _version,
      applicationLegalese: '\u00a9 2026 Axiom Forge Software',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Instant AI car identification and UK vehicle valuation. '
          'Designed for UK-registered vehicles.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Contact: privacy@axiomforgesoftware.com',
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  void _showPlanDetails(BuildContext context) {
    final planLabel = _plan == 'trader' ? 'Trader Plan'
        : _plan == 'basic' ? 'Basic Plan'
        : 'Free Plan';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              planLabel,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_plan == 'free') ...[
              _planDetailRow('AI identification scans', '5/month'),
              _planDetailRow('Price valuations', 'Not included'),
              _planDetailRow('AI identification', 'Unlimited'),
            ] else ...[
              _planDetailRow('Monthly valuation scans',
                  '${_planConfig?.monthlyScans ?? "-"} included'),
              _planDetailRow('Overage cost',
                  '\u00a3${((_planConfig?.overagePricePence ?? 0) / 100).toStringAsFixed(2)} per scan'),
              _planDetailRow('AI identification', 'Unlimited'),
            ],
            if (_plan == 'trader') ...[
              _planDetailRow('Priority support', 'Included'),
              _planDetailRow('Export to CSV/Excel', 'Included'),
            ],
            const SizedBox(height: 16),
            if (_usage != null) ...[
              const Text('This Month',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _planDetailRow('Valuation scans', '${_usage!.valuationScans}'),
              _planDetailRow('AI-only scans', '${_usage!.aiOnlyScans}'),
              if (_usage!.overageScans > 0)
                _planDetailRow('Overage scans', '${_usage!.overageScans}'),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _planDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showUpgradeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upgrade Your Plan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Basic plan
            if (_plan == 'free') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.workspace_premium, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text('Basic', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('\u00a35/mo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _planDetailRow('Valuation scans', '10/month'),
                    _planDetailRow('Overage cost', '\u00a30.40 per scan'),
                    _planDetailRow('AI identification', 'Unlimited'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Trader plan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber[600]!, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.diamond, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      const Text('Trader', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('\u00a314.99/mo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber[700])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _planDetailRow('Valuation scans', '75/month'),
                  _planDetailRow('Overage cost', '\u00a30.30 per scan'),
                  _planDetailRow('Priority support', 'Included'),
                  _planDetailRow('Export to CSV/Excel', 'Included'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payments coming soon. Contact us to upgrade.'),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: Colors.amber[700],
                ),
                child: const Text('Contact Us to Upgrade'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Contact: privacy@axiomforgesoftware.com',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await AuthService().signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber, size: 40, color: Colors.red[400]),
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data '
          'including your profile, scan history, and reports.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Delete Firestore data first
      await UserService().deleteUserData(user.uid);

      // Clear local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Delete the Firebase Auth account
      await user.delete();

      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'For security, please sign out and sign back in, '
              'then try deleting your account again.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete account right now. Please try again later.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete account right now. Please try again later.'),
          ),
        );
      }
    }
  }
}
