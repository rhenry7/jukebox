import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review.dart';
import '../ui/widgets/genre_pills.dart' show rankTags, splitGenreTags;
import 'community_reviews_provider.dart' show communityReviewsProvider;
import 'reviews_provider.dart' show ReviewWithDocId, firestoreProvider;

/// How many of the newest reviews the fallback search reads.
const int tagPoolSize = 500;

/// Reviews fetched per page on the tag page.
const int tagPageSize = 20;

/// How long a tag page's results are kept after it closes, so going back
/// and forth between tags is instant.
const Duration tagFeedKeepAlive = Duration(minutes: 5);

/// How many related tags the tag page offers.
const int relatedTagCount = 8;

/// Reviews for one tag, and the tags people use alongside it.
typedef TagReviews = ({
  List<ReviewWithDocId> exact,
  List<ReviewWithDocId> similar,
  List<String> related,
});

// ── Tag page feed ───────────────────────────────────────────────────────────
//
// Three sections, each a paged database query on fields written with every
// review (see [searchKeysFor]): reviews tagged with the tag, then with a
// similar tag, then whose text mentions it. While the first page loads, the
// page shows matches from the Popular pool already in memory.

/// One tag page's results.
@immutable
class TagFeed {
  const TagFeed({
    required this.exact,
    required this.similar,
    required this.mentions,
    required this.related,
    this.exactCount,
    this.similarCount,
    this.hasMore = false,
    this.isPreview = false,
  });

  final List<ReviewWithDocId> exact;
  final List<ReviewWithDocId> similar;
  final List<ReviewWithDocId> mentions;

  /// Other tags on these reviews, most used first.
  final List<String> related;

  /// Totals across all reviews, when known (otherwise use the list lengths).
  final int? exactCount;
  final int? similarCount;

  final bool hasMore;

  /// Built from reviews already in memory while the real results load.
  final bool isPreview;

  List<ReviewWithDocId> get all => [...exact, ...similar, ...mentions];
}

final tagFeedProvider = AsyncNotifierProvider.autoDispose
    .family<TagFeedNotifier, TagFeed, String>(TagFeedNotifier.new);

/// Loads a tag page page by page: Tagged, then Similar, then Mentions.
class TagFeedNotifier extends AutoDisposeFamilyAsyncNotifier<TagFeed, String> {
  late String _want;
  late FirebaseFirestore _db;
  final _sections = <_Section>[];
  final _seen = <String>{};
  final _exact = <ReviewWithDocId>[];
  final _similar = <ReviewWithDocId>[];
  final _mentions = <ReviewWithDocId>[];
  int? _exactCount;
  int? _similarCount;
  bool _loading = false;
  int _generation = 0;

  @override
  Future<TagFeed> build(String tag) async {
    _keepAliveForAWhile();
    // A refresh or close makes any background load from before it stale.
    ref.onDispose(() => _generation++);
    _want = normalizeTag(tag);
    _db = ref.watch(firestoreProvider);

    final generation = ++_generation;
    final preview = _preview() ?? await _cachedPreview();
    if (preview != null) {
      // Show what's in memory now; the real first page replaces it (unless
      // the page was refreshed or closed in the meantime).
      unawaited(Future(() async {
        final result = await AsyncValue.guard(_firstPage);
        if (generation == _generation) state = result;
      }));
      return preview;
    }
    return _firstPage();
  }

