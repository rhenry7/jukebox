import 'package:cloud_firestore/cloud_firestore.dart';

/// User-created playlist model
class UserPlaylist {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final List<String> tags;
  final List<PlaylistTrack> tracks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? coverImageUrl; // First track's album art

  UserPlaylist({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.tags = const [],
    this.tracks = const [],
    required this.createdAt,
    required this.updatedAt,
    this.coverImageUrl,
  });

  /// Create from Firestore document
  factory UserPlaylist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse tracks with error handling
    List<PlaylistTrack> tracks = [];
    if (data['tracks'] != null && data['tracks'] is List) {
      try {
        tracks = (data['tracks'] as List<dynamic>)
            .map((t) {
              try {
                if (t is Map<String, dynamic>) {
                  return PlaylistTrack.fromMap(t);
                }
                print('⚠️ Track is not a Map: ${t.runtimeType}');
                return null;
              } catch (e) {
                print('⚠️ Error parsing track: $e');
                print('   Track data: $t');
                return null;
              }
            })
            .whereType<PlaylistTrack>()
            .toList();
      } catch (e) {
        print('❌ Error parsing tracks array: $e');
        print('   Tracks data: ${data['tracks']}');
      }
    }
    
    // Handle timestamps
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }
    
    DateTime updatedAt;
    if (data['updatedAt'] is Timestamp) {
      updatedAt = (data['updatedAt'] as Timestamp).toDate();
    } else {
      updatedAt = DateTime.now();
    }
    
    print('📦 [PLAYLIST] Parsing playlist: ${data['name']}');
    print('   Playlist ID: ${doc.id}');
    print('   Tracks count in data: ${data['tracks']?.length ?? 0}');
    print('   Parsed tracks count: ${tracks.length}');
    if (tracks.isNotEmpty) {
      print('   First track: ${tracks.first.title} by ${tracks.first.artist}');
    }
    
    return UserPlaylist(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? 'Untitled Playlist',
      description: data['description'] as String?,
      tags: List<String>.from(data['tags'] ?? []),
      tracks: tracks,
      createdAt: createdAt,
      updatedAt: updatedAt,
      coverImageUrl: data['coverImageUrl'] as String?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'tags': tags,
      'tracks': tracks.map((t) => t.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'coverImageUrl': coverImageUrl ?? (tracks.isNotEmpty ? tracks.first.imageUrl : null),
    };
  }

  /// Get track count
  int get trackCount => tracks.length;

  /// Get duration (if available)
  Duration? get duration {
    // Could calculate from track durations if we store them
    return null;
  }
}

/// Track in a user playlist
class PlaylistTrack {
  final String trackId; // Spotify track ID
  final String title;
  final String artist;
  final String? albumTitle;
  final String? imageUrl; // Album art URL
  final int? durationMs; // Duration in milliseconds
  final String? spotifyUri; // Spotify URI for playback
  final DateTime addedAt;

  PlaylistTrack({
    required this.trackId,
    required this.title,
    required this.artist,
    this.albumTitle,
    this.imageUrl,
    this.durationMs,
    this.spotifyUri,
    required this.addedAt,
  });

  /// Create from map
  factory PlaylistTrack.fromMap(Map<String, dynamic> map) {
    // Handle addedAt - could be Timestamp, DateTime, or null
    DateTime addedAt;
    if (map['addedAt'] == null) {
      addedAt = DateTime.now(); // Default to now if missing
    } else if (map['addedAt'] is Timestamp) {
      addedAt = (map['addedAt'] as Timestamp).toDate();
    } else if (map['addedAt'] is DateTime) {
      addedAt = map['addedAt'] as DateTime;
    } else {
      addedAt = DateTime.now(); // Fallback
    }

    return PlaylistTrack(
      trackId: map['trackId'] as String? ?? map['id'] as String? ?? '', // Support both 'trackId' and 'id'
      title: map['title'] as String? ?? 'Unknown',
      artist: map['artist'] as String? ?? 'Unknown',
      albumTitle: map['albumTitle'] as String?,
      imageUrl: map['imageUrl'] as String?,
      durationMs: map['durationMs'] as int?,
      spotifyUri: map['spotifyUri'] as String?,
      addedAt: addedAt,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'title': title,
      'artist': artist,
      'albumTitle': albumTitle,
      'imageUrl': imageUrl,
      'durationMs': durationMs,
      'spotifyUri': spotifyUri,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}
