import 'dart:async';
import 'package:flutter/foundation.dart';

/// Executes [action] with exponential back-off when a Spotify 429 (rate-limit)
/// error is detected.
///
/// - [maxRetries] – total retry attempts (default 3).
/// - [initialDelay] – wait before first retry (doubled on each subsequent retry).
///
/// The function inspects the stringified exception for `429` or `rate limit`.
/// If the last attempt still fails the exception is rethrown to the caller.
Future<T> withSpotifyRetry<T>(
  Future<T> Function() action, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 2),
}) async {
  int attempt = 0;
  Duration delay = initialDelay;

  while (true) {
    try {
      return await action();
    } catch (e) {
      attempt++;
      final errorStr = e.toString().toLowerCase();
      final isRateLimit =
          errorStr.contains('429') || errorStr.contains('rate limit');

      if (!isRateLimit || attempt >= maxRetries) {
        rethrow;
      }

      debugPrint(
          '⏳ Spotify 429 – retry $attempt/$maxRetries in ${delay.inSeconds}s');
      await Future.delayed(delay);
      delay *= 2; // exponential back-off
    }
  }
}