  /// The next page, into the first section that has more.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (_loading || current == null || !current.hasMore) return;
    _loading = true;
    try {
      await _fill();
      state = AsyncData(_feed());
    } catch (e) {
      debugPrint('[TAG_PAGE] Could not load more: $e');
    } finally {
      _loading = false;
    }
  }

  void _keepAliveForAWhile() {
    final link = ref.keepAlive();
    Timer? timer;
    ref.onCancel(() => timer = Timer(tagFeedKeepAlive, link.close));
    ref.onResume(() => timer?.cancel());
    ref.onDispose(() => timer?.cancel());
  }

  /// Matches among the Popular reviews already loaded, if that feed is open.
  TagFeed? _preview() {
    if (!ref.exists(communityReviewsProvider)) return null;
    final pool = ref.read(communityReviewsProvider).valueOrNull;
    if (pool == null || pool.isEmpty) return null;
    final feed = _fromPool(pool);
    return feed.all.isEmpty ? null : feed;
  }

  /// This tag's newest reviews already on the device (from an earlier
  /// visit), to show while the server is asked. Null when none are cached.
  Future<TagFeed?> _cachedPreview() async {
    try {
      final snapshot = await _db
          .collectionGroup('reviews')
          .where('tagKeys', arrayContains: _want)
          .orderBy('date', descending: true)
          .limit(tagPageSize)
          .get(const GetOptions(source: Source.cache));
      final pool = <ReviewWithDocId>[];
      for (final doc in snapshot.docs) {
        try {
          final item = ReviewWithDocId(
            review: Review.fromFirestore(doc.data()),
            docId: doc.id,
            fullReviewId: doc.reference.path,
          );
          if (!item.review.isRepost) pool.add(item);
        } catch (_) {
          // Unreadable; the server page decides.
        }
      }
      if (pool.isEmpty) return null;
      final feed = _fromPool(pool);
      return feed.exact.isEmpty ? null : feed;
    } catch (_) {
      return null;
    }
  }

  Future<TagFeed> _firstPage() async {
    _reset();
    try {
      final words = _tagWords(_want);
      final counts = Future.wait([
        _count(_db
            .collectionGroup('reviews')
            .where('tagKeys', arrayContains: _want)),
        if (words.isNotEmpty)
          _count(_db
              .collectionGroup('reviews')
              .where('tagWordKeys', arrayContainsAny: words)),
      ]);
      await _fill();
      if (_exact.isEmpty) {
        // A pill's own tag always has reviews; none means the index isn't
        // built yet (or a query failed), so search the newest reviews.
        return _legacy();
      }
      final c = await counts;
      _exactCount = c[0];
      if (c.length > 1 && c[1] != null && c[0] != null) {
        _similarCount = (c[1]! - c[0]!).clamp(0, 1 << 30);
      }
      return _feed();
    } catch (e) {
      debugPrint('[TAG_PAGE] Indexed search failed, using recent reviews: $e');
      return _legacy();
    }
  }

  void _reset() {
    _seen.clear();
    _exact.clear();
    _similar.clear();
    _mentions.clear();
    _exactCount = null;
    _similarCount = null;
    final reviews = _db.collectionGroup('reviews');
    final words = _tagWords(_want);
    _sections
      ..clear()
      ..add(_Section(
        reviews.where('tagKeys', arrayContains: _want),
        _exact,
        (_) => true,
      ))
      ..add(_Section(
        words.isEmpty
            ? null
            : reviews.where('tagWordKeys', arrayContainsAny: words),
        _similar,
        (r) => !_hasExactTag(r, _want),
      ))
      ..add(_Section(
        reviews.where('textWordKeys', arrayContains: _mentionWord(_want)),
        _mentions,
        (r) => mentionsTag(r.review.review, _want),
      ));
  }

  /// Fetches pages until [tagPageSize] new reviews arrive or nothing is left.
  Future<void> _fill() async {
    var added = 0;
    for (final section in _sections) {
      while (!section.done && added < tagPageSize) {
        added += await _nextPage(section);
      }
      if (added >= tagPageSize) return;
    }
  }

  Future<int> _nextPage(_Section section) async {
    final base = section.query;
    if (base == null) {
      section.done = true;
      return 0;
    }
    var query = base.orderBy('date', descending: true);
    if (section.cursor != null) {
      query = query.startAfterDocument(section.cursor!);
    }
    final snapshot = await query.limit(tagPageSize).get();
    if (snapshot.docs.length < tagPageSize) section.done = true;
    if (snapshot.docs.isNotEmpty) section.cursor = snapshot.docs.last;

    var added = 0;
    for (final doc in snapshot.docs) {
      if (!_seen.add(doc.reference.path)) continue;
      final ReviewWithDocId item;
      try {
        item = ReviewWithDocId(
          review: Review.fromFirestore(doc.data()),
          docId: doc.id,
          fullReviewId: doc.reference.path,
        );
      } catch (e) {
        debugPrint('[TAG_PAGE] Skipping unreadable review ${doc.id}: $e');
        continue;
      }
      if (item.review.isRepost || !section.keep(item)) continue;
      section.into.add(item);
      added++;
    }
    return added;
  }

  TagFeed _feed() => TagFeed(
        exact: List.of(_exact),
        similar: List.of(_similar),
        mentions: List.of(_mentions),
        related: _relatedTags(_want, [..._exact, ..._similar]),
        exactCount: _exactCount,
        similarCount: _similarCount,
        hasMore: _sections.any((s) => !s.done),
      );

  /// Today's search before the index existed: the newest [tagPoolSize]
  /// reviews, filtered here.
  Future<TagFeed> _legacy() async {
    final snapshot = await _db
        .collectionGroup('reviews')
        .orderBy('date', descending: true)
        .limit(tagPoolSize)
        .get();
    final pool = <ReviewWithDocId>[];
    for (final doc in snapshot.docs) {
      try {
        pool.add(ReviewWithDocId(
          review: Review.fromFirestore(doc.data()),
          docId: doc.id,
          fullReviewId: doc.reference.path,
        ));
      } catch (e) {
        debugPrint('[TAG_PAGE] Skipping unreadable review ${doc.id}: $e');
      }
    }
    return _fromPool(pool, isPreview: false);
  }

  TagFeed _fromPool(List<ReviewWithDocId> pool, {bool isPreview = true}) {
    final grouped = groupByTag(_want, pool);
    return TagFeed(
      exact: grouped.exact,
      similar: grouped.similar,
      mentions: mentionsAmong(_want, pool,
          exclude: {...grouped.exact, ...grouped.similar}),
      related: grouped.related,
      isPreview: isPreview,
    );
  }

  Future<int?> _count(Query<Map<String, dynamic>> query) async {
    try {
      return (await query.count().get()).count;
    } catch (e) {
      debugPrint('[TAG_PAGE] Count unavailable: $e');
      return null;
    }
  }
}

