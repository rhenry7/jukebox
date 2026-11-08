# Project Rules
Design System
- For the design system reference the design_system.md file in the project root


## Images: read docs/image-rendering.md before touching any image code
Album art is everywhere in this app, and a black or missing cover reads as a broken app. Show network images with `AppCachedImage` (`lib/utils/cached_image.dart`); card backgrounds come from `CardSurface`. **Never use `CachedNetworkImage` on the web**: its web path left album art black or missing, especially after leaving a page and coming back. `test/images/image_loading_guard_test.dart` blocks the cause; the end-to-end check in `integration_test/app_test.dart` catches art that never loads but can't see black squares. Whenever image code changes, run both and check images in a real browser (load, scroll, open a review, go back).

## Glass and toasts: read docs/glassmorphism.md before building anything that floats
Everything that floats over content (dock, drawer, sheets, dialogs, menus, toasts, tag pills) is frosted glass built with `GlassSurface` (`lib/ui/widgets/glass.dart`, numbers in `AppGlass` in `tokens.dart`): `GlassLevel.panel` for anything with text, `GlassLevel.pill` for tags and small controls. Show toasts only with `showAppToast(context, message, tone: ToastTone.success / warning / error)` or `messenger.showAppToast(...)` after an await (`lib/ui/widgets/app_toast.dart`), with human messages, never `Error: $e`. Never use `BackdropFilter`, `ImageFilter.blur` or `SnackBar` directly: `test/glass/glass_guard_test.dart` fails if you do.

## Shared Widgets

### Review Card
The canonical review card widget lives in **one place only**:

```
lib/ui/widgets/review_card.dart
```

This file contains:
- `ReviewCardWithGenres` — the widget all screens should use (handles async genre loading)
- `ReviewCardWidget` — the core card UI (used internally by ReviewCardWithGenres)
- `ReviewCopyWith` extension on `Review`
- `CompactReviewCard` — a small horizontal card (art; stars, song, artist, reviewer + date; Spotify; one line of up to 5 tags) for carousels

**Rule:** Never duplicate or inline review card UI in a screen file. All screens that display review cards must import from `lib/ui/widgets/review_card.dart`.

Screens currently using this widget:
- `lib/ui/screens/Home/community_reviews.dart` (Popular tab)
- `lib/ui/screens/Home/friends_reviews.dart` (Friends tab)
- `lib/ui/screens/Home/recommended_reviews.dart` (For You tab)
- `lib/ui/screens/Profile/profilePage.dart` (Profile → Reviews tab)
- `lib/ui/screens/search/search_screen.dart` (Search results)

The card frame (inset 8 from the screen edges, 8 between cards, 12 corner radius, no border, blurred album-art background) is `CardSurface` in `lib/ui/widgets/card_surface.dart`. Review cards use it; any new content card should too, with `AppSpacing.cardPadding` inside and `AppSpacing.cardListItem` around it.

Genre / tag pills come from `lib/ui/widgets/genre_pills.dart`: `GenrePills(tags)`. Never build tag chips inline. Tapping a pill opens that tag's page (`lib/ui/screens/tag/tag_reviews_page.dart`): reviews with the tag, then reviews with similar tags (`tagsSimilar`), then reviews whose text mentions it, plus related tags to explore. It pages through a database index, not a scan: every review carries `tagKeys` / `tagWordKeys` / `textWordKeys` (`searchKeysFor` in `lib/providers/tag_reviews_provider.dart`, written by `submitReview` and kept in sync by the `onReviewWritten` function via `syncSearchKeys`). The Dart and TypeScript (`searchKeys` in `functions/src/text.ts`) versions must match; both are tested against `functions/src/__tests__/fixtures/search_keys.json`. Backfill with `npm run backfill -- --search-keys`.

