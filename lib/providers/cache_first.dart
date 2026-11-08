import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a page's data is kept after the page closes (or after it was
/// fetched ahead of a tap that never came), so going back is instant.
const Duration pageDataKeepAlive = Duration(minutes: 5);

extension KeepAliveFor on AutoDisposeRef<Object?> {
  /// Keeps this provider's data for [duration] once nothing is using it.
  /// Also covers a provider only read ahead of time ([ProviderContainer.read]
  /// with no listener yet), which would otherwise be dropped straight away.
  void keepAliveFor([Duration duration = pageDataKeepAlive]) {
    KeepAliveLink? link;
    Timer? timer;
    void hold() {
      timer?.cancel();
      link ??= keepAlive();
      timer = Timer(duration, () {
        link?.close();
        link = null;
      });
    }

    hold();
    onCancel(hold);
    onResume(() => timer?.cancel());
    onDispose(() => timer?.cancel());
  }
}

/// [query] from the on-device cache first, when it has at least [minCached]
/// results, then from the server. Shows something at once on a repeat
/// visit; the server copy replaces it a moment later. A failed server read
/// after a cached result keeps the cached one (e.g. offline).
Stream<QuerySnapshot<T>> cacheThenServer<T>(
  Query<T> query, {
  int minCached = 1,
}) async* {
  QuerySnapshot<T>? cached;
  try {
    cached = await query.get(const GetOptions(source: Source.cache));
  } catch (_) {
    // Nothing cached for this query (or no cache in this browser).
  }
  final showedCache = cached != null && cached.docs.length >= minCached;
  if (showedCache) yield cached;
  try {
    yield await query.get();
  } catch (e) {
    if (!showedCache) rethrow;
    debugPrint('Server read failed; keeping cached results: $e');
  }
}

/// [ref] from the on-device cache first, then the server (see
/// [cacheThenServer]).
Stream<DocumentSnapshot<T>> docCacheThenServer<T>(
    DocumentReference<T> ref) async* {
  DocumentSnapshot<T>? cached;
  try {
    cached = await ref.get(const GetOptions(source: Source.cache));
  } catch (_) {
    // Not cached.
  }
  final showedCache = cached != null && cached.exists;
  if (showedCache) yield cached;
  try {
    yield await ref.get();
  } catch (e) {
    if (!showedCache) rethrow;
    debugPrint('Server read failed; keeping cached copy: $e');
  }
}
