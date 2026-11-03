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

`lib/ui/screens/Home/_comments.dart` contains `UserReviewsCollection` and `FriendsReviewList` (the dismissible list wrapper used by the Profile screen). It imports `ReviewCardWithGenres` from the shared widget file.

### Review Feed (list layout)
Lists of review cards are laid out by **one widget**:

```
lib/ui/widgets/review_feed.dart
```

- `ReviewFeed` — owns page gutter, card gap, top/bottom spacing (incl. floating-dock clearance), pull-to-refresh, infinite scroll and the loading footer. Screens pass only `reviews`, `onRefresh`, optional `onLoadMore`/`hasMore`, a `storageKey`, a `layout` (`tab` or `pushed`) and an optional `itemWrapper` (e.g. Dismissible — must not add padding).
- `ReviewFeedSkeleton` — the loading state, same spacing as the feed.

Empty / error / loading-more states come from `lib/ui/widgets/app_states.dart` (`AppEmptyState`, `AppErrorState`, `AppLoadingFooter`).

**Rule:** Screens never set padding, margins or gaps around review cards and never hand-build empty/error states. Change the shared widget instead so every screen stays in sync. Spacing, radius and color values come from `lib/ui/theme/tokens.dart`.

Currently using `ReviewFeed`: the three Home tabs (Popular, Friends, For You). Profile, Search and Album detail still build their own lists and are next to migrate.

### For You recommendations (server-side CF-RAG)
The For You list and the post-review "Because you just reviewed X" sheet are built in **Cloud Functions** (`functions/`, TypeScript). See `functions/README.md`.

- Each review is analysed **once, when written** (`onReviewWritten`): an LLM reads the whole text for context-aware sentiment per aspect, then the review and each aspect are embedded into `reviewVectors` / `reviewAspects` (server-only collections).
- For You = vector search over the whole corpus (praise↔praise, complaint↔complaint, review style, lookalike listeners) → deterministic ranking → cached at `users/{uid}/forYou/current`. Opening the tab costs no AI.
- App side: `lib/services/for_you_service.dart` and `lib/providers/recommended_reviews_provider.dart`. `ReviewRecommendationService` is only the on-device fallback while no cached list exists.

**Rule:** Never call OpenAI (or any paid AI API) from the Flutter app, and never add AI keys to `deploy.sh` — anything in a `--dart-define` ships in the public web bundle. AI work goes in `functions/` with keys in Secret Manager.

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