class _Section {
  _Section(this.query, this.into, this.keep);

  final Query<Map<String, dynamic>>? query;
  final List<ReviewWithDocId> into;
  final bool Function(ReviewWithDocId) keep;
  DocumentSnapshot<Map<String, dynamic>>? cursor;
  bool done = false;
}

bool _hasExactTag(ReviewWithDocId r, String want) =>
    splitGenreTags(r.review.genres).map(normalizeTag).contains(want);

/// Meaningful words of a normalized tag, for the similar-tags query.
List<String> _tagWords(String want) => want
    .split(' ')
    .where((w) => w.isNotEmpty && !_genericWords.contains(w))
    .toSet()
    .toList();

/// The word looked up for "mentions": the tag's first meaningful word.
String _mentionWord(String want) {
  final words = _tagWords(want);
  return words.isNotEmpty ? words.first : want.split(' ').first;
}

List<String> _relatedTags(String want, List<ReviewWithDocId> reviews) =>
    rankTags([for (final r in reviews) splitGenreTags(r.review.genres)])
        .where((t) => normalizeTag(t) != want)
        .take(relatedTagCount)
        .toList();

/// Whether review [text] mentions the normalized tag [want] as whole words.
bool mentionsTag(String text, String want) {
  if (want.isEmpty) return false;
  return RegExp(
          '(^|[^\\p{L}\\p{N}&])${RegExp.escape(want)}(\$|[^\\p{L}\\p{N}&])',
          unicode: true)
      .hasMatch(normalizeTag(text));
}

/// Reviews in [candidates] whose text mentions [tag] (newest first), other
/// than reposts and those in [exclude].
@visibleForTesting
List<ReviewWithDocId> mentionsAmong(
  String tag,
  List<ReviewWithDocId> candidates, {
  Set<ReviewWithDocId> exclude = const {},
}) {
  final want = normalizeTag(tag);
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  return candidates
      .where((c) =>
          !c.review.isRepost &&
          !exclude.contains(c) &&
          mentionsTag(c.review.review, want))
      .toList()
    ..sort(
        (a, b) => (b.review.date ?? epoch).compareTo(a.review.date ?? epoch));
}

// ── Search keys (the index) ─────────────────────────────────────────────────
// Must match `searchKeys` in functions/src/text.ts; both are tested against
// functions/src/__tests__/fixtures/search_keys.json.

/// Common words left out of `textWordKeys`.
const Set<String> _stopwords = {
  'a', 'an', 'and', 'the', 'of', 'to', 'in', 'on', 'for', 'is', 'it', 'its', //
  'this', 'that', 'with', 'as', 'at', 'be', 'but', 'by', 'are', 'was', 'were',
  'i', 'im', 'my', 'me', 'so', 'or', 'if', 'you', 'your', 'we', 'they', 'he',
  'she', 'his', 'her', 'them', 'than', 'then', 'there', 'from', 'have', 'has',
  'had', 'do', 'does', 'did', 'not', 'no', 'just', 'very', 'too', 'also',
};

