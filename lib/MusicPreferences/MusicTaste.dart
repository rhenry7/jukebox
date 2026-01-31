import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/models/music_preferences.dart';

Future<MusicPreferences?> fetchMusicPreferences() async {
  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";
  try {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('musicPreferences')
        .doc('profile')
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null) {
        return MusicPreferences.fromJson(data);
      }
    }
    return null;
  } catch (e) {
    print('Error fetching music preferences: $e');
    return null;
  }
}

// Enhanced UserPreferences model with additional fields

// Track history model with enhanced metadata
class TrackHistory {
  final String trackId;
  final String trackName;
  final String artistName;
  final List<String> genres;
  final DateTime playedAt;
  final int listeningDuration; // in seconds
  final bool wasSkipped;
  final bool wasRepeated;
  final String context; // playlist, album, radio, etc.
  final Map<String, double>? audioFeatures; // from Spotify API

  TrackHistory({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    required this.genres,
    required this.playedAt,
    required this.listeningDuration,
    this.wasSkipped = false,
    this.wasRepeated = false,
    this.context = 'unknown',
    this.audioFeatures,
  });

  toJson() {
    return {
      'trackId': trackId,
      'trackName': trackName,
      'artistName': artistName,
      'genres': genres,
      'playedAt': playedAt.toIso8601String(),
      'listeningDuration': listeningDuration,
      'wasSkipped': wasSkipped,
      'wasRepeated': wasRepeated,
      'context': context,
      'audioFeatures': audioFeatures,
    };
  }

  static TrackHistory fromJson(Map<String, dynamic> json) {
    return TrackHistory(
      trackId: json['trackId'],
      trackName: json['trackName'],
      artistName: json['artistName'],
      genres: List<String>.from(json['genres']),
      playedAt: DateTime.parse(json['playedAt']),
      listeningDuration: json['listeningDuration'],
      wasSkipped: json['wasSkipped'] ?? false,
      wasRepeated: json['wasRepeated'] ?? false,
      context: json['context'] ?? 'unknown',
      audioFeatures: json['audioFeatures'] != null
          ? Map<String, double>.from(json['audioFeatures'])
          : null,
    );
  }
}

// Main taste profile collection widget
class MusicTasteProfileWidget extends StatefulWidget {
  final EnhancedUserPreferences? initialPreferences;
  final Function(EnhancedUserPreferences) onPreferencesChanged;

  final bool isOnboarding;

  const MusicTasteProfileWidget({
    Key? key,
    this.initialPreferences,
    required this.onPreferencesChanged,
    this.isOnboarding = false,
  }) : super(key: key);

  @override
  State<MusicTasteProfileWidget> createState() =>
      _MusicTasteProfileWidgetState();
}

