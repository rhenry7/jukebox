import 'package:flutter/material.dart';

import '../screens/Profile/ProfileSignIn.dart';

/// Shows a sign-up/sign-in prompt modal sheet.
/// Use this whenever an anonymous or unauthenticated user tries to
/// perform an action that requires an account (like, comment, repost, etc.).
void showAuthGateModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AuthGateSheet(),
  );
}

class _AuthGateSheet extends StatelessWidget {
  const _AuthGateSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131313),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Disco ball art
          Image.asset(
            'lib/assets/images/discoball_loading.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          // Headline
          const Text(
            'The crates don\'t open themselves.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // Sub-copy
          const Text(
            'Sign up to like, comment, and join the conversation with fellow music heads.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          // Sign Up CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEE2309),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Sign Up — It\'s Free',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Sign In link
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              );
            },
            child: const Text(
              'Already have an account? Sign in',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
