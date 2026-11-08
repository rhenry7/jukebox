# Image rendering

REVERB is a visual app. Album art is on every review card, the review page,
"More like this", search, tag pages, profiles and onboarding, and the cards'
blurred glass background is made from it too. **A missing or black album
cover reads as a broken app**, so treat image changes like logic changes:
test them in the browser and keep the guards below passing.

## The bug this prevents

Album art sometimes showed as a **solid black square** or a **music-note
error tile**, on every page, often on first load and especially **after
leaving a page and coming back**: art that had loaded went black.

- The image URLs were fine (all of Spotify's `i.scdn.co` covers load, with
  CORS).
- The cause was `cached_network_image` on the web. Its web path
  (`ImageRenderMethodForWeb.HtmlImage`) decodes through the browser's
  `<img>`, and those pictures intermittently came out black or never arrived.
  It failed silently: nothing in the console.
- Flutter's own loader (`Image.network` / `NetworkImage`) on the same URLs, on
  the same screen, always worked.
- Loading cards in stages (Popular's first 10, For You card by card) was not
  the cause; it just meant images were requested more often, so the bug
  showed more.

## Rules

1. **Show network images with `AppCachedImage`** (`lib/utils/cached_image.dart`).
   It gives every image the same loading spinner and music-note error tile,
   and picks the right loader per platform:
   - **Web:** `Image.network`, decoded at the size shown (`cacheWidth`), so a
     100 px thumbnail doesn't hold a 640 px cover in memory. The browser's HTTP
     cache caches the files.
   - **Phones:** `CachedNetworkImage` (disk cache), which works there.
2. **Never use `CachedNetworkImage` / `CachedNetworkImageProvider` on the
   web.** Only `AppCachedImage` and `CardSurface` may import the package, and
   only in their non-web branch.
3. **Card backgrounds come from `CardSurface`** (`lib/ui/widgets/card_surface.dart`).
   The blur is made by decoding the art tiny (`ResizeImage`) and stretching
   it, not with a live blur: live blur on many cards ran iPhones out of GPU
   memory.
4. **Decode at display size** where you can (`cacheWidth` / `ResizeImage`).
   Full-size decodes of every cover add up fast on phones.
5. **Always give an error state** (`errorBuilder` / `errorWidget`), never a
   blank box, so a failed image is visible as a failure.
6. Raw `Image.network` / `NetworkImage` outside those widgets needs a reason.
   Today the only exception is the review page's hero and frosted backdrop
   (`review_detail_page.dart`), which fade the art with a shader mask.

## Tests that guard this

- **`test/images/image_loading_guard_test.dart`** (runs with `flutter test`
  and in CI) is the real protection. It fails if any file other than
  `AppCachedImage` / `CardSurface` uses `cached_network_image`, if those two
  stop branching on `kIsWeb`, or if a screen loads network images directly.
  It blocks the cause, so the bug can't come back through code.
- **`integration_test/app_test.dart`** (`./scripts/run_integration_tests.sh`,
  real Chrome) checks album art on the home feed finishes loading (no
  spinners, no music-note error tiles) on first load and after opening a
  review and coming back. It catches art that never loads or errors.
  **It does not catch art drawn as a black square:** with the old broken
  code put back, the bug didn't show up under `flutter drive`, and it passed.
  Re-drawing the page off screen shows the art correctly even when the
  screen is black, and taking real browser screenshots failed under
  `flutter drive` here.
  That's why the guard test above matters, and why a browser check (below)
  is still required.

## When you change anything image-related

- Run both tests above.
- Look at it in a browser: load the home feed, scroll, open a review, go back,
  switch tabs, tap Home to refresh. Album art must appear and stay.
- On the web, check the console and the Network tab: each cover should load
  once per size, with no errors.
- If it's something phones do differently (memory, caching), say so: it
  needs checking on an iPhone (Safari and the installed app).
