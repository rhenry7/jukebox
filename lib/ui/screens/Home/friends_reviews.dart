import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/friends_provider.dart';
import '../../../providers/reviews_provider.dart' show ReviewWithDocId;
import '../../widgets/skeleton_loader.dart';
import '../Profile/ProfileSignIn.dart';
import '_comments.dart' show ReviewCardWithGenres;

/// Friends reviews feed – shows reviews from users the current user has added
/// as friends. Mirrors the layout and UX of [CommunityReviewsCollection].
class FriendsReviewsCollection extends ConsumerWidget {
  const FriendsReviewsCollection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // Not signed in
    if (userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Sign In Required',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to see reviews from your friends!',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const SignInScreen()),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign In!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final friendsReviewsAsync = ref.watch(friendsReviewsProvider);
    final friendIdsAsync = ref.watch(friendIdsProvider);
    final friendIds = friendIdsAsync.value ?? [];

    // No friends added yet — prompt
    if (friendIds.isEmpty && !friendIdsAsync.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No friends yet',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 8),
              const Text(
                'Head to the Community tab and tap on a reviewer\'s name to add them as a friend!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Switch to the Community tab (index 1 inside CategoryTapBar)
                  DefaultTabController.of(context).animateTo(1);
                },
                icon: const Icon(Icons.public),
                label: const Text('Go to Community'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return friendsReviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Your ${friendIds.length} friend${friendIds.length == 1 ? " hasn\'t" : "s haven\'t"} posted any reviews yet',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(friendsReviewsProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: Colors.red[600],
          child: Column(
            children: [
              const Gap(10),
              Expanded(
                child: _FriendsReviewList(reviews: reviews),
              ),
            ],
          ),
        );
      },
      loading: () => ListView.builder(
        itemCount: 3,
        itemBuilder: (_, __) => const ReviewCardSkeleton(),
      ),
      error: (error, _) {
        debugPrint('Error loading friends reviews: $error');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading friends\' reviews',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(friendsReviewsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Simple list of friend reviews reusing the existing review card widgets.
class _FriendsReviewList extends StatelessWidget {
  final List<ReviewWithDocId> reviews;
  const _FriendsReviewList({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const PageStorageKey('friends_reviews_list'),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Card(
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              side: BorderSide(color: Color.fromARGB(56, 158, 158, 158)),
            ),
            color: Colors.white10,
            child: ReviewCardWithGenres(
              review: review.review,
              reviewId: review.fullReviewId,
              showLikeButton: true,
            ),
          ),
        );
      },
    );
  }
}
