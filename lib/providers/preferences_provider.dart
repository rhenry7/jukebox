import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/providers/auth_provider.dart';

/// User's music preferences - automatically updates when preferences change
final userPreferencesProvider = FutureProvider<EnhancedUserPreferences>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
  }
  
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .get();
      
  if (!doc.exists || doc.data() == null) {
    return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
  }
  
  try {
    return EnhancedUserPreferences.fromJson(doc.data()!);
  } catch (e) {
    print('Error parsing preferences: $e');
    return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
  }
});

/// Stream version of preferences for real-time updates
final userPreferencesStreamProvider = StreamProvider<EnhancedUserPreferences>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return Stream.value(EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []));
  }
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('musicPreferences')
      .doc('profile')
      .snapshots()
      .map((doc) {
        if (!doc.exists || doc.data() == null) {
          return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
        }
        try {
          return EnhancedUserPreferences.fromJson(doc.data()!);
        } catch (e) {
          print('Error parsing preferences: $e');
          return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
        }
      });
});
