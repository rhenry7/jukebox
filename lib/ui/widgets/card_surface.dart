import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The card surface shared by every content card (review cards, Explore
/// track cards): tonal fill, slightly rounded corners, no border and, optionally, the blurred album art behind the content. Screens must not
/// wrap cards in their own Card — only position them (e.g. with
/// [AppSpacing.cardListItem]) and pad the content with
/// [AppSpacing.cardPadding].
class CardSurface extends StatelessWidget {
  final Widget child;

  /// Album art used as the blurred card background (see [kAlbumArtCardBackground]).
  final String? imageUrl;

  const CardSurface({super.key, required this.child, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final showArt = kAlbumArtCardBackground && url != null && url.isNotEmpty;
    return Material(
      color: AppColors.surfaceContainer,
      // The glass edge: a faint light stroke, painted over the content.
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: showArt ? const BorderSide(color: _glassEdge) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: showArt
          ? Stack(
              children: [
                Positioned.fill(child: _AlbumArtBackdrop(imageUrl: url)),
                child,
              ],
            )
          : child,
    );
  }
}

/// The edge of a glass card catching the light (white at 22%).
const Color _glassEdge = Color(0x38FFFFFF);

/// Experiment: album art as the card background. Set to false to go back to
/// the flat surface everywhere.
const bool kAlbumArtCardBackground = true;

/// Album art seen through a pane of frosted glass. The content sits on the
/// glass; under it, bottom to top:
///  1. the art, heavily blurred, a little more saturated and slightly
///     magnified, like colour seen through a lens — it carries the album's
///     colours;
///  2. the same art unblurred, faint, so some texture shows through;
///  3. a dark scrim so white text stays readable;
///  4. the glass: a milky white sheen, brightest at the top-left where the
///     light hits, plus a soft highlight glow.
/// The light edge of the glass is the card's border ([CardSurface]).
///
/// No live blur (BackdropFilter) here — see [_blurSourceWidth].
class _AlbumArtBackdrop extends StatelessWidget {
  const _AlbumArtBackdrop({required this.imageUrl});

  final String imageUrl;

  /// The blur is made by decoding the art this many pixels wide and
  /// stretching it smoothly over the card, instead of a live Gaussian blur.
  /// A live blur on every card ran mobile Safari / Chrome on iOS out of GPU
  /// memory (blank and grey slabs, missing nav bar); this costs about as
  /// much as drawing a thumbnail. Smaller = blurrier.
  static const int _blurSourceWidth = 6;

  /// Opacity of the whole art (blurred + sharp layers).
  static const double _artOpacity = 0.45;
  static const double _sharpOpacity = 0.40;
  static const double _scrimTop = 0.74;
  static const double _scrimMiddle = 0.45;
  static const double _scrimBottom = 0.90;

  /// The art behind the glass: enlarged like through a lens, and more
  /// colourful so the blur has rich colour to diffuse.
  static const double _magnify = 1.12;
  static const double _saturation = 1.4;

  /// Milky sheen of the glass at the lit corner and the far corner.
  static const double _sheenLit = 0.13;
  static const double _sheenFar = 0.02;

  Widget _blurredArt() => Image(
        image: ResizeImage(
          // Flutter's NetworkImage decodes the bytes itself, so the resize
          // applies on web too. (CachedNetworkImage hands web images to an
          // HTML <img>, which ignores it and draws the art sharp.)
          NetworkImage(imageUrl),
          width: _blurSourceWidth,
          policy: ResizeImagePolicy.fit,
        ),
        fit: BoxFit.cover,
        // Smooth (bicubic) upscaling is what turns the tiny image into a blur.
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );

  Widget _art() => CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        // While loading or on error, the plain card surface shows through.
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: _artOpacity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: _magnify,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_saturate(_saturation)),
                    child: _blurredArt(),
                  ),
                ),
                Opacity(opacity: _sharpOpacity, child: _art()),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceContainerLowest.withValues(alpha: _scrimTop),
                  AppColors.surfaceContainerLowest
                      .withValues(alpha: _scrimMiddle),
                  AppColors.surfaceContainerLowest
                      .withValues(alpha: _scrimBottom),
                ],
              ),
            ),
          ),
          // The glass: frosted sheen, lit from the top-left…
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: _sheenLit),
                  Colors.white.withValues(alpha: _sheenFar),
                  Colors.white.withValues(alpha: _sheenFar),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          // …with a soft glow where the light lands.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.85, -1.1),
                radius: 0.9,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A colour matrix that scales saturation by [s] (1 = unchanged), using the
/// standard luminance weights.
List<double> _saturate(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final t = 1 - s;
  return [
    t * r + s, t * g, t * b, 0, 0, //
    t * r, t * g + s, t * b, 0, 0,
    t * r, t * g, t * b + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
