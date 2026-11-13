import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/providers/search_reviews_provider.dart';
import 'package:flutter_test_project/ui/widgets/review_card.dart'
    show ReviewCardWithGenres;
import 'package:flutter_test_project/ui/screens/search/unified_search_results.dart';
import 'package:flutter_test_project/ui/theme/tokens.dart';
import 'package:flutter_test_project/ui/widgets/music_news_feed.dart';
import 'package:flutter_test_project/ui/widgets/round_icon_button.dart';
import 'package:flutter_test_project/ui/widgets/search_pill_field.dart';

/// Search reviews: everyone's (the Home search button), or with
/// [ownReviewsOnly] just the signed-in user's (the Profile search bar).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.ownReviewsOnly = false});

  final bool ownReviewsOnly;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _submittedQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Auto-focus keyboard when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _submittedQuery = value.trim());
      }
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    if (mounted) {
      setState(() => _submittedQuery = value.trim());
    }
  }

  void _clearSearch() {
    _controller.clear();
    _debounce?.cancel();
    setState(() => _submittedQuery = '');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Same header as Home and Profile: a round grey back button, then the
      // search field as a grey pill like Profile's "Search your reviews".
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 56.0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: RoundIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        titleSpacing: AppSpacing.sm,
        title: SearchPillField(
          controller: _controller,
          focusNode: _focusNode,
          hintText: widget.ownReviewsOnly
              ? 'Search your reviews'
              : 'Artist, track, album, genre…',
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          onClear: _clearSearch,
        ),
        actions: const [SizedBox(width: 12)],
      ),
      // Before typing: the latest reviews from music sites (searching all
      // reviews) or a prompt (your own). Typing swaps in the results.
      body: _submittedQuery.isEmpty
          ? widget.ownReviewsOnly
                ? const _EmptyPrompt(ownReviewsOnly: true)
                : const MusicNewsFeed(
                    emptyPrompt: _EmptyPrompt(ownReviewsOnly: false),
                  )
          // All reviews: everything that matches (reviews, music to review,
          // articles, tags). Your own: just your reviews.
          : !widget.ownReviewsOnly
          ? UnifiedSearchResults(query: _submittedQuery)
          : _SearchResults(
              query: _submittedQuery,
              ownReviewsOnly: widget.ownReviewsOnly,
            ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.ownReviewsOnly});

  final bool ownReviewsOnly;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            ownReviewsOnly
                ? 'Find your reviews by artist,\nsong, tag or anything you wrote'
                : 'Search reviews by artist,\ntrack, album, or genre',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  final bool ownReviewsOnly;
  const _SearchResults({required this.query, required this.ownReviewsOnly});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ownReviewsOnly
        ? ref.watch(myReviewsSearchProvider(query))
        : ref.watch(searchReviewsProvider(query));

    return resultsAsync.when(
      loading: () =>
          const Center(child: SizedBox(height: 200, child: DiscoBallLoading())),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Something went wrong.\nTry again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_off, size: 56, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    ownReviewsOnly
                        ? 'None of your reviews match\n"$query"'
                        : 'No reviews found for\n"$query"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                ownReviewsOnly
                    ? '${results.length} of your review${results.length == 1 ? '' : 's'}'
                    : '${results.length} result${results.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final item = results[index];
                  return Padding(
                    padding: AppSpacing.cardListItem,
                    child: ReviewCardWithGenres(
                      review: item.review,
                      reviewId: item.fullReviewId,
                      showLikeButton: true,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
