import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/providers/cache_first.dart';
import 'package:flutter_test_project/providers/reviews_provider.dart';

/// The music sites in "Best New Music", in the order the site picker lists
/// them.
const musicNewsSources = {
  'pitchfork': 'Pitchfork',
  'stereogum': 'Stereogum',
  'nme': 'NME',
  'billboard': 'Billboard',
  'guardian': 'The Guardian',
  'quietus': 'The Quietus',
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
    this.genres = const [],
    this.tags = const [],
    this.artistMbids = const [],
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

  /// Broad genres ("Hip-hop", "Rock"…), from the site's and MusicBrainz's
  /// tags (server, `genresFor` in functions/src/news.ts).
  final List<String> genres;

  /// Genre-like tags, lowercase ("grime", "indie rock").
  final List<String> tags;

  /// The artist's MusicBrainz ID, when found.
  final List<String> artistMbids;

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
      genres: _strings(d['genres']),
      tags: _strings(d['tags']),
      artistMbids: _strings(d['artistMbids']),
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

List<String> _strings(Object? v) => v is List
    ? [
        for (final x in v)
          if (x is String && x.isNotEmpty) x,
      ]
    : const [];

/// Sites the user switched off in the site picker (kept for the session).
final musicNewsHiddenSourcesProvider = StateProvider<Set<String>>(
  (ref) => const {},
);

/// The filter pill picked: [NewsFilter.all] unless the user tapped one.
final musicNewsFilterProvider = StateProvider.autoDispose<NewsFilter>(
  (ref) => NewsFilter.all,
);

/// A filter pill: All, For you, Critics agree, This week, or a genre.
@immutable
class NewsFilter {
  const NewsFilter._(this.kind, [this.genre]);

  const NewsFilter.genre(String genre) : this._(NewsFilterKind.genre, genre);

  static const all = NewsFilter._(NewsFilterKind.all);
  static const forYou = NewsFilter._(NewsFilterKind.forYou);
  static const criticsAgree = NewsFilter._(NewsFilterKind.criticsAgree);
  static const thisWeek = NewsFilter._(NewsFilterKind.thisWeek);

  final NewsFilterKind kind;
  final String? genre;

  String get label => switch (kind) {
    NewsFilterKind.all => 'All',
    NewsFilterKind.forYou => 'For you',
    NewsFilterKind.criticsAgree => 'Critics agree',
    NewsFilterKind.thisWeek => 'This week',
    NewsFilterKind.genre => genre!,
  };

  @override
  bool operator ==(Object other) =>
      other is NewsFilter && other.kind == kind && other.genre == genre;

  @override
  int get hashCode => Object.hash(kind, genre);
}

enum NewsFilterKind { all, forYou, criticsAgree, thisWeek, genre }

/// The first named artist ("Erykah Badu & The Alchemist" → "Erykah Badu"),
/// as the server looks artists up (`mainArtist` in functions/src/news.ts).
String newsMainArtist(String artist) => artist
    .split(
      RegExp(r'\s*(?:,|&|\band\b|\bfeat\.?|\bx\b)\s*', caseSensitive: false),
    )
    .first
    .trim();

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// One album and every site's review of it.
class NewsAlbum {
  NewsAlbum(List<MusicNewsItem> reviews)
    : reviews = [...reviews]..sort(_byStanding);

  /// The site's own pick (Best New Album, Album of the Week) first, then
  /// the newest.
  static int _byStanding(MusicNewsItem a, MusicNewsItem b) {
    final pick = _isPick(b).compareTo(_isPick(a));
    return pick != 0 ? pick : b.publishedAt.compareTo(a.publishedAt);
  }

  static int _isPick(MusicNewsItem i) =>
      RegExp(
        'best new|of the (week|month)',
        caseSensitive: false,
      ).hasMatch(i.label)
      ? 1
      : 0;

  final List<MusicNewsItem> reviews;

  /// The review the row shows (cover, album, artist, take).
  MusicNewsItem get primary => reviews.first;

  /// When the latest review of it came out.
  DateTime get latest =>
      reviews.map((r) => r.publishedAt).reduce((a, b) => a.isAfter(b) ? a : b);

  /// More than one site reviewed it.
  bool get criticsAgree => sources.length > 1;

  List<String> get sources => [
    for (final r in reviews)
      if (!reviews.takeWhile((x) => x != r).any((x) => x.source == r.source))
        r.source,
  ];

  List<String> get sourceNames => [
    for (final s in sources)
      reviews.firstWhere((r) => r.source == s).sourceName,
  ];

  Set<String> get genres => {for (final r in reviews) ...r.genres};
  Set<String> get tags => {for (final r in reviews) ...r.tags};
  Set<String> get artistMbids => {for (final r in reviews) ...r.artistMbids};
}

/// Groups reviews of the same album (same first-named artist and title,
/// ignoring case and punctuation), newest album first.
List<NewsAlbum> groupNewsAlbums(List<MusicNewsItem> items) {
  final groups = <String, List<MusicNewsItem>>{};
  for (final i in items) {
    final key = '${_norm(newsMainArtist(i.artist))}|${_norm(i.album)}';
    groups.putIfAbsent(key == '|' ? i.id : key, () => []).add(i);
  }
  return [for (final g in groups.values) NewsAlbum(g)]
    ..sort((a, b) => b.latest.compareTo(a.latest));
}

/// The sites take turns (each newest first, the site with the newest album
/// first), so one that posts daily doesn't fill the top of the list.
List<NewsAlbum> interleaveBySource(List<NewsAlbum> albums) {
  final bySource = <String, List<NewsAlbum>>{};
  for (final a in albums) {
    bySource.putIfAbsent(a.primary.source, () => []).add(a);
  }
  final queues = bySource.values.toList();
  return [
    for (var round = 0; queues.any((q) => round < q.length); round++)
      for (final q in queues)
        if (round < q.length) q[round],
  ];
}

/// What the user's reviews say they like, for "For you": the artists they
/// rated well, artists that sound like them, and their tags.
class NewsTaste {
  const NewsTaste({
    this.artists = const {},
    this.similar = const {},
    this.tags = const {},
  });

  static const empty = NewsTaste();

  /// MusicBrainz IDs of artists the user rated 3.5★ or more.
  final Set<String> artists;

  /// Artists that sound like those (ListenBrainz), MBID → 0–1 similarity.
  final Map<String, double> similar;

  /// Tags on the user's reviews, lowercase.
  final Set<String> tags;

  bool get isEmpty => artists.isEmpty && similar.isEmpty && tags.isEmpty;

  /// How well [album] fits: an artist they love 1, one that sounds like it
  /// up to 0.6, plus 0.15 per shared tag (up to three).
  double score(NewsAlbum album) {
    var artist = 0.0;
    for (final id in album.artistMbids) {
      if (artists.contains(id)) artist = 1;
      artist = artist < 1 && similar[id] != null
          ? (0.6 * similar[id]!).clamp(artist, 1.0)
          : artist;
    }
    final shared = album.tags.where(tags.contains).length.clamp(0, 3);
    return artist + 0.15 * shared;
  }
}

/// The signed-in user's [NewsTaste], from their reviews and the similar
/// artists cached for them (`similarArtists/{mbid}`, public).
final newsTasteProvider = FutureProvider.autoDispose<NewsTaste>((ref) async {
  ref.keepAliveFor();
  final reviews = await ref.watch(userReviewsProvider.future);
  if (reviews.isEmpty) return NewsTaste.empty;
  final artists = <String>{};
  final tags = <String>{};
  for (final r in reviews) {
    final review = r.review;
    if (review.score >= 3.5) artists.addAll(review.artistMbids);
    for (final t in review.genres ?? const <String>[]) {
      tags.add(t.toLowerCase().trim());
    }
  }
  final similar = <String, double>{};
  final docs = await Future.wait([
    for (final id in artists.take(20))
      FirebaseFirestore.instance
          .collection('similarArtists')
          .doc(id)
          .get()
          .then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d)
          .catchError((Object _) => null),
  ]);
  for (final doc in docs) {
    final list = doc?.data()?['similar'];
    if (list is! List) continue;
    for (final s in list) {
      if (s is! Map) continue;
      final id = s['mbid'], score = s['score'];
      if (id is! String || score is! num || artists.contains(id)) continue;
      if (score > (similar[id] ?? 0)) similar[id] = score.toDouble();
    }
  }
  return NewsTaste(artists: artists, similar: similar, tags: tags);
});

