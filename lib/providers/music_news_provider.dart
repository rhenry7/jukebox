import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/cache_first.dart';

/// The music sites in "Best New Music", in the order their filter pills show.
const musicNewsSources = {
  'pitchfork': 'Pitchfork',
  'stereogum': 'Stereogum',
  'nme': 'NME',
  'billboard': 'Billboard',
};

/// Serves a news item's image with cross-site headers (the `newsImage`
/// function): Pitchfork's and NME's own images can't be drawn on the web.
/// `--dart-define=NEWS_IMAGE_ENDPOINT=…` points it elsewhere (an emulator).
const _newsImageEndpoint = String.fromEnvironment(
  'NEWS_IMAGE_ENDPOINT',
  defaultValue: 'https://us-central1-juxeboxd.cloudfunctions.net/newsImage',
);

/// A review from a music site, from `musicNews/{id}` (written every few hours
/// by the `refreshMusicNews` function, see functions/src/news.ts).
class MusicNewsItem {
  const MusicNewsItem({
    required this.id,
    required this.source,
    required this.sourceName,
    required this.label,
    required this.title,
    this.album = '',
    this.artist = '',
    this.verdict = '',
    required this.summary,
    required this.author,
    required this.url,
    required this.publishedAt,
    this.siteImageUrl,
  });

  final String id;
  final String source;
  final String sourceName;

  /// The kind of pick: "Best New Album", "Album of the Week", "Album Review".
  final String label;

  /// The site's headline.
  final String title;

  /// Split out of the headline by the server where the site's format allows
  /// (empty if not, or for items stored before the split existed).
  final String album;
  final String artist;

  /// The critic's one-line take (NME's "review: brighter, poppier…").
  final String verdict;
  final String summary;
  final String author;

  /// The full review on the site.
  final String url;
  final DateTime publishedAt;

  /// The site's own image URL.
  final String? siteImageUrl;

  /// The row's main line: the album, or the headline when it couldn't be
  /// split.
  String get heading => album.isNotEmpty ? album : title;

  /// The line under it: the artist (empty when unknown).
  String get byArtist => album.isNotEmpty ? artist : '';

  /// The hook: the verdict, else the summary.
  String get hook => verdict.isNotEmpty ? verdict : summary;

  /// What to look the record up by (Spotify, "Review it"): album and
  /// artist, or a short headline as it is ("Josh Johnson Animative" is
  /// already artist + album). Null for a long article headline, which
  /// wouldn't find anything.
  ({String title, String artist})? get lookup {
    if (album.isNotEmpty) return (title: album, artist: artist);
    final words = title.trim().split(RegExp(r'\s+'));
    return title.isNotEmpty && words.length <= 6
        ? (title: title, artist: '')
        : null;
  }

  /// The image to show: on the web through the `newsImage` function (sites
  /// don't allow cross-site loading); on phones straight from the site.
  String? get imageUrl {
    if (siteImageUrl == null) return null;
    return kIsWeb ? '$_newsImageEndpoint?id=$id' : siteImageUrl;
  }

  factory MusicNewsItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const {};
    return MusicNewsItem(
      id: doc.id,
      source: d['source'] as String? ?? '',
      sourceName: d['sourceName'] as String? ?? '',
      label: d['label'] as String? ?? '',
      title: d['title'] as String? ?? '',
      album: d['album'] as String? ?? '',
      artist: d['artist'] as String? ?? '',
      verdict: d['verdict'] as String? ?? '',
      summary: d['summary'] as String? ?? '',
      author: d['author'] as String? ?? '',
      url: d['url'] as String? ?? '',
      publishedAt: (d['publishedAt'] as Timestamp?)?.toDate() ?? DateTime(1970),
      siteImageUrl: d['imageUrl'] as String?,
    );
  }
}

/// The newest reviews from every source, newest first. Cache first, then the
/// server; kept a while so reopening Search is instant.
final musicNewsProvider = StreamProvider<List<MusicNewsItem>>((ref) {
  ref.keepAliveFor();
  final query = FirebaseFirestore.instance
      .collection('musicNews')
      .orderBy('publishedAt', descending: true)
      .limit(60);
  return cacheThenServer(query).map(
    (snap) => [
      for (final doc in snap.docs)
        // Album reviews only (the server already drops the rest; this also
        // covers items stored before it did).
        if ((doc.data()['album'] as String? ?? '').isNotEmpty &&
            (doc.data()['artist'] as String? ?? '').isNotEmpty &&
            Uri.tryParse(doc.data()['url'] as String? ?? '')?.scheme == 'https')
          MusicNewsItem.fromFirestore(doc),
    ],
  );
});

/// The source pill picked on the Search page (null: all sources).
final musicNewsSourceProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// [items] from [source] only, newest first. With no [source] (All), the
/// sites take turns (each newest first, the site with the newest review
/// first), so one site that posts daily doesn't fill the top of the list.
List<MusicNewsItem> filterMusicNews(List<MusicNewsItem> items, String? source) {
  if (source != null) {
    return [
      for (final i in items)
        if (i.source == source) i,
    ];
  }
  final bySource = <String, List<MusicNewsItem>>{};
  for (final i in [
    ...items,
  ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt))) {
    bySource.putIfAbsent(i.source, () => []).add(i);
  }
  final queues = bySource.values.toList();
  return [
    for (var round = 0; queues.any((q) => round < q.length); round++)
      for (final q in queues)
        if (round < q.length) q[round],
  ];
}
