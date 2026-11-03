# UI Polish Audit — 2026-10-29

Code-only audit of spacing, radius and color consistency against `design_system.md`.
Migration step 1 (shared review card) and step 2 (dock clearance on list screens) are done. See **Progress** at the bottom.

| Artifact | What it is |
|---|---|
| `lib/ui/theme/tokens.dart` | `AppSpacing`, `AppRadius`, `AppColors`, `AppShadows` — the design system in code. Not imported anywhere yet. |
| `docs/ui_audit/before/` | Baseline screenshots (web build, logged in as the demo user). |
| `docs/ui_audit/token_mapping.md` | Every hard-coded spacing / radius value with file:line → proposed token, plus colors grouped by value. Regenerate with `scripts/token_audit.py`. |

## Numbers

| Category | Occurrences | Already on scale | Value would change |
|---|---|---|---|
| Spacing (`EdgeInsets` / `SizedBox` / `Gap`) | 707 | 514 (73%) | 191 |
| Corner radius | 187 | 156 (83%) | 24 |
| Colors | 1,149 uses, 103 distinct values | — | — |

Most common off-scale spacing: `10→12` ×57, `20→24` ×38, `6→8` ×27, `14→16` ×21, `28→32` ×16, `5→4` ×11.
So the drift is mostly values *between* steps, not wildly different ones — mechanical to fix.

## Top findings (ranked by visible impact)

### 1. The shared review card is wrapped differently on every screen
`ReviewCardWithGenres` is shared, but the **card surface** (`Card` + border + margin + outer padding) is re-declared in each of the 6 screens:

| Screen | Outer padding | Card margin |
|---|---|---|
| `Home/community_reviews.dart:445` | `only(right: 20)` | `all(5)` |
| `Home/friends_reviews.dart:389` | `symmetric(h: 8, v: 4)` | `zero` |
| `Home/recommended_reviews.dart:309, 442` | `symmetric(...)` | `all(0)` |
| `Home/_comments.dart:278` (Profile) | — | `all(0)` |
| `search/search_screen.dart:195` | `symmetric(h: 8, v: 4)` | `all(5)` |
| `Trending/album_detail_page.dart:64` | `symmetric(...)` | `zero` |

All six use radius 8, a 1px `Color.fromARGB(56,158,158,158)` border and `Colors.white10` fill.
This is the main source of the "card padding inconsistencies", and it bends the CLAUDE.md rule against inlining card UI.
**Fix:** move the surface into `ReviewCardWithGenres` (or a `CrateCard` wrapper in `lib/ui/widgets/`) and make screens pass nothing but the review.

### 2. Card treatment contradicts the design system
- Doc: Crate Card radius `1.5rem` (24), **no borders** ("No-Line" rule), separation by surface shift.
- Code: radius 8, 1px border, translucent `white10` fill rather than `surfaceContainerHigh`.
- See `before/02_review_card_zoom.png`.

### 3. Content hides behind the floating dock
`MainNavigation` uses `extendBody: true`, but list screens don't add bottom padding for the dock, so the last card's action row sits under it (`before/03_home_friends.jpg`, `04_home_for_you.jpg`, `06_discover_crates.jpg`). Only `trending_tracks.dart` accounts for it.
**Fix:** one `AppSpacing.dockClearance` value (≈ dock height + gutter) applied as list bottom padding.

### 4. Dividers and outlines throughout
11 `Divider(` and 36 `Border.all` uses. Visible on the review detail page (lines above/below the stats row, `before/10_review_detail_scrolled.jpg`) and the Profile tab bar (`before/08_profile.jpg`). Doc says replace with spacing / background shifts, or a 15%-opacity ghost border where accessibility needs one.

### 5. Inconsistent sibling card heights
- Trending track cards: only the first has a subtitle ("classic grunge"), so text baselines don't line up across the row (`before/07_trending.jpg`).
- Discover list: rows without genre chips are shorter than rows with them (`before/05_discover_discovery.jpg`).
- Popular Crates: tag chips wrap to a second line on some cards (`before/06_discover_crates.jpg`).
**Fix:** reserve fixed slots (min-height / fixed line count) for optional text and chip rows.

### 6. Mixed shape language on controls
- Profile: "Edit Profile" is a filled grey pill, "Share" an outlined pill — two secondary styles side by side.
- Review detail: comment input is a 25-radius pill, but its send button is a ~8-radius square.
- Radius drift: `20→24` ×8, `10→12` ×6, and pills written as 30 / 50 / 100 / 999 / 9999.

