import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/main.dart';
import 'package:flutter_test_project/services/account_deletion_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _confirmController = TextEditingController();
  bool _isDeleting = false;
  bool get _confirmEnabled => _confirmController.text.trim() == 'DELETE';

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (!_confirmEnabled) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Final confirmation',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete your account and all associated data. '
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Forever',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await AccountDeletionService().deleteAccount();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MyApp()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);

      // Firebase requires recent sign-in before deleting the account.
      if (e.code == 'requires-recent-login') {
        _showReauthPrompt();
      } else {
        _showError('Delete failed: ${e.message}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _showError('Delete failed. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showReauthPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Re-authentication required',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'For security, please sign out and sign back in before deleting your account.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Delete Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning icon + header
            const Center(
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 64),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Delete your account?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            // What gets deleted
            _SectionLabel('This will permanently delete:'),
            const SizedBox(height: 12),
            ..._deletionItems.map((item) => _BulletItem(item)),
            const SizedBox(height: 32),

            // Type to confirm
            const Text(
              'Type DELETE to confirm',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              enabled: !_isDeleting,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Delete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_confirmEnabled && !_isDeleting) ? _handleDelete : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.red.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isDeleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Delete My Account',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _deletionItems = [
    'Your profile and account credentials',
    'All your music reviews and ratings',
    'Your music preferences and taste profile',
    'Your playlists and playlist likes',
    'Your friends and followers',
    'Your notifications and activity history',
    'All AI recommendation data',
  ];
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600));
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(color: Colors.red, fontSize: 14)),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