### Review form tag suggestions
Under the Tags field the review form suggests up to 5 tags as tappable `GlassPill`s (`+ tag`); tapping adds it to the field, and tags already typed drop out. `tagSuggestionsProvider` (`lib/providers/tag_suggestions_provider.dart`) puts other reviewers' tags for the same song first (from the Popular pool already loaded), then MusicBrainz's from `TagSuggestionService` (`lib/services/tag_suggestion_service.dart`): the song's tags, then its album's, then the artist's, most voted first, with junk like "meme" / "seen live" / bare years removed. Results are cached per song in `trackGenres/{song}.suggestedTags` (30 days, or 1 day when none were found; a lookup that failed is never cached; needs sign-in to read/write). While they load, the line "Finding suggested tags" shows with cycling dots (`AppLoadingText` in `app_states.dart`). MusicBrainz often answers 503 "busy", so each lookup retries with backoff for up to `TagSuggestionService.retryFor` (25 s), inside `suggestionTimeout` (30 s); if nothing turns up, the form says "Couldn't find any suggested tags for this song". The field always starts empty: suggestions never fill it in. This is separate from `GenreCacheService`, whose broad genres the cards show.

### Review Feed (list layout)
Lists of review cards are laid out by **one widget**:

```
lib/ui/widgets/review_feed.dart
```

- `ReviewFeed` — owns page gutter, card gap, top/bottom spacing (incl. floating-dock clearance), pull-to-refresh, infinite scroll and the loading footer. Screens pass only `reviews`, `onRefresh`, optional `onLoadMore`/`hasMore`, a `storageKey`, a `layout` (`tab` or `pushed`) and an optional `itemWrapper` (e.g. Dismissible — must not add padding).
- `ReviewFeedSkeleton` — the loading state, same spacing as the feed.
- Your own review cards swipe left (or long-press) to open the glass edit / delete options: wrap the card in `OwnReviewOptions` (`lib/ui/widgets/review_options.dart`), which does nothing for other people's reviews. Used by Popular (as the `itemWrapper`) and Profile → Reviews.
- Under the Home tabs, `HomeFeedControls` (`lib/ui/widgets/home_feed_controls.dart`) is a swipeable carousel of tags plus a sort button. Its state (`homeTagFilterProvider`, `homeSortProvider` in `lib/providers/home_feed_controls.dart`) applies to all three tabs: a tag filter keeps reviews with any picked tag (`matchesTagFilter`, normalized tags), and the sort (`applyHomeSort`) reorders. Popular filters through the tag index (`popularTagFilterProvider`), Friends filters its loaded list, and For You loads its whole list while a filter or sort is on. Tags come from the Popular pool (`homeTagChoicesProvider`), shuffled once per session.
- Tag pills everywhere are `GlassPill` (in `genre_pills.dart`): a pill-level `GlassSurface` with `grouped: true`, which shares one background capture through the `BackdropGroup` in `main.dart`.
- Tapping Home while already on Home calls `ReviewFeed.scrollToTopAndRefresh()`: the `tab`-layout feed on screen scrolls to the top and runs its `onRefresh`.

Empty / error / loading-more states come from `lib/ui/widgets/app_states.dart` (`AppEmptyState`, `AppErrorState`, `AppLoadingFooter`, and `AppLoadingText` for a "Loading..." line with animated dots).

**Rule:** Screens never set padding, margins or gaps around review cards and never hand-build empty/error states. Change the shared widget instead so every screen stays in sync. Spacing, radius and color values come from `lib/ui/theme/tokens.dart`.

Currently using `ReviewFeed`: the three Home tabs (Popular, Friends, For You). Profile and Search still build their own lists and are next to migrate.

### For You recommendations (server-side CF-RAG)
The For You list is built in **Cloud Functions** (`functions/`, TypeScript). See `functions/README.md`. The post-review "Because you just reviewed X" sheet matches by tags in the app (`TagMatchService`); the `analyzeAndMatch` callable in `functions/` is no longer called by the app.

- Each review is analysed **once, when written** (`onReviewWritten`): an LLM reads the whole text for context-aware sentiment per aspect, then the review and each aspect are embedded into `reviewVectors` / `reviewAspects` (server-only collections).
- For You = vector search over the whole corpus (praise↔praise, complaint↔complaint, review style, lookalike listeners) → deterministic ranking → cached at `users/{uid}/forYou/current`. Opening the tab costs no AI.
- App side: `lib/services/for_you_service.dart` and `lib/providers/recommended_reviews_provider.dart`. `ReviewRecommendationService` is only the on-device fallback while no cached list exists.

