import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Legal'),
      ),
      body: ListView(
        children: [
          _LegalTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we collect and use your data',
            onTap: () => _openUrl(
              context,
              'https://juxeboxd.web.app/privacy-policy.html',
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          _LegalTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Rules and guidelines for using CrateBoxd',
            onTap: () => _openUrl(
              context,
              'https://YOUR_TERMS_OF_SERVICE_URL_HERE',
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'CrateBoxd © 2026\nAll rights reserved.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LegalTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}
