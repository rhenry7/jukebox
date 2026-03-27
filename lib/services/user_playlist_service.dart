import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test_project/models/user_playlist.dart';

/// Service for managing user-created playlists in Firestore
class UserPlaylistService {
  static const String _collectionName = 'playlists';

  /// Get all playlists for a user
  static Stream<List<UserPlaylist>> getUserPlaylists(String userId) {
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(UserPlaylist.fromFirestore)
            .toList());
  }

  /// Get all playlists from all users (Community tab)
  static Stream<List<UserPlaylist>> getAllPlaylists({int limit = 40}) {
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(UserPlaylist.fromFirestore).toList());
  }

  /// Get playlists by a list of user IDs (Friends tab)
  /// Uses Firestore whereIn (max 30 per query), batches if needed.
  static Stream<List<UserPlaylist>> getPlaylistsByUserIds(
      List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);

    // Firestore whereIn supports max 30 items
    const batchSize = 30;
    final batches = <List<String>>[];
    for (var i = 0; i < userIds.length; i += batchSize) {
      batches.add(userIds.sublist(
          i, i + batchSize > userIds.length ? userIds.length : i + batchSize));
    }

    final streams = batches.map((batch) {
      return FirebaseFirestore.instance
          .collection(_collectionName)
          .where('userId', whereIn: batch)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map(UserPlaylist.fromFirestore).toList());
    }).toList();

    return _combinePlaylistStreams(streams);
  }

  /// Merges multiple playlist streams and sorts by updatedAt desc.
  static Stream<List<UserPlaylist>> _combinePlaylistStreams(
      List<Stream<List<UserPlaylist>>> streams) {
    if (streams.isEmpty) return Stream.value([]);
    if (streams.length == 1) return streams.first;

    final latestValues = <int, List<UserPlaylist>>{};

    return Stream.multi((controller) {
      final subscriptions = <int, StreamSubscription<List<UserPlaylist>>>{};

      for (var i = 0; i < streams.length; i++) {
        final index = i;
        subscriptions[index] = streams[index].listen(
          (playlists) {
            latestValues[index] = playlists;
            final all = latestValues.values.expand((list) => list).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            controller.add(all);
          },
          onError: (e) => debugPrint('Playlist stream error: $e'),
        );
      }

      controller.onCancel = () {
        for (final sub in subscriptions.values) {
          sub.cancel();
        }
      };
    });
  }

  /// Get a single playlist by ID
  static Future<UserPlaylist?> getPlaylist(String playlistId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(playlistId)
          .get();

      if (doc.exists) {
        return UserPlaylist.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting playlist: $e');
      return null;
    }
  }

  /// Get a single playlist by ID as a stream (for real-time updates)
  static Stream<UserPlaylist?> getPlaylistStream(String playlistId) {
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .doc(playlistId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        try {
          return UserPlaylist.fromFirestore(doc);
        } catch (e) {
          debugPrint('❌ Error parsing playlist from Firestore: $e');
          debugPrint('   Document data: ${doc.data()}');
          return null;
        }
      }
      return null;
    });
  }

  /// Create a new playlist
  static Future<String> createPlaylist({
    required String userId,
    required String name,
    String? description,
    List<String>? tags,
  }) async {
    try {
      // Validate inputs
      if (userId.isEmpty) {
        throw Exception('UserId cannot be empty');
      }
      if (name.trim().isEmpty) {
        throw Exception('Playlist name cannot be empty');
      }

      // Build playlist data, omitting null values
      final playlistData = <String, dynamic>{
        'userId': userId, // Ensure userId is set as string
        'name': name.trim(),
        'tags': tags ?? [],
        'tracks': <Map<String, dynamic>>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Only add description if it's not null/empty
      if (description != null && description.trim().isNotEmpty) {
        playlistData['description'] = description.trim();
      }
      
      // Only add coverImageUrl if we have tracks (which we don't at creation)
      // So we'll omit it for now

      debugPrint('📝 [PLAYLIST SERVICE] Creating playlist with data:');
      debugPrint('   userId: $userId');
      debugPrint('   userId type: ${userId.runtimeType}');
      debugPrint('   name: ${playlistData['name']}');
      debugPrint('   collection: $_collectionName');
      debugPrint('   data keys: ${playlistData.keys.toList()}');
      debugPrint('   data: $playlistData');

      final docRef = await FirebaseFirestore.instance
          .collection(_collectionName)
          .add(playlistData);

      debugPrint('✅ Playlist created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating playlist: $e');
      rethrow;
    }
  }

  /// Update playlist metadata (name, description, tags)
  static Future<void> updatePlaylistMetadata({
    required String playlistId,
    String? name,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (tags != null) updates['tags'] = tags;

      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(playlistId)
          .update(updates);
    } catch (e) {
      debugPrint('Error updating playlist metadata: $e');
      rethrow;
    }
  }

  /// Add a track to a playlist
  static Future<void> addTrackToPlaylist({
    required String playlistId,
    required PlaylistTrack track,
  }) async {
    try {
      final playlistRef = FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(playlistId);

      // Get current playlist
      final playlistDoc = await playlistRef.get();
      if (!playlistDoc.exists) {
        throw Exception('Playlist not found');
      }

      final playlist = UserPlaylist.fromFirestore(playlistDoc);
      
      // Check if track already exists
      final trackExists = playlist.tracks.any((t) => t.trackId == track.trackId);
      if (trackExists) {
        throw Exception('Track already in playlist');
      }

      // Add track to list
      final updatedTracks = [...playlist.tracks, track];

      // Update cover image if this is the first track
      final coverImageUrl = playlist.coverImageUrl ?? track.imageUrl;

      // Convert tracks to maps for Firestore
      final tracksData = updatedTracks.map((t) {
        final map = t.toMap();
        debugPrint('📝 Saving track: ${map['title']} by ${map['artist']}');
        debugPrint('   trackId: ${map['trackId']}');
        debugPrint('   imageUrl: ${map['imageUrl']}');
        return map;
      }).toList();

      debugPrint('💾 Updating playlist with ${tracksData.length} tracks');
      
      await playlistRef.update({
        'tracks': tracksData,
        'coverImageUrl': coverImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Playlist updated successfully');
    } catch (e) {
      debugPrint('Error adding track to playlist: $e');
      rethrow;
    }
  }

  /// Remove a track from a playlist
  static Future<void> removeTrackFromPlaylist({
    required String playlistId,
    required String trackId,
  }) async {
    try {
      final playlistRef = FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(playlistId);

      final playlistDoc = await playlistRef.get();
      if (!playlistDoc.exists) {
        throw Exception('Playlist not found');
      }

      final playlist = UserPlaylist.fromFirestore(playlistDoc);
      final updatedTracks = playlist.tracks.where((t) => t.trackId != trackId).toList();

      // Update cover image if we removed the first track
      final coverImageUrl = updatedTracks.isNotEmpty ? updatedTracks.first.imageUrl : null;

      await playlistRef.update({
        'tracks': updatedTracks.map((t) => t.toMap()).toList(),
        'coverImageUrl': coverImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error removing track from playlist: $e');
      rethrow;
    }
  }

  /// Reorder tracks in a playlist
  static Future<void> reorderTracks({
    required String playlistId,
    required List<PlaylistTrack> tracks,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(playlistId)
          .update({
        'tracks': tracks.map((t) => t.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error reordering tracks: $e');
      rethrow;
    }
  }

  /// Get playlists by a list of document IDs (e.g. liked playlists).
  /// Streams real-time updates; batches if more than 30 IDs.
  static Stream<List<UserPlaylist>> getPlaylistsByIds(List<String> ids) {
    if (ids.isEmpty) return Stream.value([]);
    final limited = ids.take(30).toList();
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .where(FieldPath.documentId, whereIn: limited)
        .snapshots()
        .map((snap) => snap.docs.map(UserPlaylist.fromFirestore).toList());
  }

  /// Delete a playlist
  static Future<void> deletePlaylist(String playlistId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(playlistId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting playlist: $e');
      rethrow;
    }
  }
}
