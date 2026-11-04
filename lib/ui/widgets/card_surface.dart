import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The card surface shared by every content card (review cards, Explore
/// track cards): tonal fill, square corners, a faint ghost border and,
/// optionally, the blurred album art behind the content. Screens must not
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
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.ghostBorder),
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

/// Experiment: album art as the card background. Set to false to go back to
/// the flat surface everywhere.
const bool kAlbumArtCardBackground = true;

/// Album art as a card background, in three layers:
///  1. the art, heavily blurred — carries the album's colours;
///  2. the same art unblurred at ~20% so some texture and style shows through;
///  3. a dark scrim so white text stays readable.
class _AlbumArtBackdrop extends StatelessWidget {
  const _AlbumArtBackdrop({required this.imageUrl});

  final String imageUrl;

  /// The blur is made by decoding the art this many pixels wide and
  /// stretching it smoothly over the card, instead of a live Gaussian blur.
  /// A live blur on every card ran mobile Safari / Chrome on iOS out of GPU
  /// memory (blank and grey slabs, missing nav bar); this costs about as
  /// much as drawing a thumbnail. Smaller = blurrier.
  static const int _blurSourceWidth = 8;

  /// Opacity of the whole art (blurred + sharp layers).
  static const double _artOpacity = 0.85;
  static const double _sharpOpacity = 0.20;
  static const double _scrimTop = 0.74;
  static const double _scrimMiddle = 0.85;
  static const double _scrimBottom = 0.90;

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
                _blurredArt(),
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
        ],
      ),
    );
  }
}
