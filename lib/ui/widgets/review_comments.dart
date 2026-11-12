import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/review.dart';
import '../../models/review_comment.dart';
import '../../providers/auth_provider.dart'
    show currentUserIdProvider, currentUserProvider, isAnonymousUserProvider;
import '../../providers/review_comments_provider.dart';
import '../../services/review_comments_service.dart';
import '../../utils/helpers.dart';
import '../theme/tokens.dart';
import 'auth_gate_modal.dart';
import 'app_toast.dart';
import 'glass.dart';

/// Shared comment UI for a review: the list, a single comment, the input,
/// and the bottom sheet opened from the comment button on review cards.

/// Opens the comments for [review] in a bottom sheet: everyone's comments
/// plus an input to add one. Anonymous users can read but get the sign-in
/// prompt when they try to write.
Future<void> showReviewCommentsSheet(
  BuildContext context, {
  required Review review,
  required String reviewId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The glass surface below paints the sheet's background.
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      // Lift the sheet above the keyboard while typing.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _GlassSheetSurface(
        child: _ReviewCommentsSheet(review: review, reviewId: reviewId),
      ),
    ),
  );
}

/// Frosted-glass sheet background: a [GlassSurface] panel with the sheet's
/// rounded top.
class _GlassSheetSurface extends StatelessWidget {
  const _GlassSheetSurface({required this.child});

  final Widget child;

  static const _radius =
      BorderRadius.vertical(top: Radius.circular(AppRadius.xl));

  @override
  Widget build(BuildContext context) {
    return GlassSurface(borderRadius: _radius, child: child);
  }
}

class _ReviewCommentsSheet extends ConsumerWidget {
  const _ReviewCommentsSheet({required this.review, required this.reviewId});

  final Review review;
  final String reviewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(reviewCommentsProvider(reviewId));
    final comments = commentsAsync.valueOrNull ?? const <ReviewComment>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: AppRadius.pillAll,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comments (${comments.length})',
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: commentsAsync.isLoading && comments.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  : comments.isEmpty
                      ? ListView(
                          controller: scrollController,
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                              child: Center(
                                child: Text(
                                  'No comments yet. Be the first.',
                                  style: TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pageGutter,
                          ),
                          itemCount: comments.length,
                          itemBuilder: (context, i) => CommentTile(
                            comment: comments[i],
                            reviewId: reviewId,
                          ),
                        ),
            ),
            CommentComposer(review: review, reviewId: reviewId),
          ],
        );
      },
    );
  }
}