/// How many distinct words of a review's text are indexed.
const int maxTextWordKeys = 150;

/// Normalized words of [text], in order (letters, digits and "&").
List<String> textWords(String text) => normalizeTag(text)
    .split(RegExp(r'[^\p{L}\p{N}&]+', unicode: true))
    .where((w) =>
        w.length >= 2 && RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(w))
    .toList();

/// The tag page's index fields for a review, written with it: its normalized
/// tags, the meaningful words of those tags (similar tags), and the distinct
/// words of its text (mentions). Reposts get none, so they never match.
Map<String, List<String>> searchKeysFor({
  List<String>? genres,
  List<String>? tags,
  String review = '',
  bool isRepost = false,
}) {
  final tagKeys = <String>{};
  final tagWordKeys = <String>{};
  final textWordKeys = <String>{};
  if (!isRepost) {
    for (final tag in splitGenreTags([...?genres, ...?tags])) {
      final key = normalizeTag(tag);
      if (key.isEmpty) continue;
      tagKeys.add(key);
      for (final word in key.split(' ')) {
        if (word.isNotEmpty && !_genericWords.contains(word)) {
          tagWordKeys.add(word);
        }
      }
    }
    for (final word in textWords(review)) {
      if (textWordKeys.length >= maxTextWordKeys) break;
      if (!_stopwords.contains(word)) textWordKeys.add(word);
    }
  }
  List<String> sorted(Set<String> s) => s.toList()..sort();
  return {
    'tagKeys': sorted(tagKeys),
    'tagWordKeys': sorted(tagWordKeys),
    'textWordKeys': sorted(textWordKeys),
  };
}

/// Splits [candidates] into reviews tagged exactly [tag] and reviews with a
/// similar tag (see [tagsSimilar]), each newest first, skipping reposts.
/// [related] is the other tags on those reviews, most used first.
@visibleForTesting
TagReviews groupByTag(String tag, List<ReviewWithDocId> candidates) {
  final want = normalizeTag(tag);
  final exact = <ReviewWithDocId>[];
  final similar = <ReviewWithDocId>[];
  final matchedTags = <List<String>>[];

  for (final c in candidates) {
    if (c.review.isRepost) continue;
    final tags = splitGenreTags(c.review.genres);
    final keys = tags.map(normalizeTag);
    if (keys.contains(want)) {
      exact.add(c);
    } else if (keys.any((k) => tagsSimilar(want, k))) {
      similar.add(c);
    } else {
      continue;
    }
    matchedTags.add(tags);
  }

  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  int newest(ReviewWithDocId a, ReviewWithDocId b) =>
      (b.review.date ?? epoch).compareTo(a.review.date ?? epoch);
  exact.sort(newest);
  similar.sort(newest);

  return (
    exact: exact,
    similar: similar,
    related: rankTags(matchedTags)
        .where((t) => normalizeTag(t) != want)
        .take(relatedTagCount)
        .toList(),
  );
}

/// Words too generic to make two tags similar on their own.
const Set<String> _genericWords = {
  'music',
  'and',
  'the',
  'of',
  'song',
  'songs'
};

/// Lowercase, with spelling variants folded together: "R&B", "rnb" and
/// "R and B" → "r&b"; "hip-hop" and "hiphop" → "hip hop".
String normalizeTag(String tag) {
  var t = tag.toLowerCase().trim().replaceAll(RegExp(r'[-_]+'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAll(RegExp(r'\b(rnb|r ?n ?b|r and b|r ?& ?b)\b'), 'r&b');
  t = t.replaceAll(RegExp(r'\bhiphop\b'), 'hip hop');
  return t;
}

/// True when two normalized tags are related: one contains the other as
/// whole words ("r&b" / "alternative r&b"), or they share a meaningful word
/// ("chill dance" / "relaxing dance").
bool tagsSimilar(String a, String b) {
  if (a == b) return true;
  final wordsA = a.split(' ');
  final wordsB = b.split(' ');
  bool containsWords(List<String> outer, List<String> inner) {
    for (var i = 0; i + inner.length <= outer.length; i++) {
      if (listEquals(outer.sublist(i, i + inner.length), inner)) return true;
    }
    return false;
  }

  if (containsWords(wordsA, wordsB) || containsWords(wordsB, wordsA)) {
    return true;
  }
  final meaningful = wordsA.where((w) => !_genericWords.contains(w)).toSet();
  return wordsB.any(meaningful.contains);
}
