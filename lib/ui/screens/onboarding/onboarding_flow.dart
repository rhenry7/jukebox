import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify/spotify.dart' as sp;

import 'package:flutter_test_project/Api/api_key.dart';
import 'package:flutter_test_project/models/enhanced_user_preferences.dart';
import 'package:flutter_test_project/routing/MainNavigation.dart';
import 'package:flutter_test_project/services/review_recommendation_service.dart';
import 'package:flutter_test_project/utils/cached_image.dart';
import 'package:flutter_test_project/utils/spotify_retry.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _bg = Color(0xFF0E0E0E);
const _surface = Color(0xFF1A1919);
const _surfaceHigh = Color(0xFF201F1F);
const _primary = Color(0xFFEE2309);
const _secondary = Color(0xFF3FFF8B);
const _onSurfaceVariant = Color(0xFFADAAAA);
const _outlineVariant = Color(0xFF494847);

// ─── Data models ──────────────────────────────────────────────────────────────

class _ArtistItem {
  final String name;
  final String? imageUrl;
  const _ArtistItem({required this.name, this.imageUrl});
}

class _AlbumItem {
  final String name;
  final String artist;
  final String? imageUrl;
  const _AlbumItem({required this.name, required this.artist, this.imageUrl});
}

// ─── Spotify helpers ──────────────────────────────────────────────────────────

sp.SpotifyApi _buildSpotifyApi() =>
    sp.SpotifyApi(sp.SpotifyApiCredentials(clientId, clientSecret));