**Rule:** Never call OpenAI (or any paid AI API) from the Flutter app, and never add AI keys to `deploy.sh` — anything in a `--dart-define` ships in the public web bundle. AI work goes in `functions/` with keys in Secret Manager.

### Other users' profiles
`ProfilePage(userId:, displayName:)` shows any user's profile with the same header, filled from their reviews (`reviewsByUserProvider`, `topArtistsForUserProvider`) and `users/{uid}` (`userProfileInfoProvider`). It opens from "View profile" in the reviewer sheet on review cards. Another user's profile has Add Friend in place of Edit Profile, and only their reviews: their bookmarks and activity stay private. Add/remove friend goes through `toggleFriend` in `lib/ui/widgets/friend_toggle.dart`.

### Profile → Bookmarks
The bookmark button on every review card (`_BookmarkButton` in `review_card.dart`) saves the review's path to `users/{uid}/bookmarks` via `lib/services/bookmark_service.dart`. Profile → Bookmarks (`bookmarkedReviewsProvider` in `lib/providers/bookmarks_provider.dart`) loads those reviews live, so edits show and deleted reviews drop out.

### Profile → Activity
The Activity tab merges four sources in `buildActivity` (`lib/providers/activity_provider.dart`): the user's own reviews and reposts, their likes and comments from the private log at `users/{uid}/activity` (`lib/services/activity_service.dart`, written next to each action and removed when it is undone), and likes / comments / reposts / friend adds on their reviews from notifications. Any new user action that should appear there must call `ActivityService` from its service.

### Review Detail Page
Tapping anywhere on a review card (outside the bottom action row) navigates to:

```
lib/ui/screens/review_detail/review_detail_page.dart
```

`ReviewDetailPage(review: Review, reviewId: String?)` — full-screen detail view with hero album art, drop-cap review body, live like button, stats bar, a "More like this" row and the comments section. The row (`SimilarReviewsRow` in `lib/ui/widgets/similar_reviews_row.dart`) shows up to 5 `CompactReviewCard`s for reviews sharing tags, found through the tag index by `similarReviewsProvider` (`lib/providers/similar_reviews_provider.dart`). The tap is wired directly inside `ReviewCardWidget`; no screens need to handle navigation themselves.

### Auth Gating / Feature Gating 
- for action buttons: like, review, submit review, comment, share, repost, add friends, preferences, notifications.. 
if a user is not signed in, or anonymous user, display a modal that says sign up - use the discoball.gif as a the art for the modal with a cheeky message for a CTA to sign up or sign in
- do not allow anonymous users to submit reviews
- prevent anonymous users from submitting or completing any action other than viewing content from specific pre-approved fields.
- limit anonymous user visibility to popular reviews - else keep suggestion that they sign in / sign up 
- default "anonymous user" as not signed in, anonymous user is for previewing functionality that should lead to CTA for sign up/ sign in
### Sign-in / sign-up routing
The signed-in user drives the UI: `ProfileGate` and the auth providers rebuild on auth changes by themselves, so screens never push `MainNav` or a new `MyApp` after signing in or out. All in `lib/ui/screens/Profile/helpers/profileHelpers.dart`:
- Open the auth screens with `openSignIn(context)` / `openSignUp(context)` (they share the route name `authRouteName`).
- After any successful sign-in or sign-up, call `completeSignIn(context, user)`: it shows onboarding if `hasCompletedOnboarding` is false, otherwise pops the auth screens back to where the user was.
- Onboarding is done when `users/{uid}/musicPreferences/profile.onboardingComplete` is true (skipping sets it too); older accounts count as done if they saved genres or artists.
- New users' `users/{uid}` record is created by `ensureUserDoc` only. Never store passwords in Firestore.
- Show auth errors with `authErrorMessage(code)` (`auth/authService.dart`), never raw Firebase text.
- Sign out with `await signOut()`, then `popUntil(isFirst)`.