/// The genre pills, those with albums: the user's genres first (how many of
/// their tags the genre's albums carry), then the biggest.
List<String> newsGenres(List<NewsAlbum> albums, NewsTaste taste) {
  final count = <String, int>{};
  final affinity = <String, int>{};
  for (final a in albums) {
    final shared = a.tags.where(taste.tags.contains).length;
    for (final g in a.genres) {
      count[g] = (count[g] ?? 0) + 1;
      affinity[g] = (affinity[g] ?? 0) + shared;
    }
  }
  return count.keys.toList()..sort((a, b) {
    final byTaste = (affinity[b] ?? 0).compareTo(affinity[a] ?? 0);
    if (byTaste != 0) return byTaste;
    final bySize = count[b]!.compareTo(count[a]!);
    return bySize != 0 ? bySize : a.compareTo(b);
  });
}

/// How many days count as "This week".
const newsThisWeekDays = 7;

/// [albums] under [filter]: For you ranks by [NewsTaste.score] (fits only);
/// the rest keep the sites taking turns.
List<NewsAlbum> applyNewsFilter(
  List<NewsAlbum> albums,
  NewsFilter filter,
  NewsTaste taste, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  switch (filter.kind) {
    case NewsFilterKind.all:
      return interleaveBySource(albums);
    case NewsFilterKind.forYou:
      final scored =
          [
            for (final a in albums)
              if (taste.score(a) > 0) (a, taste.score(a)),
          ]..sort((x, y) {
            final byScore = y.$2.compareTo(x.$2);
            return byScore != 0 ? byScore : y.$1.latest.compareTo(x.$1.latest);
          });
      return [for (final s in scored) s.$1];
    case NewsFilterKind.criticsAgree:
      return [
        for (final a in albums)
          if (a.criticsAgree) a,
      ];
    case NewsFilterKind.thisWeek:
      return interleaveBySource([
        for (final a in albums)
          if (today.difference(a.latest).inDays < newsThisWeekDays) a,
      ]);
    case NewsFilterKind.genre:
      return interleaveBySource([
        for (final a in albums)
          if (a.genres.contains(filter.genre)) a,
      ]);
  }
}

/// The pills to show for [albums]: All, then For you / Critics agree / This
/// week when each has something, then genres.
List<NewsFilter> newsFilters(
  List<NewsAlbum> albums,
  NewsTaste taste, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  return [
    NewsFilter.all,
    if (albums.any((a) => taste.score(a) > 0)) NewsFilter.forYou,
    if (albums.any((a) => a.criticsAgree)) NewsFilter.criticsAgree,
    if (albums.any((a) => today.difference(a.latest).inDays < newsThisWeekDays))
      NewsFilter.thisWeek,
    for (final g in newsGenres(albums, taste)) NewsFilter.genre(g),
  ];
}