/// Fetch the top Spotify image URL for an artist name.
Future<String?> _fetchArtistImageUrl(sp.SpotifyApi api, String name) async {
  try {
    final pages = await withSpotifyRetry(
      () => api.search.get(name, types: [sp.SearchType.artist]).first(1),
    );
    for (final page in pages) {
      for (final item in page.items ?? []) {
        if (item is sp.Artist && item.images?.isNotEmpty == true) {
          return item.images!.first.url;
        }
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Fetch the top Spotify album art URL for a name + artist pair.
Future<String?> _fetchAlbumArtUrl(
    sp.SpotifyApi api, String albumName, String artistName) async {
  try {
    final query = '$albumName $artistName';
    final pages = await withSpotifyRetry(
      () => api.search.get(query, types: [sp.SearchType.album]).first(1),
    );
    for (final page in pages) {
      for (final item in page.items ?? []) {
        if (item is sp.AlbumSimple && item.images?.isNotEmpty == true) {
          return item.images!.first.url;
        }
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Search artists on Spotify (used for the search bar).
Future<List<_ArtistItem>> _searchArtistsSpotify(String query) async {
  try {
    final api = _buildSpotifyApi();
    final pages = await withSpotifyRetry(
      () => api.search.get(query, types: [sp.SearchType.artist]).first(12),
    );
    final artists = <_ArtistItem>[];
    for (final page in pages) {
      for (final item in page.items ?? []) {
        if (item is sp.Artist && item.name != null) {
          final url =
              (item.images?.isNotEmpty == true) ? item.images!.first.url : null;
          artists.add(_ArtistItem(name: item.name!, imageUrl: url));
        }
      }
    }
    return artists;
  } catch (e) {
    debugPrint('[Onboarding] Artist search error: $e');
    return [];
  }
}

/// Search albums on Spotify (used for the search bar).
Future<List<_AlbumItem>> _searchAlbumsSpotify(String query) async {
  try {
    final api = _buildSpotifyApi();
    final pages = await withSpotifyRetry(
      () => api.search.get(query, types: [sp.SearchType.album]).first(12),
    );
    final albums = <_AlbumItem>[];
    for (final page in pages) {
      for (final item in page.items ?? []) {
        if (item is sp.AlbumSimple && item.name != null) {
          final artistName = item.artists?.firstOrNull?.name ?? '';
          final url =
              (item.images?.isNotEmpty == true) ? item.images!.first.url : null;
          albums.add(_AlbumItem(name: item.name!, artist: artistName, imageUrl: url));
        }
      }
    }
    return albums;
  } catch (e) {
    debugPrint('[Onboarding] Album search error: $e');
    return [];
  }
}

// ─── Main flow controller ─────────────────────────────────────────────────────

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

  final Set<String> _selectedGenres = {};
  final Set<String> _selectedArtists = {};
  final Set<String> _selectedAlbums = {};

  static const int _minGenres = 3;

  void _toggleGenre(String g) => setState(() =>
      _selectedGenres.contains(g) ? _selectedGenres.remove(g) : _selectedGenres.add(g));

  void _toggleArtist(String a) => setState(() =>
      _selectedArtists.contains(a) ? _selectedArtists.remove(a) : _selectedArtists.add(a));

  void _toggleAlbum(String al) => setState(() =>
      _selectedAlbums.contains(al) ? _selectedAlbums.remove(al) : _selectedAlbums.add(al));

  void _next() {
    if (_currentPage == 0 && _selectedGenres.length < _minGenres) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least 3 genres to continue.'),
          backgroundColor: Color(0xFF1A1919),
        ),
      );
      return;
    }
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;

        final prefs = EnhancedUserPreferences(
          favoriteGenres: _selectedGenres.toList(),
          favoriteArtists: _selectedArtists.toList(),
          favoriteAlbums: _selectedAlbums.toList(),
          genreWeights: {for (final g in _selectedGenres) g: 1.0},
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('musicPreferences')
            .doc('profile')
            .set(
              {
                ...prefs.toJson(),
                'onboardingComplete': true,
                'lastUpdated': DateTime.now().toIso8601String(),
              },
              SetOptions(merge: true),
            );

        // Clear the recommendations cache so the For You tab generates fresh
        // results using the new preferences immediately.
        ReviewRecommendationService.clearRecommendationsCache(uid);

        debugPrint('[Onboarding] Saved '
            '${_selectedGenres.length} genres, '
            '${_selectedArtists.length} artists, '
            '${_selectedAlbums.length} albums');
      }
    } catch (e) {
      debugPrint('[Onboarding] Save error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNav(title: 'CRATEBOXD')),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(currentPage: _currentPage, onClose: _finish),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _GenresPage(selected: _selectedGenres, onToggle: _toggleGenre),
                  _ArtistsPage(selected: _selectedArtists, onToggle: _toggleArtist),
                  _AlbumsPage(selected: _selectedAlbums, onToggle: _toggleAlbum),
                ],
              ),
            ),
            _BottomBar(
              currentPage: _currentPage,
              saving: _saving,
              onBack: _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared chrome ────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int currentPage;
  final VoidCallback onClose;

  const _TopBar({required this.currentPage, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'CRATEBOXD',
            style: GoogleFonts.gasoekOne(
              textStyle: const TextStyle(
                color: Color(0xFFCC1111),
                fontSize: 16,
                shadows: [Shadow(blurRadius: 10, color: Color(0x99CC0000))],
              ),
            ),
          ),
          Row(
            children: [
              Text(
                '${currentPage + 1} / 3',
                style: const TextStyle(
                  color: _onSurfaceVariant,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded,
                    color: _onSurfaceVariant, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int currentPage;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomBar({
    required this.currentPage,
    required this.saving,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = currentPage == 0;
    final isLast = currentPage == 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: isFirst
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: onBack,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text(
                      '← BACK',
                      style: TextStyle(
                        color: _onSurfaceVariant,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: active ? _secondary : _outlineVariant,
                  ),
                );
              }),
            ),
          ),
          GestureDetector(
            onTap: saving ? null : onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: _secondary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: _secondary.withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    )
                  : Text(
                      isLast ? 'DONE' : 'NEXT →',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1: Genres (no emojis) ───────────────────────────────────────────────

class _GenresPage extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;

  const _GenresPage({required this.selected, required this.onToggle});

  static const _genres = [
    'Hip-Hop', 'R&B', 'Electronic', 'Jazz',
    'Rock', 'Pop', 'Indie', 'Classical',
    'Metal', 'Soul', 'Folk', 'Ambient',
    'Punk', 'Reggae', 'Blues', 'House',
    'Alternative', 'Country', 'Funk', 'Techno',
    'Trap', 'Gospel', 'Afrobeats', 'Lo-Fi',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What fuels \nyour groove?',
            style: GoogleFonts.spaceGrotesk(
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Select at least 3 vibes to personalise\nyour late-night discovery archive.',
            style: TextStyle(
                color: _onSurfaceVariant, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _genres.map((genre) {
              final isSelected = selected.contains(genre);
              return GestureDetector(
                onTap: () => onToggle(genre),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primary.withOpacity(0.14)
                        : _surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _primary
                          : _outlineVariant.withOpacity(0.35),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _primary.withOpacity(0.22),
                              blurRadius: 14,
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : _onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              selected.length >= 3
                  ? '${selected.length} selected  ✓'
                  : '${selected.length} / 3 minimum',
              key: ValueKey(selected.length >= 3),
              style: TextStyle(
                color: selected.length >= 3 ? _secondary : _onSurfaceVariant,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Artists ──────────────────────────────────────────────────────────

class _ArtistsPage extends StatefulWidget {
  final Set<String> selected;
  final void Function(String) onToggle;

  const _ArtistsPage({required this.selected, required this.onToggle});

  @override
  State<_ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<_ArtistsPage> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  List<_ArtistItem> _items = const [];
  bool _loading = true; // starts loading while we fetch real images

  // Curated names — images are fetched from Spotify on initState
  static const _kCuratedNames = [
    'Kendrick Lamar', 'Frank Ocean', 'Radiohead',
    'Beyoncé', 'Tyler the Creator', 'Billie Eilish',
    'The Beatles', 'Kanye West', 'Miles Davis',
    'Björk', 'Bon Iver', 'Lorde',
  ];

  @override
  void initState() {
    super.initState();
    _loadCuratedArtists();
  }

  Future<void> _loadCuratedArtists() async {
    try {
      final api = _buildSpotifyApi();
      final imageUrls = await Future.wait(
        _kCuratedNames.map((name) => _fetchArtistImageUrl(api, name)),
      );
      final items = List.generate(
        _kCuratedNames.length,
        (i) => _ArtistItem(name: _kCuratedNames[i], imageUrl: imageUrls[i]),
      );
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      debugPrint('[Onboarding] Failed to load artist images: $e');
      if (mounted) {
        setState(() {
          _items = _kCuratedNames
              .map((n) => _ArtistItem(name: n))
              .toList();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _loadCuratedArtists();
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final found = await _searchArtistsSpotify(value.trim());
      if (mounted) {
        setState(() {
          _items = found.isEmpty
              ? _kCuratedNames.map((n) => _ArtistItem(name: n)).toList()
              : found;
          _loading = false;
        });
      }
    });
  }

  Color _avatarBg(String name) {
    const palette = [
      Color(0xFF6B3FA0), Color(0xFF1E5F74), Color(0xFF7B2D8B),
      Color(0xFF1A5E3E), Color(0xFF7A3B1E), Color(0xFF1E3A5F),
      Color(0xFF5C1E6B), Color(0xFF1E4D2B), Color(0xFF6B1E3A),
      Color(0xFF1E4A6B),
    ];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who\'s in your\nrotation?',
                style: GoogleFonts.spaceGrotesk(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Select at least 5 artists to help build\nyour initial archive.',
                style: TextStyle(
                    color: _onSurfaceVariant, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 18),
              _SearchBar(
                  controller: _ctrl,
                  onChanged: _onSearch,
                  hint: 'Search for artists...'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.selected.length} / 5 SELECTED',
                      style: TextStyle(
                        color: widget.selected.length >= 5
                            ? _secondary
                            : _onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_secondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final artist = _items[i];
                    final isSelected =
                        widget.selected.contains(artist.name);
                    return GestureDetector(
                      onTap: () => widget.onToggle(artist.name),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _avatarBg(artist.name),
                                  border: Border.all(
                                    color: isSelected
                                        ? _primary
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: _primary.withOpacity(0.4),
                                            blurRadius: 14,
                                          )
                                        ]
                                      : [],
                                ),
                                child: artist.imageUrl != null
                                    ? ClipOval(
                                        child: AppCachedImage(
                                          imageUrl: artist.imageUrl!,
                                          width: 80,
                                          height: 80,
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          artist.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: _primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            artist.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : _onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Step 3: Albums ───────────────────────────────────────────────────────────

class _AlbumsPage extends StatefulWidget {
  final Set<String> selected;
  final void Function(String) onToggle;

  const _AlbumsPage({required this.selected, required this.onToggle});

  @override
  State<_AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<_AlbumsPage> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  List<_AlbumItem> _items = const [];
  bool _loading = true; // starts loading while we fetch real art

  // Curated base list — art URLs fetched from Spotify on initState
  static const _kCuratedBase = [
    _AlbumItem(name: 'To Pimp a Butterfly', artist: 'Kendrick Lamar'),
    _AlbumItem(name: 'Blonde', artist: 'Frank Ocean'),
    _AlbumItem(name: 'OK Computer', artist: 'Radiohead'),
    _AlbumItem(name: 'DAMN.', artist: 'Kendrick Lamar'),
    _AlbumItem(name: 'My Beautiful Dark Twisted Fantasy', artist: 'Kanye West'),
    _AlbumItem(name: 'When We All Fall Asleep, Where Do We Go?', artist: 'Billie Eilish'),
    _AlbumItem(name: 'Abbey Road', artist: 'The Beatles'),
    _AlbumItem(name: 'Homogenic', artist: 'Björk'),
    _AlbumItem(name: 'For Emma, Forever Ago', artist: 'Bon Iver'),
    _AlbumItem(name: 'Melodrama', artist: 'Lorde'),
    _AlbumItem(name: 'IGOR', artist: 'Tyler the Creator'),
    _AlbumItem(name: 'Kind of Blue', artist: 'Miles Davis'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCuratedAlbums();
  }

  Future<void> _loadCuratedAlbums() async {
    try {
      final api = _buildSpotifyApi();
      final imageUrls = await Future.wait(
        _kCuratedBase.map(
          (a) => _fetchAlbumArtUrl(api, a.name, a.artist),
        ),
      );
      final items = List.generate(
        _kCuratedBase.length,
        (i) => _AlbumItem(
          name: _kCuratedBase[i].name,
          artist: _kCuratedBase[i].artist,
          imageUrl: imageUrls[i],
        ),
      );
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      debugPrint('[Onboarding] Failed to load album art: $e');
      if (mounted) setState(() { _items = _kCuratedBase; _loading = false; });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _loadCuratedAlbums();
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final found = await _searchAlbumsSpotify(value.trim());
      if (mounted) {
        setState(() {
          _items = found.isEmpty ? _kCuratedBase : found;
          _loading = false;
        });
      }
    });
  }

  Color _placeholderColor(String name) {
    const palette = [
      Color(0xFF1E3A5F), Color(0xFF3D1A00), Color(0xFF1A1A3E),
      Color(0xFF0D3D1A), Color(0xFF3D1A1A), Color(0xFF2D1A3D),
      Color(0xFF1A2D3D), Color(0xFF3D2D1A), Color(0xFF1A3D2D),
    ];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'ARCHIVE YOUR\n',
                      style: GoogleFonts.spaceGrotesk(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    TextSpan(
                      text: 'ESSENTIALS.',
                      style: GoogleFonts.spaceGrotesk(
                        textStyle: const TextStyle(
                          color: _secondary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Pick the albums that shaped your sound.\nBuild your digital crate.',
                style: TextStyle(
                    color: _onSurfaceVariant, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 18),
              _SearchBar(
                controller: _ctrl,
                onChanged: _onSearch,
                hint: 'Search for an album or artist...',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_secondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final album = _items[i];
                    final isSelected =
                        widget.selected.contains(album.name);
                    return GestureDetector(
                      onTap: () => widget.onToggle(album.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.25),
                                    blurRadius: 14,
                                  )
                                ]
                              : [
                                  const BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                  )
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: album.imageUrl != null
                                        ? AppCachedImage(
                                            imageUrl: album.imageUrl!,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: _placeholderColor(
                                                album.name),
                                            child: Center(
                                              child: Icon(
                                                Icons.album_rounded,
                                                color: Colors.white
                                                    .withOpacity(0.25),
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                  ),
                                  if (isSelected)
                                    ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Container(
                                        color: _primary.withOpacity(0.4),
                                        child: const Center(
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    album.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    album.artist,
                                    style: const TextStyle(
                                      color: _onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Shared search bar ────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;
  final String hint;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(color: _onSurfaceVariant, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
