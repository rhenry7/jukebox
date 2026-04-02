import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/services/user_playlist_service.dart';
import 'package:flutter_test_project/ui/screens/playlists/add_songs_screen.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0A0A);
const _card = Color(0xFF121212);
const _primary = Color(0xFFFF3B30);
const _glass = Color(0x08FFFFFF); // rgba(255,255,255,0.03) approx
const _border = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
const _labelColor = Color(0x66FFFFFF); // 40% white
const _hintColor = Color(0x4DFFFFFF); // 30% white

/// Screen for creating a new playlist.
class CreatePlaylistScreen extends ConsumerStatefulWidget {
  const CreatePlaylistScreen({super.key});

  @override
  ConsumerState<CreatePlaylistScreen> createState() =>
      _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends ConsumerState<CreatePlaylistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be signed in to create a playlist')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final playlistId = await UserPlaylistService.createPlaylist(
        userId: user.uid,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        tags: tags.isEmpty ? null : tags,
      );

      if (mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AddSongsScreen(playlistId: playlistId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating playlist: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // ── Header ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _bg.withOpacity(0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CREATE PLAYLIST',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        centerTitle: false,
      ),
      // ── Body ────────────────────────────────────────────────────────────────
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  // ── Identity (name) ────────────────────────────────────────
                  _SectionLabel(label: 'Identity'),
                  const SizedBox(height: 12),
                  _GlassField(
                    child: TextFormField(
                      controller: _nameController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _pillDecoration(
                        hint: 'Enter playlist name...',
                        suffix: Text(
                          '*',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a playlist name'
                          : null,
                    ),
                    pill: true,
                  ),
                  const SizedBox(height: 36),

                  // ── Curator's Note (description) ───────────────────────────
                  _SectionLabel(label: "Curator's Note"),
                  const SizedBox(height: 12),
                  _GlassField(
                    child: TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      maxLines: 5,
                      decoration: _roundedDecoration(
                        hint: "What's the vibe of this collection?",
                      ),
                    ),
                    pill: false,
                  ),
                  const SizedBox(height: 36),

                  // ── Sonic Labels (tags) ────────────────────────────────────
                  _SectionLabel(label: 'Sonic Labels'),
                  const SizedBox(height: 12),
                  _GlassField(
                    child: TextFormField(
                      controller: _tagsController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      decoration: _pillDecoration(
                        hint: 'Lo-fi, Industrial, Night Drive...',
                        prefix: const Icon(Icons.label_outline,
                            color: _labelColor, size: 20),
                      ),
                    ),
                    pill: true,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Separate tags with commas',
                      style: TextStyle(
                        color: _labelColor,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer CTA ──────────────────────────────────────────────────
            _Footer(isCreating: _isCreating, onTap: _createPlaylist),
          ],
        ),
      ),
    );
  }

  InputDecoration _pillDecoration({
    required String hint,
    Widget? suffix,
    Widget? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
      border: InputBorder.none,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 20), child: suffix)
          : null,
      suffixIconConstraints: const BoxConstraints(),
      prefixIcon: prefix != null
          ? Padding(padding: const EdgeInsets.only(left: 18, right: 8), child: prefix)
          : null,
      prefixIconConstraints: const BoxConstraints(),
    );
  }

  InputDecoration _roundedDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
      border: InputBorder.none,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    );
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
        ),
      ),
    );
  }
}

// ─── Glass input wrapper ───────────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  final Widget child;
  final bool pill;
  const _GlassField({required this.child, required this.pill});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(pill ? 100 : 28),
        border: Border.all(color: _border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(pill ? 100 : 28),
        child: child,
      ),
    );
  }
}

// ─── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final bool isCreating;
  final VoidCallback onTap;
  const _Footer({required this.isCreating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_bg, _bg, _bg.withOpacity(0)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: GestureDetector(
        onTap: isCreating ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: isCreating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CREATE & ADD SONGS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
