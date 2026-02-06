# Jukeboxd

A Flutter-based, cross-platform music discovery and review app targeting web, iOS, and Android. Jukeboxd combines social reviewing with AI-powered music recommendations, letting users rate and review tracks, discover new music tailored to their taste, and explore what a community of listeners is enjoying.

---

## High-Level Architecture

The app follows a layered architecture with Riverpod for state management and Firebase as the backend:

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  MainNavigation → Home / Discovery / Trending /  │
│                   Add Review / Profile           │
├─────────────────────────────────────────────────┤
│               Provider Layer (Riverpod)          │
│  authStateProvider, userReviewsProvider,         │
│  userPreferencesProvider, trendingTracksProvider  │
├─────────────────────────────────────────────────┤
│              Service Layer                       │
│  MusicRecommendationService (AI + Collaborative) │
│  ReviewAnalysisService, PlaylistGenerationService│
│  MusicProfileService, WikipediaService           │
│  ReviewLikesService, UserServices                │
├─────────────────────────────────────────────────┤
│            External API Layer                    │
│  OpenAI (GPT-3.5) │ Spotify │ MusicBrainz │     │
│  Wikipedia         │ Unsplash│ Firebase     │     │
├─────────────────────────────────────────────────┤
│              Data / Cache Layer                   │
│  Firestore (reviews, preferences, caches)        │
│  In-memory caches (validation, images)           │
│  CachedNetworkImage (disk-level image cache)     │
└─────────────────────────────────────────────────┘
```

**Key navigation tabs:** Home (reviews feed), Discovery (recommendations + explore), Add Review, Trending, Profile.

---

## The Recommendation System

The recommendation feature uses a multi-signal, multi-source approach with three independent recommendation pipelines that are merged, deduplicated, and balanced.

### Data Model: `EnhancedUserPreferences`

The foundation of all recommendations is a rich preference profile stored in Firestore at `users/{userId}/musicPreferences/profile`:

| Field | Type | Purpose |
|-------|------|---------|
| `favoriteGenres` | `List<String>` | Top genres the user likes |
| `favoriteArtists` | `List<String>` | Preferred artists |
| `dislikedGenres` | `List<String>` | Genres to avoid |
| `genreWeights` | `Map<String, double>` | 0.0–1.0 strength per genre |
| `moodPreferences` | `Map<String, double>` | chill, energetic, focus, party |
| `tempoPreferences` | `Map<String, double>` | slow, medium, fast preference |
| `contextualPreferences` | `Map<String, List<String>>` | workout/study/sleep playlists |
| `savedTracks` / `dislikedTracks` | `List<String>` | Positive/negative signals |
| `audioFeatureProfile` | `Map<String, double>` | danceability, energy, valence |
| `skipCounts` / `repeatCounts` | `Map<String, int>` | Behavioral engagement signals |

This profile is built from two sources: (a) explicit input via the **MusicTasteProfileWidget** (an onboarding wizard with genre sliders, mood sliders, and tempo sliders), and (b) implicit signals from user reviews, likes, and interactions.

### The Three Recommendation Pipelines

#### Pipeline A: AI-Powered Recommendations (OpenAI GPT-3.5-Turbo)

This is the primary recommendation engine, implemented in `MusicRecommendationService`.

**Flow:**

```
User Reviews + Preferences + Review Analysis
           │
           ▼
   _buildEnhancedPrompt()  ← constructs a detailed GPT prompt
           │
           ▼
   OpenAI GPT-3.5-turbo API  (POST to /v1/chat/completions)
           │
           ▼
   _parseRecommendations()  ← extracts structured song/artist/album/genre
           │
           ▼
   List<MusicRecommendation>
```

**The prompt construction** (`_buildEnhancedPrompt`) synthesizes:

- **Genre weights** — tells the AI which genres matter most (e.g., "rock: 0.85, jazz: 0.6")
- **Favorite artists** — seeds for stylistic targeting
- **Disliked genres/tracks** — explicit negative signals to avoid
- **Mood and tempo preferences** — emotional tone parameters
- **Recent review analysis** — the `UserReviewProfile` from `ReviewAnalysisService` provides:
  - `ratingPattern` (average rating, variance, what the user rates highly)
  - `genrePreferences` (derived from actual review scores, not just stated preferences)
  - `artistPreferences` (who the user reviews most favorably)
  - `reviewSentiment` (NLP-extracted keywords — what terms appear in positive vs. negative reviews)
  - `temporalPatterns` (review timing, whether taste is shifting)
- **Exclusion list** — recently recommended songs are excluded to avoid repeats (managed by `_recentRecommendations` cache)

The `ReviewAnalysisService` performs **incremental analysis** — it caches the review profile in Firestore and only re-analyzes when new reviews are added, using either a full recomputation or an incremental update for small batches.

#### Pipeline B: Collaborative Filtering

Implemented in `RecommendationEnhancements.findSimilarUsers()` and `getCollaborativeRecommendations()`.

**Flow:**

```
Current user's highly-rated artists (score > 3.5)
           │
           ▼
   Cross-reference with community reviews (collectionGroup query)
           │
           ▼
   Rank other users by overlap count → Top 10 similar users
           │
           ▼
   Fetch their highly-rated songs the current user hasn't reviewed
           │
           ▼
   List<MusicRecommendation>