/// The comment box: a floating frosted-glass card. At rest it's a one-line
/// "Write a comment..." field; tapped, it shows "Comment on <song>" and
/// grows to 5 lines as you type. Callers place it just above the keyboard
/// (`MediaQuery.viewInsets`), so what you type stays visible.
class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({
    super.key,
    required this.review,
    required this.reviewId,
  });

  final Review review;
  final String? reviewId;

  /// Height of the card at rest, plus its margin: space to leave below
  /// content it floats over.
  static const double restingHeight = 84;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  /// Extra space under the text while the box is open.
  static const double _openExtraSpace = 29;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    _controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    if (ref.read(isAnonymousUserProvider)) {
      showAuthGateModal(context);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null || widget.reviewId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ReviewCommentsService().addComment(
        reviewId: widget.reviewId!,
        userId: user.uid,
        displayName: user.displayName?.isNotEmpty == true
            ? user.displayName!
            : 'Anonymous',
        text: text,
        reviewOwnerUserId: widget.review.userId,
        reviewTitle: widget.review.title,
        reviewArtist: widget.review.artist,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        debugPrint('Comment failed: $e');
        showAppToast(context, "Couldn't post your comment. Try again.", tone: ToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnon = ref.watch(isAnonymousUserProvider);
    final open = _focus.hasFocus || _controller.text.isNotEmpty;
    final canSend = _controller.text.trim().isNotEmpty && !_isSubmitting;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
          shadow: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (open)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(
                          text: 'Comment on ',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: widget.review.title,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: isAnon ? () => showAuthGateModal(context) : null,
                        child: AbsorbPointer(
                          absorbing: isAnon,
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            minLines: 1,
                            // Grows with the text up to 5 lines, then scrolls.
                            maxLines: open ? 5 : 1,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            scrollPadding: EdgeInsets.zero,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15, height: 1.4),
                            decoration: InputDecoration(
                              hintText: isAnon
                                  ? 'Sign in to comment...'
                                  : 'Write a comment...',
                              hintStyle: const TextStyle(
                                  color: Colors.white54, fontSize: 15),
                              border: InputBorder.none,
                              isDense: true,
                              // Open: extra room under the text (~70% more
                              // typing area) so it reads as a place to write.
                              contentPadding: EdgeInsets.only(
                                top: AppSpacing.sm + 2,
                                bottom: open
                                    ? AppSpacing.sm + 2 + _openExtraSpace
                                    : AppSpacing.sm + 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Semantics(
                      button: true,
                      label: 'Post comment',
                      enabled: canSend,
                      child: GestureDetector(
                        onTap: canSend ? _submit : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: canSend || _isSubmitting
                                ? Colors.white
                                : Colors.white24,
                          ),
                          child: _isSubmitting
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black),
                                )
                              : Icon(Ionicons.arrowUp,
                                  color: canSend ? Colors.black : Colors.white54,
                                  size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One comment with like / edit / delete actions.
class CommentTile extends ConsumerStatefulWidget {
  final ReviewComment comment;
  final String reviewId;
  const CommentTile({super.key, required this.comment, required this.reviewId});

  @override
  ConsumerState<CommentTile> createState() => CommentTileState();
}

class CommentTileState extends ConsumerState<CommentTile> {
  bool _isEditing = false;
  bool _isSaving = false;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.comment.text);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _saveEdit(String currentUserId) async {
    final trimmed = _editController.text.trim();
    if (trimmed.isEmpty || trimmed == widget.comment.text) {
      setState(() => _isEditing = false);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ReviewCommentsService().updateComment(
        reviewId: widget.reviewId,
        commentId: widget.comment.id,
        userId: currentUserId,
        newText: trimmed,
      );
      if (mounted) setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        debugPrint('Comment edit failed: $e');
        showAppToast(context, "Couldn't save your edit. Try again.", tone: ToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isAnon = ref.watch(isAnonymousUserProvider);
    final isOwn = widget.comment.userId == currentUserId;

    final likeKey = (
      reviewId: widget.reviewId,
      commentId: widget.comment.id,
      userId: currentUserId ?? '',
    );
    final isLiked = currentUserId != null
        ? ref.watch(commentLikeStatusProvider(likeKey)).valueOrNull ?? false
        : false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[850],
            ),
            child: const Icon(Icons.person, size: 18, color: Colors.white38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time
                Row(
                  children: [
                    Text(
                      widget.comment.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.comment.createdAt != null)
                      Text(
                        formatRelativeTime(widget.comment.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // ── Comment body OR inline edit field ────────────────────
                if (_isEditing) ...[
                  TextField(
                    controller: _editController,
                    autofocus: true,
                    maxLines: null,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.45),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF201F1F),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _isSaving
                            ? null
                            : () => _saveEdit(currentUserId!),
                        child: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.white54),
                              )
                            : const Text(
                                'SAVE',
                                style: TextStyle(
                                  color: Color(0xFF3FFF8B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () {
                          _editController.text = widget.comment.text;
                          setState(() => _isEditing = false);
                        },
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    widget.comment.text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Like + Reply + Edit + Delete actions
                  Row(
                    children: [
                      // Like
                      GestureDetector(
                        onTap: () async {
                          if (isAnon) {
                            showAuthGateModal(context);
                            return;
                          }
                          if (currentUserId == null) return;
                          try {
                            await ReviewCommentsService().toggleCommentLike(
                              reviewId: widget.reviewId,
                              commentId: widget.comment.id,
                              userId: currentUserId,
                            );
                          } catch (_) {}
                        },
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 15,
                              color: isLiked
                                  ? const Color(0xFFEE2309)
                                  : Colors.white38,
                            ),
                            if (widget.comment.likes > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${widget.comment.likes}',
                                style: TextStyle(
                                  color: isLiked
                                      ? const Color(0xFFEE2309)
                                      : Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Reply
                      GestureDetector(
                        onTap: () {
                          if (isAnon) {
                            showAuthGateModal(context);
                            return;
                          }
                          // TODO: reply threading
                        },
                        child: const Text(
                          'REPLY',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      // Edit + Delete (own comments only)
                      if (isOwn) ...[
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () => setState(() => _isEditing = true),
                          child: const Text(
                            'EDIT',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () async {
                            try {
                              await ReviewCommentsService().deleteComment(
                                reviewId: widget.reviewId,
                                commentId: widget.comment.id,
                                userId: currentUserId!,
                              );
                            } catch (_) {}
                          },
                          child: const Text(
                            'DELETE',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
