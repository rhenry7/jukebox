import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A network image (album art, avatars) with the app's loading and error
/// placeholders: a spinner while loading, a music note if it fails.
///
/// On phones it uses [CachedNetworkImage] (cached on disk). On the web it
/// uses Flutter's own [Image.network] instead: cached_network_image decodes
/// web images through the browser's `<img>` path, and those pictures came out
/// solid black or never appeared, especially after leaving a page and coming
/// back. The browser's HTTP cache already caches the files on the web.
class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  Widget _placeholder() => Container(
    width: width,
    height: height,
    color: Colors.grey[850],
    child: const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
        ),
      ),
    ),
  );

  Widget _error() => Container(
    width: width,
    height: height,
    color: Colors.grey[800],
    child: const Icon(Icons.music_note, color: Colors.white70),
  );

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (kIsWeb) {
      // Decode at the size it's shown (e.g. 100 px thumbnails of 640 px
      // art) to keep memory down.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final w = width;
      image = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: w != null && w.isFinite ? (w * dpr).round() : null,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(),
        errorBuilder: (context, error, stack) => _error(),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _placeholder(),
        errorWidget: (context, url, error) => _error(),
      );
    }

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}
