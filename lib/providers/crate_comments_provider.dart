import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/crate_comment.dart';
import 'package:flutter_test_project/services/crate_comment_service.dart';

/// Real-time stream of comments for a given playlist/crate ID.
final crateCommentsProvider =
    StreamProvider.autoDispose.family<List<CrateComment>, String>((ref, playlistId) {
  return CrateCommentService.commentsStream(playlistId);
});
