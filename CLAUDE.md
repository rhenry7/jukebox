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
- `lib/ui/screens/Profile/profilePage.dart` (My Reviews tab)
- `lib/ui/screens/Trending/album_detail_page.dart` (Album detail)
- `lib/ui/screens/search/search_screen.dart` (Search results)

`lib/ui/screens/Home/_comments.dart` contains `UserReviewsCollection` and `FriendsReviewList` (the dismissible list wrapper used by the Profile screen). It imports `ReviewCardWithGenres` from the shared widget file.

### Review Detail Page
Tapping anywhere on a review card (outside the bottom action row) navigates to:

```
lib/ui/screens/review_detail/review_detail_page.dart
```

`ReviewDetailPage(review: Review, reviewId: String?)` — full-screen detail view with hero album art, drop-cap review body, live like button, stats bar, and comments section. The tap is wired directly inside `ReviewCardWidget`; no screens need to handle navigation themselves.


### Auth Gating / Feature Gating 
- for action buttons: like, review, submit review, comment, share, repost, add friends, preferences, notifications
if a user is not signed in, or anonymous user, display a modal that says sign up - use the discoball.gif as a the art for the modal with a cheeky message for a CTA to sign up or sign in
- limit anoymous user visiblity to popular reviews; popular tracks and suggested tracks; popular crates - else keep suggestion that they sign in / sign up 
- default "anonymous user" as not signed in, anonymous user is for previewing functionality that should lead to CTA for sign up/ sign in