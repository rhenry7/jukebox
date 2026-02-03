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
