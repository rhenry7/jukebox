import 'package:flutter/material.dart';
import 'package:flutter_test_project/ui/screens/playlists/playlists_screen.dart';

/// Playlist Discovery Screen - Redirects to new playlists screen
class PlaylistDiscoveryScreen extends StatelessWidget {
  const PlaylistDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaylistsScreen();
  }
}
