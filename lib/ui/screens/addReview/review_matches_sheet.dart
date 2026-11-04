import 'package:flutter/material.dart';

import '../../../GIFs/gifs.dart';
import '../../../services/for_you_service.dart' show ReviewMatch;
import '../../../services/tag_match_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_states.dart';
import '../../widgets/reason_label.dart';
import '../../widgets/review_card.dart';

/// Shown right after posting a review: other people's reviews whose tags
/// overlap the tags on the review the user just wrote.
Future<void> showReviewMatchesSheet(
  BuildContext context, {
  required String reviewPath,
  required String reviewedTitle,
  required String reviewedArtist,
  required List<String> tags,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _ReviewMatchesSheet(
      matches: TagMatchService.matchesFor(
        reviewPath: reviewPath,
        tags: tags,
        title: reviewedTitle,
        artist: reviewedArtist,
      ),
      reviewedTitle: reviewedTitle,
    ),
  );
}

class _ReviewMatchesSheet extends StatelessWidget {
  const _ReviewMatchesSheet(
      {required this.matches, required this.reviewedTitle});

  final Future<List<ReviewMatch>> matches;
  final String reviewedTitle;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Because you just reviewed $reviewedTitle',
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ReviewMatch>>(
                future: matches,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const DiscoBallLoading();
                  }
                  final list = snapshot.data ?? const <ReviewMatch>[];
                  if (list.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.auto_awesome,
                      title: 'No matching reviews yet',
                      message:
                          'Nobody else has tagged recent reviews the same way yet.',
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final match = list[index];
                      return Padding(
                        padding: AppSpacing.cardListItem,
                        child: WithReason(
                          reason: match.reason,
                          child: ReviewCardWithGenres(
                            review: match.review.review,
                            reviewId: match.review.fullReviewId,
                            showLikeButton: true,
                          ),
                        ),
                      );
                    },
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