```

This is a user-based collaborative filter: "Users who loved the same artists you love also loved these other songs." The similarity metric is overlap count of shared highly-rated artists, with the top 10 most similar users contributing recommendations.

#### Pipeline C: Spotify-Based Recommendations

Implemented in `RecommendationEnhancements.getSpotifyRecommendations()`.

**Flow:**

```
User's saved tracks + favorite artists
           │
           ▼
   Spotify Search API (seeded by user preferences)
           │
           ▼
   Filter by genre weights, exclude disliked
           │
           ▼
   List<MusicRecommendation>
```

This pipeline uses the user's Spotify-style preferences to discover tracks directly through the Spotify search API, using genre/artist seeds derived from the user's profile.

### Post-Processing: Merging, Validation & Balancing

After all three pipelines produce candidates, `MusicRecommendationService.getRecommendations()` merges them through several post-processing stages:

**a) Validation** — Verifying recommendations are real tracks:
- `spotify-only` mode (default, fast): search Spotify for the track
- `hybrid` mode: check MusicBrainz first, then Spotify
- `none` mode: skip validation for speed
- Results are cached in `_validationCache` (capped at 200 entries) to avoid re-validating

**b) Diversity enforcement** (`RecommendationEnhancements.ensureDiversity`):
- Calculates a diversity score based on genre spread (60% weight) and artist spread (40% weight)
- Ensures a minimum number of distinct genres and artists
- Prevents one genre or artist from dominating the list

**c) Novelty scoring** (`RecommendationEnhancements.calculateNoveltyScore`):
- Measures how "new" a recommendation is relative to the user's existing preferences
- Higher scores for unfamiliar genres/artists

**d) Safe/discovery balancing** (`RecommendationEnhancements.balanceRecommendations`):
- Splits recommendations into "safe bets" (close to existing taste) and "discoveries" (novel)
- Applies a configurable `discoveryRatio` (default 60% discoveries) to keep results fresh while staying relevant

**e) Metadata enrichment** — Album art is fetched from Spotify and cached via `AlbumArtCacheService` (Firestore-backed with 30-day TTL). This step can be skipped for speed with `skipMetadataEnrichment: true`.

### Additional Discovery Features

Beyond the core AI recommendation engine, the Discovery tab offers several supplementary discovery surfaces:

- **Explore Tracks** (`explore_tracks.dart`): Uses `MusicProfileService` to read the user's taste profile, generates weighted genre queries, sends them to the Spotify search API in parallel, and enriches results with Wikipedia artist bios (cached in Firestore with 7-day TTL via `WikipediaBioCacheService`)

- **Personalized Playlists** (`discoveryFreshTrackCards.dart`): Fetches Spotify playlists tailored to the user's preferences, with a feedback loop — when a user likes a playlist, their preferences are updated

- **Playlist Generation** (`PlaylistGenerationService`): Context-aware playlist builder using MusicBrainz. Given a context like "workout" or "study", it maps to appropriate genres/tempo/mood, queries MusicBrainz for recordings, then ranks results by `genreWeight > mood > tempo > communityRating`

- **Trending Tracks** (`TrendingTracksService`): Fetches popular Spotify tracks across multiple genre queries and ranks them by a combination of popularity and relevance to the user's preferences

- **Community Reviews** feed: social discovery through what other users are reviewing and rating highly

### The Feedback Loop

The system is designed as a closed-loop learning system:

```
User reviews a track → Review stored in Firestore
                         │
                         ├─► savedTracks / dislikedTracks updated
                         ├─► ReviewAnalysisService re-analyzes on next request
                         ├─► Genre weights updated (implicit from ratings)
                         ├─► MusicProfileInsightsService extracts new patterns
                         │
                         ▼
                    Next recommendation request uses updated profile
```

Every review, like, dislike, and playlist interaction feeds back into the preference model, making recommendations progressively more personalized.

---

## Performance & Resilience

- **Rate limiting**: Queue-based (1 req/sec) for MusicBrainz API calls
- **Retry with backoff**: Spotify 429 errors handled via `withSpotifyRetry()` (exponential backoff, 3 retries)
- **HTTP timeouts**: 15–20s on all external API calls
- **Multi-layer caching**: Firestore caches for album art (30d TTL), genres (14d TTL), Wikipedia bios (7d TTL); in-memory caches for validation results and recent recommendations (with size caps and FIFO eviction)
- **Incremental analysis**: `ReviewAnalysisService` only re-analyzes reviews when new ones are added, using Firestore-cached profiles
- **Image caching**: `CachedNetworkImage` for disk-level image caching with loading placeholders and error handling

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Backend | Firebase (Firestore, Auth) |
| AI | OpenAI GPT-3.5-Turbo |
| Music APIs | Spotify Web API, MusicBrainz API |
| Content | Wikipedia API, Unsplash API |
| Deployment | Firebase Hosting, GitHub Actions CI/CD |
| Testing | flutter_test, fake_cloud_firestore, firebase_auth_mocks |