### 7. Typography doesn't match the doc
Manrope (body font in the doc) is not used anywhere. Only `GoogleFonts.spaceGrotesk` ×4 and `gasoekOne` ×3. Body text is mostly `Colors.white` (640 uses), while the doc asks for `onSurfaceVariant` (#adaaaa) for long-form text.

### 8. Ad-hoc color variants
- 10+ different reds (`Colors.red`, `red[600]`, `red[700]`, `redAccent`, `0xFFCC1111`, five `fromARGB` reds) all meaning "primary".
- Two different neon greens (`0xFF3FFF8B`, `0xFF39FF6A`) for `secondary`.
- Genre / chart / heatmap colors are legitimately unique — move them to a dedicated palette list, not tokens.

## Decisions (resolved 2026-10-29)

| # | Question | Decision |
|---|---|---|
| 1 | Card radius | **12** (`AppRadius.card`). Not the doc's 24. |
| 2 | Card borders | **Keep a faint 1px ghost border**: white at 15% (`AppColors.ghostBorder`), replacing today's 22% grey. |
| 3 | Gutters | `pageGutter = 16`, `cardGap = 12`. |
| 4 | In-between values | **Round up** (10→12, 20→24, 6→8). |
| 5 | Body text color | **Stay white.** `onSurfaceVariant` only for metadata, timestamps and captions. |
| 6 | Fonts | **Doc updated to match the code:** Roboto (default) for body, Space Grotesk for headlines, Gasoek One for the wordmark. |

`design_system.md` was updated for 1, 2, 3, 5 and 6 so the doc and the tokens agree.
Findings 2 and 7 above are therefore only partly still open: borders become a ghost border, and the font and body-color mismatches are resolved.

## Suggested migration order (after decisions)

1. `lib/ui/widgets/review_card.dart`: absorb the card surface (finding 1), using radius 12, a ghost border and `surfaceContainerHigh` fill. This fixes 6 screens at once.
2. Dock clearance on all list screens (finding 3).
3. Remaining shared widgets: `auth_gate_modal.dart`, `skeleton_loader.dart`.
4. Screen by screen, one commit each, using `token_mapping.md`: Home → Review detail → Profile → Discover → Trending → Search → Playlists → Onboarding.
5. Take after-screenshots matching `before/`, then add a CI grep that flags new raw `EdgeInsets`/`circular(` numbers outside `tokens.dart`.

## Progress

### Done: step 1, shared review card surface
- The card surface now lives in `review_card.dart` (`_ReviewCardSurface`): `surfaceContainer` fill, `AppRadius.card` (12) and a `ghostBorder` (white at 15%).
- **7** per-screen `Card` wrappers were removed: Popular, Friends, For You (×2), Profile `_comments.dart`, Profile → Reviews tab (`profilePage.dart`, missed in the original audit), Search and Album detail. Screens now only wrap cards in `Padding(padding: AppSpacing.cardListItem)`, which gives 16 at the page edges and 12 between cards.
- Card internals are on the token scale: inner padding 24 (`cardPadding`), and the spacing values 20→24, 10→12 and 6→8. Tag chips are pills and stars use `AppColors.rating`. Artist and timestamp text use `onSurfaceVariant`.
- The Popular and Profile swipe-to-dismiss backgrounds now use the card radius.
- `ReviewCardSkeleton` matches the real card's surface, padding and 100px art, so content no longer shifts when it loads.

### Done: step 2, dock clearance
`AppSpacing.dockClearance` (112) is now bottom padding on the Popular, Friends, For You, Profile reviews and Discover lists. Crates, Profile and Trending already had their own clearance.

### Done: shared list layout for the Home tabs
- `lib/ui/widgets/review_feed.dart`: `ReviewFeed` owns list padding (first card 16 below the top, `dockClearance` at the bottom for tabs), card gap, pull-to-refresh, infinite scroll and the loading footer. `ReviewFeedSkeleton` is the matching loading state.
- `lib/ui/widgets/app_states.dart`: `AppEmptyState`, `AppErrorState`, `AppLoadingFooter`. One size for icons (64), titles (18), messages (`onSurfaceVariant`) and pill-shaped `primary` action buttons.
- Popular, Friends and For You now only provide data and callbacks. Scroll controllers and load-more logic moved out of the screens. The files went from 605 / 400 / 580 lines to 391 / 246 / 324.
- Visible changes: the loading placeholders now sit 16 below the tab bar like the real cards (they used to jump by 10). The "Sign In Required" prompts are the same size as other empty states (they were larger). Buttons use the brand `primary` red (they used Material `red[600]`/`red[700]`). The "loading more" spinner is centered on every tab.

### Not done yet
- Move Profile → Reviews, Search and Album detail onto `ReviewFeed` (needs an `embedded` layout for Profile's nested scroll).
- Theme layer (card, chip, text styles in `ThemeData`) and guardrails (CI check for raw padding/colors in screens, golden tests).
- Steps 3–5 (other shared widgets, then screen by screen).
- The Home tab-bar pill sits at ~14px from the edge vs. the cards' 16. Fix it in `categoryTapBar.dart`.

After-screenshots: `docs/ui_audit/after/` (614px-wide viewport).
