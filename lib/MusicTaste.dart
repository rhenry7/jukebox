import 'package:flutter/material.dart';

// Enhanced UserPreferences model with additional fields
class EnhancedUserPreferences {
  final List<String> favoriteGenres;
  final List<String> favoriteArtists;
  final List<String> dislikedGenres;
  final Map<String, double> genreWeights; // 0.0 to 1.0 preference strength
  final List<TrackHistory> recentlyPlayed;
  final List<String> savedTracks;

  // New fields for enhanced recommendations
  final Map<String, double>
      audioFeatureProfile; // danceability, energy, valence, etc.
  final Map<String, double>
      moodPreferences; // chill, energetic, focus, party, etc.
  final Map<String, double> tempoPreferences; // slow, medium, fast
  final Map<String, List<String>>
      contextualPreferences; // workout, study, sleep, etc.
  final DateTime lastUpdated;
  final int totalListeningTime; // in minutes
  final Map<String, int> skipCounts; // track skip frequency
  final Map<String, int> repeatCounts; // track repeat frequency

  EnhancedUserPreferences({
    required this.favoriteGenres,
    required this.favoriteArtists,
    this.dislikedGenres = const [],
    this.genreWeights = const {},
    this.recentlyPlayed = const [],
    this.savedTracks = const [],
    this.audioFeatureProfile = const {},
    this.moodPreferences = const {},
    this.tempoPreferences = const {},
    this.contextualPreferences = const {},
    DateTime? lastUpdated,
    this.totalListeningTime = 0,
    this.skipCounts = const {},
    this.repeatCounts = const {},
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  EnhancedUserPreferences copyWith({
    List<String>? favoriteGenres,
    List<String>? favoriteArtists,
    List<String>? dislikedGenres,
    Map<String, double>? genreWeights,
    List<TrackHistory>? recentlyPlayed,
    List<String>? savedTracks,
    Map<String, double>? audioFeatureProfile,
    Map<String, double>? moodPreferences,
    Map<String, double>? tempoPreferences,
    Map<String, List<String>>? contextualPreferences,
    DateTime? lastUpdated,
    int? totalListeningTime,
    Map<String, int>? skipCounts,
    Map<String, int>? repeatCounts,
  }) {
    return EnhancedUserPreferences(
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      favoriteArtists: favoriteArtists ?? this.favoriteArtists,
      dislikedGenres: dislikedGenres ?? this.dislikedGenres,
      genreWeights: genreWeights ?? this.genreWeights,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      savedTracks: savedTracks ?? this.savedTracks,
      audioFeatureProfile: audioFeatureProfile ?? this.audioFeatureProfile,
      moodPreferences: moodPreferences ?? this.moodPreferences,
      tempoPreferences: tempoPreferences ?? this.tempoPreferences,
      contextualPreferences:
          contextualPreferences ?? this.contextualPreferences,
      lastUpdated: lastUpdated ?? DateTime.now(),
      totalListeningTime: totalListeningTime ?? this.totalListeningTime,
      skipCounts: skipCounts ?? this.skipCounts,
      repeatCounts: repeatCounts ?? this.repeatCounts,
    );
  }
}

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
  late EnhancedUserPreferences _preferences;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _preferences = widget.initialPreferences ??
        EnhancedUserPreferences(
          favoriteGenres: [],
          favoriteArtists: [],
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updatePreferences() {
    widget.onPreferencesChanged(_preferences);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.transparent,
            child: TabBar(
              isScrollable: true,
              controller: _tabController,
              padding: const EdgeInsets.only(
                  left: 2.0), // Control how close to left edge

              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicator: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(25), // Creates pill-shaped indicator
                color: Colors.red[600], // Background color of the selected tab
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 255, 9, 9).withAlpha(100),
                    blurRadius: 36.0,
                    spreadRadius: 10.0,
                    offset: const Offset(
                      1.0,
                      5.0,
                    ),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Genres',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Moods',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Tempo',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 0.0), // Padding around text
                    child: Text(
                      'Context',
                      style: TextStyle(color: Colors.white),
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
        onPressed: _updatePreferences,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text('Save', style: TextStyle(color: Colors.white)),
      ),
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
