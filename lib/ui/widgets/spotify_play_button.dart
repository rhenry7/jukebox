import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/spotify_link_service.dart';
import '../../services/spotify_open/spotify_open.dart';
import '../theme/tokens.dart';
import 'app_toast.dart';

/// "Play on Spotify" button for a reviewed song or album: a full-width pill
/// with a label (review detail page), or with [compact] just the logo
/// (review cards).
///
/// Uses [url] when the review saved its Spotify link. Otherwise the link is
/// looked up as soon as the button is built, so the tap itself opens it right
/// away (browsers block pop-ups opened after a wait); until a confident match
/// is found, the tap opens Spotify's search instead.
/// [raw] as a link to open, if it's an https link to open.spotify.com. Review
/// fields are written by their authors, so anything else is ignored and the
/// button searches as usual.
@visibleForTesting
Uri? savedSpotifyLink(String? raw) {
  final uri = raw == null ? null : Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host != 'open.spotify.com') {
    return null;
  }
  return uri;
}

class SpotifyPlayButton extends StatefulWidget {
  const SpotifyPlayButton({
    super.key,
    required this.title,
    required this.artist,
    this.url,
    this.compact = false,
  });

  final String title;
  final String artist;

  /// The review's saved Spotify link, if any ([savedSpotifyLink] checks it).
  final String? url;
  final bool compact;

  @override
  State<SpotifyPlayButton> createState() => _SpotifyPlayButtonState();
}

class _SpotifyPlayButtonState extends State<SpotifyPlayButton> {
  Uri? _link;

  @override
  void initState() {
    super.initState();
    final saved = savedSpotifyLink(widget.url);
    if (saved != null) {
      _link = saved;
      return;
    }
    SpotifyLinkService.resolve(widget.title, widget.artist).then((link) {
      if (mounted) setState(() => _link = link);
    });
  }

  Future<void> _open() async {
    final url =
        _link ?? SpotifyLinkService.searchUrl(widget.title, widget.artist);
    final opened = await openOnSpotify(url);
    if (!opened && mounted) {
      showAppToast(context, "Couldn't open Spotify", tone: ToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Tooltip(
        message: 'Play on Spotify',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _open,
            customBorder: const CircleBorder(),
            child: const SizedBox.square(
              dimension: 36,
              child: Center(child: SpotifyLogo(size: 30)),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _open,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          side: BorderSide.none,
          // Same fully rounded shape as the genre / tag pills.
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpotifyLogo(size: 22),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Play on Spotify',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Spotify mark: a green circle with three curved bars.
class SpotifyLogo extends StatelessWidget {
  const SpotifyLogo({super.key, this.size = 24});

  final double size;

  static const Color spotifyGreen = Color(0xFF1ED760);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Spotify',
      child:
          CustomPaint(size: Size.square(size), painter: _SpotifyLogoPainter()),
    );
  }
}

class _SpotifyLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    canvas.drawCircle(center, s / 2, Paint()..color = SpotifyLogo.spotifyGreen);

    final bar = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Top bar is widest and thickest; each one below is narrower and thinner.
    const bars = [
      (y: 0.36, halfWidth: 0.30, stroke: 0.085),
      (y: 0.53, halfWidth: 0.255, stroke: 0.07),
      (y: 0.69, halfWidth: 0.21, stroke: 0.06),
    ];
    for (final b in bars) {
      bar.strokeWidth = s * b.stroke;
      final w = s * b.halfWidth;
      final y = s * b.y;
      // A shallow arc bowing upward, like a smile turned over.
      final rect = Rect.fromCenter(
        center: Offset(s / 2, y + w * 0.9),
        width: w * 2.6,
        height: w * 2.0,
      );
      canvas.drawArc(rect, math.pi * 1.28, math.pi * 0.44, false, bar);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
