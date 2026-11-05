# Project Rules
Design System
- For the design system reference the design_system.md file in the project root



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

**Rule:** Never duplicate or inline review card UI in a screen file. All screens that display review cards must import from `lib/ui/widgets/review_card.dart`.

Screens currently using this widget:
- `lib/ui/screens/Home/community_reviews.dart` (Popular tab)
- `lib/ui/screens/Home/friends_reviews.dart` (Friends tab)
- `lib/ui/screens/Home/recommended_reviews.dart` (For You tab)
- `lib/ui/screens/Profile/profilePage.dart` (Profile → Reviews tab)
- `lib/ui/screens/Trending/album_detail_page.dart` (Album detail)
- `lib/ui/screens/search/search_screen.dart` (Search results)

The card frame (inset 8 from the screen edges, 8 between cards, 12 corner radius, no border, blurred album-art background) is `CardSurface` in `lib/ui/widgets/card_surface.dart`. Review cards and Explore track cards both use it; any new content card should too, with `AppSpacing.cardPadding` inside and `AppSpacing.cardListItem` around it.

Genre / tag pills come from `lib/ui/widgets/genre_pills.dart`: `GenrePills(tags)` when the genres are known, or `TrackGenrePills(title, artist)` to look them up first (used by Explore track cards). Never build tag chips inline. Tapping a pill opens that tag's page (`lib/ui/screens/tag/tag_reviews_page.dart`): reviews with the tag, then reviews with similar tags (`tagsSimilar`), then reviews whose text mentions it, plus related tags to explore. It pages through a database index, not a scan: every review carries `tagKeys` / `tagWordKeys` / `textWordKeys` (`searchKeysFor` in `lib/providers/tag_reviews_provider.dart`, written by `submitReview` and kept in sync by the `onReviewWritten` function via `syncSearchKeys`). The Dart and TypeScript (`searchKeys` in `functions/src/text.ts`) versions must match; both are tested against `functions/src/__tests__/fixtures/search_keys.json`. Backfill with `npm run backfill -- --search-keys`.

`lib/ui/screens/Home/_comments.dart` contains `UserReviewsCollection` and `FriendsReviewList` (the dismissible list wrapper used by the Profile screen). It imports `ReviewCardWithGenres` from the shared widget file.

### Review Feed (list layout)
Lists of review cards are laid out by **one widget**:

```
lib/ui/widgets/review_feed.dart
```

- `ReviewFeed` — owns page gutter, card gap, top/bottom spacing (incl. floating-dock clearance), pull-to-refresh, infinite scroll and the loading footer. Screens pass only `reviews`, `onRefresh`, optional `onLoadMore`/`hasMore`, a `storageKey`, a `layout` (`tab` or `pushed`) and an optional `itemWrapper` (e.g. Dismissible — must not add padding).
- `ReviewFeedSkeleton` — the loading state, same spacing as the feed.
- Your own review cards swipe left (or long-press) to open the glass edit / delete options: wrap the card in `OwnReviewOptions` (`lib/ui/widgets/review_options.dart`), which does nothing for other people's reviews. Used by Popular (as the `itemWrapper`) and Profile → Reviews.
- Tapping Home while already on Home calls `ReviewFeed.scrollToTopAndRefresh()`: the `tab`-layout feed on screen scrolls to the top and runs its `onRefresh`.

Empty / error / loading-more states come from `lib/ui/widgets/app_states.dart` (`AppEmptyState`, `AppErrorState`, `AppLoadingFooter`).

**Rule:** Screens never set padding, margins or gaps around review cards and never hand-build empty/error states. Change the shared widget instead so every screen stays in sync. Spacing, radius and color values come from `lib/ui/theme/tokens.dart`.

Currently using `ReviewFeed`: the three Home tabs (Popular, Friends, For You). Profile, Search and Album detail still build their own lists and are next to migrate.

### For You recommendations (server-side CF-RAG)
The For You list and the post-review "Because you just reviewed X" sheet are built in **Cloud Functions** (`functions/`, TypeScript). See `functions/README.md`.

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

`ReviewDetailPage(review: Review, reviewId: String?)` — full-screen detail view with hero album art, drop-cap review body, live like button, stats bar, and comments section. The tap is wired directly inside `ReviewCardWidget`; no screens need to handle navigation themselves.


### Auth Gating / Feature Gating 
- for action buttons: like, review, submit review, comment, share, repost, add friends, preferences, notifications.. 
if a user is not signed in, or anonymous user, display a modal that says sign up - use the discoball.gif as a the art for the modal with a cheeky message for a CTA to sign up or sign in
- do not allow anonymous users to submit reviews
- prevent anonymous users from submitting or completing any action other than viewing content from specific pre-approved fields.
- limit anonymous user visibility to popular reviews; popular tracks and suggested tracks; popular crates - else keep suggestion that they sign in / sign up 
- default "anonymous user" as not signed in, anonymous user is for previewing functionality that should lead to CTA for sign up/ sign in
### Sign-in / sign-up routing
The signed-in user drives the UI: `ProfileGate` and the auth providers rebuild on auth changes by themselves, so screens never push `MainNav` or a new `MyApp` after signing in or out. All in `lib/ui/screens/Profile/helpers/profileHelpers.dart`:
- Open the auth screens with `openSignIn(context)` / `openSignUp(context)` (they share the route name `authRouteName`).
- After any successful sign-in or sign-up, call `completeSignIn(context, user)`: it shows onboarding if `hasCompletedOnboarding` is false, otherwise pops the auth screens back to where the user was.
- Onboarding is done when `users/{uid}/musicPreferences/profile.onboardingComplete` is true (skipping sets it too); older accounts count as done if they saved genres or artists.
- New users' `users/{uid}` record is created by `ensureUserDoc` only. Never store passwords in Firestore.
- Show auth errors with `authErrorMessage(code)` (`auth/authService.dart`), never raw Firebase text.
- Sign out with `await signOut()`, then `popUntil(isFirst)`.

### Web updates (installed PWA)
Deploys (`deploy.sh` and `.github/workflows/deploy.yml`) build with `--pwa-strategy=none` and a `--dart-define=BUILD_ID` from `scripts/build_id.sh`, and publish the same id as `build/web/app_version.json`. `AppUpdateWatcher` (`lib/ui/widgets/app_update_watcher.dart`, in `MaterialApp.builder`) compares the two: a newer version reloads the app on launch, or shows an "Update" pill when the user returns to it. Any new web deploy path must stamp the build id the same way. `firebase.json` serves html/js/json with `Cache-Control: no-cache`.
