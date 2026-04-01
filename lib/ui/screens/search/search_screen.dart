import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/GIFs/gifs.dart';
import 'package:flutter_test_project/providers/search_reviews_provider.dart';
import 'package:flutter_test_project/ui/screens/Home/_comments.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

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
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.red,
          decoration: InputDecoration(
            hintText: 'Artist, track, album, genre...',
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
        ),
      ),
      body: _submittedQuery.isEmpty
          ? _EmptyPrompt()
          : _SearchResults(query: _submittedQuery),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Search reviews by artist,\ntrack, album, or genre',
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
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchReviewsProvider(query));

    return resultsAsync.when(
      loading: () => const Center(
        child: SizedBox(
          height: 200,
          child: DiscoBallLoading(),
        ),
      ),
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
                    'No reviews found for\n"$query"',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 15),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                '${results.length} result${results.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final item = results[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.all(5),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      side: BorderSide(
                          color: Color.fromARGB(56, 158, 158, 158)),
                    ),
                    color: Colors.white10,
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
