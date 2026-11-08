import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart' show currentUserIdProvider;
import '../../../providers/friends_provider.dart';
import '../../../providers/home_feed_controls.dart';
import '../Profile/helpers/profileHelpers.dart' show openSignIn;
import 'package:flutter_test_project/ui/widgets/app_states.dart';
import 'package:flutter_test_project/ui/widgets/home_feed_controls.dart'
    show NoTagMatches;
import 'package:flutter_test_project/ui/widgets/review_feed.dart';

/// Friends reviews feed – shows reviews from users the current user has added
/// as friends, newest first. Mirrors the layout and UX of
/// [CommunityReviewsCollection]. The Home row's tag filter and sort apply
/// to the friends' reviews already loaded (all of them).
class FriendsReviewsCollection extends ConsumerWidget {
  const FriendsReviewsCollection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    // Not signed in
    if (userId == null) {
      return AppEmptyState(
        icon: Icons.person_off,
        title: 'Sign In Required',
        message: 'Sign in to see reviews from your friends!',
        action: AppStateAction(
          label: 'Sign In!',
          icon: Icons.login,
          onPressed: () {
            openSignIn(context);
          },
        ),
      );
    }

    final friendsReviewsAsync = ref.watch(friendsReviewsProvider);
    final friendIdsAsync = ref.watch(friendIdsProvider);
    final friendIds = friendIdsAsync.valueOrNull ?? [];

    // No friends added yet — prompt
    if (friendIds.isEmpty && !friendIdsAsync.isLoading) {
      return AppEmptyState(
        icon: Icons.people_outline,
        title: 'No friends yet',
        message:
            'Head to the Popular tab and tap on a reviewer\'s name to add them as a friend!',
        action: AppStateAction(
          label: 'Go to Popular',
          icon: Icons.public,
          // Popular is the first tab in CategoryTapBar.
          onPressed: () => DefaultTabController.of(context).animateTo(0),
        ),
      );
    }

    final tags = ref.watch(homeTagFilterProvider);
    final sort = ref.watch(homeSortProvider);

    return friendsReviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return AppEmptyState(
            icon: Icons.music_note,
            title:
                'Your ${friendIds.length} friend${friendIds.length == 1 ? " hasn't" : "s haven't"} posted any reviews yet',
          );
        }

        final shown = applyHomeSort(
          [
            for (final r in reviews)
              if (matchesTagFilter(r.review, tags)) r,
          ],
          sort,
          (r) => r.review,
        );
        if (shown.isEmpty) return const NoTagMatches();

        return ReviewFeed(
          storageKey: tags.isEmpty
              ? 'friends_reviews_list'
              : 'friends_filtered_list',
          reviews: shown,
          onRefresh: () async {
            ref.invalidate(friendsReviewsProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
        );
      },
      loading: () => const ReviewFeedSkeleton(),
      error: (error, _) {
        debugPrint('Error loading friends reviews: $error');
        return AppErrorState(
          title: 'Error loading friends\' reviews',
          onRetry: () => ref.invalidate(friendsReviewsProvider),
        );
      },
    );
  }
}
