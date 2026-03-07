import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsScreen extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const TermsScreen({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before using AutoSpotter, please review and accept the following:',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    _buildBullet(
                      icon: Icons.smart_toy_outlined,
                      title: 'AI Identification',
                      body:
                          'Vehicle identifications are AI-generated best-effort estimates and are not guaranteed to be accurate. Always verify independently.',
                    ),
                    _buildBullet(
                      icon: Icons.attach_money,
                      title: 'Price Estimates',
                      body:
                          'Valuations are indicative only, sourced from third-party data. They do not constitute a formal appraisal.',
                    ),
                    _buildBullet(
                      icon: Icons.no_photography_outlined,
                      title: 'Number Plates',
                      body:
                          'Plate images are processed transiently via cloud AI and are not stored on our servers.',
                    ),
                    _buildBullet(
                      icon: Icons.account_circle_outlined,
                      title: 'Account Data',
                      body:
                          'Your Google profile info is stored via Firebase to provide the service. You may request deletion at any time.',
                    ),
                    _buildBullet(
                      icon: Icons.flag_outlined,
                      title: 'UK Vehicles Only',
                      body:
                          'This app is designed for UK-registered vehicles. Number plate recognition, vehicle identification, and price valuations are based on UK data sources. Results for non-UK vehicles may be inaccurate or unavailable.',
                    ),
                    _buildBullet(
                      icon: Icons.gavel_outlined,
                      title: 'Acceptable Use',
                      body:
                          'Do not use the app for illegal activity, stalking, surveillance, or vehicle-related fraud.',
                    ),
                    _buildBullet(
                      icon: Icons.balance_outlined,
                      title: 'Governing Law',
                      body:
                          'These terms are governed by the laws of England & Wales.',
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('https://car-detector-833e5.web.app/privacy-policy.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        'View our full Privacy Policy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: onAccept,
                    child: const Text('I Agree'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBullet({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
