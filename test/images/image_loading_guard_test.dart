import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the fix for album art showing black or missing on the web (see
/// docs/image-rendering.md). cached_network_image's web path decodes through
/// the browser's <img> and those pictures went black or never appeared, so
/// on the web every network image must use Flutter's own loader. Only these
/// files may use cached_network_image, and only in their phone branch.
const _allowed = {
  'lib/utils/cached_image.dart',
  'lib/ui/widgets/card_surface.dart',
};

void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('only AppCachedImage and CardSurface use cached_network_image', () {
    final offenders = [
      for (final f in libFiles)
        if (!_allowed.contains(f.path) &&
            RegExp(r'CachedNetworkImage|cached_network_image')
                .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty,
        reason: 'Use AppCachedImage (lib/utils/cached_image.dart) for network '
            'images. See docs/image-rendering.md.');
  });

  test("where cached_network_image is used, the web uses Flutter's loader",
      () {
    for (final path in _allowed) {
      final src = File(path).readAsStringSync();
      expect(src, contains('kIsWeb'),
          reason: '$path must branch on kIsWeb (see docs/image-rendering.md)');
      expect(RegExp(r'Image\.network\(|NetworkImage\(').hasMatch(src), isTrue,
          reason: "$path must use Flutter's loader on the web");
    }
  });

  test('screens load network images through the shared widgets', () {
    // Raw Image.network / NetworkImage outside the image widgets skips the
    // shared placeholders and sizing. The review page hero and its frosted
    // backdrop are deliberate exceptions: they fade the art with a shader
    // mask, which needs Flutter's own decoded image.
    const exceptions = {
      ..._allowed,
      'lib/ui/screens/review_detail/review_detail_page.dart',
    };
    final offenders = [
      for (final f in libFiles)
        if (!exceptions.contains(f.path) &&
            RegExp(r'Image\.network\(|NetworkImage\(')
                .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty,
        reason: 'Use AppCachedImage. See docs/image-rendering.md.');
  });
}