### Performance conventions
- Spotify: always use `sharedSpotifyApi()` (`lib/services/spotify_client.dart`), never `SpotifyApi(...)` directly — each new client fetches its own token.
- Reviews save the picked song/album as `spotifyUrl`; `SpotifyPlayButton(url: review.spotifyUrl)` opens it without searching (only `https://open.spotify.com` links are trusted).
- Fonts used through `GoogleFonts.x()` are bundled in `assets/fonts/google_fonts/`, named as google_fonts expects (e.g. `SpaceGrotesk-Bold.ttf`) and listed in `pubspec.yaml`; google_fonts uses those before the network. A new font or weight needs its file added there, or it's downloaded from Google at startup. After adding assets, restart `flutter run` (hot restart doesn't pick up new assets).
- Firestore keeps its web cache in IndexedDB (`persistenceEnabled` in `main.dart`).
- Popular (`communityReviewsProvider`) is read once, not live: refresh, the Home re-tap and posting a review re-read it with `ref.invalidate`. It arrives in stages (the device copy, or on a first visit the newest `popularFirstBatch`, then the full pool); the tab keeps cards already placed in their places (`keepPlacedOrder`) and adds new ones below.
- For You shows each card as its review arrives, top-down in ranked order (one that arrives early waits for those above it).
- Pages show cached data first, then the server's (`lib/providers/cache_first.dart`): one-time reads use `cacheThenServer` / `docCacheThenServer` (live `snapshots()` listeners already do this). Page data providers call `ref.keepAliveFor()` so going back is instant, and cards start loading the next page's data on touch (`prefetchReviewPage` in `review_card.dart`; the reviewer sheet prefetches the profile). New page data should follow the same pattern.
- For You reads only the list document live; reviews are fetched a page at a time as the display limit grows (`recommendedReviewsProvider` returns `(loaded, total)`).

### Testing
- Screen tests (`test/screens/`) use `test/helpers/screen_harness.dart`: `pumpScreen` at phone size, plus Riverpod overrides for the signed-in user, like counts, comments and similar reviews. They never touch real Firebase, Spotify or the network; to make a screen testable, read data through a provider rather than `FirebaseFirestore.instance` / `FirebaseAuth.instance` in the widget.
- The review form saves through `reviewSubmitterProvider`, so tests can stand in a fake save.
- Don't use `pumpAndSettle` on screens with album art: the image placeholder keeps animating in tests. Pump fixed durations instead.
- QA skills from the Flutter team are in `.claude/skills/` (static analysis, coverage, layout fixes, widget and integration tests).
- End-to-end tests (`integration_test/app_test.dart`) walk the main signed-out flows in Chrome against live data, read-only: `./scripts/run_integration_tests.sh` (needs ChromeDriver matching your Chrome; see the script). They never sign in or write.
- `flutter analyze` must report no issues: CI fails on any, including infos, and then skips the tests.

### Flutter version
Flutter is managed with FVM. The version is pinned in `.fvmrc` and `.flutter-version` (3.47.9; keep them the same), and CI and `deploy.sh` check it. `fvm global 3.47.9` makes it the default (`~/fvm/default/bin` is first on PATH in `~/.zshrc`; VS Code and Cursor use it too). `pubspec.yaml` requires Flutter 3.47+, so an older Flutter stops at `pub get` with a clear error. To change version: `fvm use <version>`, update `.flutter-version`, and `fvm global <version>`.

The Dart MCP server (`.mcp.json`, `dart mcp-server` from FVM's 3.47.9) lets Claude inspect a running debug app: widget tree, runtime errors, hot reload.

### Web updates (installed PWA)
Deploys (`deploy.sh` and `.github/workflows/deploy.yml`) build with `--pwa-strategy=none` and a `--dart-define=BUILD_ID` from `scripts/build_id.sh`, and publish the same id as `build/web/app_version.json`. `AppUpdateWatcher` (`lib/ui/widgets/app_update_watcher.dart`, in `MaterialApp.builder`) compares the two: a newer version reloads the app on launch, or shows an "Update" pill when the user returns to it. Browsers that still run the caching service worker from older deploys can't reach that code, so deploys also publish `scripts/legacy_sw_cleanup.js` as `flutter_service_worker.js`, which removes the old worker and its caches. Any new web deploy path must stamp the build id and copy that file the same way. `firebase.json` serves html/js/json with `Cache-Control: no-cache`.
