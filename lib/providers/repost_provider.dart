import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/repost_service.dart';

typedef _RepostStatusKey = ({String reviewId, String userId});

final repostStatusProvider =
    StreamProvider.family<bool, _RepostStatusKey>((ref, key) {
  return RepostService().repostStatusStream(key.reviewId, key.userId);
});

final repostCountProvider =
    StreamProvider.family<int, String>((ref, reviewId) {
  return RepostService().repostCountStream(reviewId);
});