class _MusicTasteProfileWidgetState extends State<MusicTasteProfileWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<EnhancedUserPreferences> _preferencesFuture;
  late EnhancedUserPreferences _preferences;
  bool _loadedPreferences = false;

  // Available options
  final List<String> _availableGenres = [
    'Rock',
    'Pop',
    'Hip-Hop',
    'Jazz',
    'Classical',
    'Electronic',
    'EDM',
    'Country',
    'Folk',
    'Blues',
    'Reggae',
    'Punk',
    'Metal',
    'Alternative',
    'Indie',
    'R&B',
    'Soul',
    'Funk',
    'Disco',
    'House',
    'Techno',
    'Trance',
    'Dubstep',
    'Ambient',
    'World',
    'Latin',
    'Acoustic',
    'Gospel'
  ];

  final List<String> _availableMoods = [
    'Energetic',
    'Chill',
    'Happy',
    'Melancholic',
    'Aggressive',
    'Peaceful',
    'Romantic',
    'Motivational',
    'Nostalgic',
    'Dreamy',
    'Dark',
    'Uplifting'
  ];

  final List<String> _tempoOptions = ['Slow', 'Medium', 'Fast'];

  final Map<String, List<String>> _contextualOptions = {
    'Workout': ['Cardio', 'Weight Training', 'Yoga', 'Running'],
    'Study/Focus': ['Deep Work', 'Reading', 'Background', 'Concentration'],
    'Social': ['Party', 'Dinner', 'Hanging Out', 'Dancing'],
    'Relaxation': ['Sleep', 'Meditation', 'Bath', 'Wind Down'],
    'Commute': ['Driving', 'Walking', 'Public Transport', 'Cycling'],
  };

  final String userId = FirebaseAuth.instance.currentUser != null
      ? FirebaseAuth.instance.currentUser!.uid
      : "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _preferencesFuture = _fetchPreferences();
    _preferencesFuture.then((prefs) {
      setState(() {
        _preferences = prefs;
      });
      if (widget.isOnboarding) {
        _updatePreferences();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updatePreferences() {
    widget.onPreferencesChanged(_preferences);
  }

  Future<void> _uploadPreferences() async {
    if (userId.isEmpty) {
      print("User not logged in, cannot upload preferences.");
      return;
    }

    final data = _preferences.toJson();
    data['lastUpdated'] = DateTime.now().toIso8601String();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('musicPreferences')
        .doc('profile')
        .set(data, SetOptions(merge: true));
  }

  Future<EnhancedUserPreferences> _fetchPreferences() async {
    if (userId.isEmpty) {
      print("User not logged in, cannot fetch preferences.");
      return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('musicPreferences')
        .doc('profile')
        .get();

    if (doc.exists) {
      _preferences = EnhancedUserPreferences.fromJson(doc.data()!);
      return _preferences;
    } else {
      return EnhancedUserPreferences(favoriteGenres: [], favoriteArtists: []);
    }
  }

  Future<void> handleSavePreferences() async {
    print(EnhancedUserPreferences.fromJson(_preferences.toJson()));
    try {
      await _uploadPreferences();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved successfully!')),
      );
    } catch (e) {
      log('Error saving preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save preferences.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EnhancedUserPreferences>(
      future: _preferencesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading preferences'));
        } else if (!snapshot.hasData) {
          return const Center(child: Text('No preferences found'));
        } else {
          // Assign loaded preferences if not already set
          if (_loadedPreferences) {
            _preferences = snapshot.data!;
            _loadedPreferences = true;
          }
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72.0),
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 8.0,
                    bottom: 16.0,
                  ),
                  alignment: Alignment.centerLeft,
                  color: Colors.transparent,
                  child: TabBar(
                    isScrollable: true,
                    controller: _tabController,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: Colors.red[600],
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 255, 9, 9)
                              .withAlpha(100),
                          blurRadius: 36.0,
                          spreadRadius: 10.0,
                          offset: const Offset(1.0, 5.0),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    tabs: const [
                      Tab(
                        child: Text(
                          'Genres',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Tab(
                        child: Text(
                          'Moods',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Tab(
                        child: Text(
                          'Tempo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Tab(
                        child: Text(
                          'Context',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildGenreSelection(),
                _buildMoodSelection(),
                _buildTempoSelection(),
                _buildContextualSelection(),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                _updatePreferences();
                handleSavePreferences();
              },
              backgroundColor: Colors.green,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          );
        }
      },
    );
  }

  Widget _buildGenreSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Genre Preferences',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ..._availableGenres.map((genre) {
            final preference = _preferences.genreWeights[genre] ?? 0.5;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          genre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getGenreRating(preference),
                          style: TextStyle(
                            color: _getGenreColor(preference),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: preference,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      activeColor: _getGenreColor(preference),
                      onChanged: (value) {
                        setState(() {
                          // Update genre weights
                          final newGenreWeights = Map<String, double>.from(
                              _preferences.genreWeights);
                          newGenreWeights[genre] = value;

                          // Update favorite genres list based on preference
                          List<String> newFavoriteGenres =
                              List.from(_preferences.favoriteGenres);
                          if (value >= 0.6 &&
                              !newFavoriteGenres.contains(genre)) {
                            newFavoriteGenres.add(genre);
                          } else if (value < 0.6 &&
                              newFavoriteGenres.contains(genre)) {
                            newFavoriteGenres.remove(genre);
                          }

                          // Update disliked genres list
                          List<String> newDislikedGenres =
                              List.from(_preferences.dislikedGenres);
                          if (value <= 0.3 &&
                              !newDislikedGenres.contains(genre)) {
                            newDislikedGenres.add(genre);
                          } else if (value > 0.3 &&
                              newDislikedGenres.contains(genre)) {
                            newDislikedGenres.remove(genre);
                          }

                          _preferences = _preferences.copyWith(
                            genreWeights: newGenreWeights,
                            favoriteGenres: newFavoriteGenres,
                            dislikedGenres: newDislikedGenres,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMoodSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mood Preferences',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Rate how much you enjoy different moods in music',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ..._availableMoods.map((mood) {
            final preference = _preferences.moodPreferences[mood] ?? 0.5;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mood,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getMoodRating(preference),
                          style: TextStyle(
                            color: _getMoodColor(preference),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: preference,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      activeColor: _getMoodColor(preference),
                      onChanged: (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            moodPreferences:
                                Map.from(_preferences.moodPreferences)
                                  ..[mood] = value,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTempoSelection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tempo Preferences',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'How much do you enjoy different tempos?',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _tempoOptions.length,
              itemBuilder: (context, index) {
                final tempo = _tempoOptions[index];
                final preference = _preferences.tempoPreferences[tempo] ?? 0.5;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tempo,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _getTempoDescription(tempo),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: preference,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          activeColor: Colors.red,
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(
                                tempoPreferences:
                                    Map.from(_preferences.tempoPreferences)
                                      ..[tempo] = value,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contextual Preferences',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'What genres do you prefer for different activities?',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ..._contextualOptions.entries.map((entry) {
            final context = entry.key;
            final subContexts = entry.value;
            final selectedGenres =
                _preferences.contextualPreferences[context] ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(
                  context,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  selectedGenres.isEmpty
                      ? 'No preferences set'
                      : '${selectedGenres.length} genres selected',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select preferred genres for this context:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _preferences.favoriteGenres.map((genre) {
                            final isSelected = selectedGenres.contains(genre);

                            return FilterChip(
                              label: Text(genre),
                              selected: isSelected,
                              selectedColor: Colors.deepPurple[100],
                              onSelected: (selected) {
                                setState(() {
                                  final newContextualPrefs =
                                      Map<String, List<String>>.from(
                                          _preferences.contextualPreferences);
                                  if (selected) {
                                    newContextualPrefs[context] =
                                        List.from(selectedGenres)..add(genre);
                                  } else {
                                    newContextualPrefs[context] =
                                        List.from(selectedGenres)
                                          ..remove(genre);
                                  }
                                  _preferences = _preferences.copyWith(
                                    contextualPreferences: newContextualPrefs,
                                  );
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getGenreRating(double value) {
    if (value < 0.2) return 'Not for me';
    if (value < 0.4) return 'Rarely';
    if (value < 0.6) return 'Sometimes';
    if (value < 0.8) return 'Often';
    return 'Love it!';
  }

  Color _getGenreColor(double value) {
    if (value < 0.2) return Colors.grey;
    if (value < 0.4) return Colors.orange.shade200;
    if (value < 0.6) return Colors.orange;
    if (value < 0.8) return Colors.deepOrangeAccent;
    return Colors.red;
  }

  String _getMoodRating(double value) {
    if (value < 0.2) return 'Not for me';
    if (value < 0.4) return 'Rarely';
    if (value < 0.6) return 'Sometimes';
    if (value < 0.8) return 'Often';
    return 'Love it!';
  }

  Color _getMoodColor(double value) {
    if (value < 0.2) return Colors.grey;
    if (value < 0.4) return Colors.orange.shade200;
    if (value < 0.6) return Colors.orange;
    if (value < 0.8) return Colors.deepOrangeAccent;
    return Colors.red;
  }

  String _getTempoDescription(String tempo) {
    switch (tempo) {
      case 'Slow':
        return 'Ballads, ambient, chill music';
      case 'Medium':
        return 'Most pop, rock, folk music';
      case 'Fast':
        return 'Dance, electronic, punk, metal';
      default:
        return '';
    }
  }
}

// Custom circular percentage indicator widget
class CircularPercentageIndicator extends StatelessWidget {
  final double radius;
  final double percent;
  final Color progressColor;
  final Color backgroundColor;
  final Widget? center;

  const CircularPercentageIndicator({
    Key? key,
    required this.radius,
    required this.percent,
    required this.progressColor,
    required this.backgroundColor,
    this.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: [
          SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: CircularProgressIndicator(
              value: percent,
              backgroundColor: backgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              strokeWidth: 4,
            ),
          ),
          if (center != null)
            Positioned.fill(
              child: Center(child: center!),
            ),
        ],
      ),
    );
  }
}
