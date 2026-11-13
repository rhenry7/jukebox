# Best New Music: sources considered

Notes on which review sites feed the Search page's "Best New Music"
(`functions/src/news.ts`, `NEWS_SOURCES`), which were checked and turned
down, and an open decision about adding specialist sites. All feeds were
tested on 13 Nov 2026; feeds change, so re-test before acting on this.

## What a source needs

A site only works here if its RSS feed has:

1. **Album reviews**: not news, single tracks, interviews, gear or industry
   posts (or a category/keyword to filter them out).
2. **Headlines we can split into artist and album** (`titleParts`); posts
   we can't split are dropped.
3. **Images**: a JPEG/PNG/WebP cover or photo. Otherwise the server tries
   Apple's catalogue (`pickItunesCover`), which often lacks small releases,
   leaving a placeholder tile.
4. **Fresh posts**: several reviews a month.

## In use (6 sites)

| Site | Feed(s) | Notes |
|---|---|---|
| Pitchfork | `/feed/reviews/best/albums/rss` | Best New Albums. Artist comes from the link's slug, so its capitals are guessed. |
| Stereogum | `/category/album-of-the-week/feed/` | Artist is one of the post's tags. |
| NME | `/reviews/album/feed` | "Artist – 'Album' review: verdict". |
| Billboard | 5 feeds (review tags + main feed), filtered | Few album reviews now (about 5 a year); many "every track ranked" pieces. |
| The Guardian | `/music+tone/albumreview/rss` | Added Nov 2026. Has genre tags; "album of the week/month" labels. |
| The Quietus | `/feed`, items tagged "Reviews" | Added Nov 2026. AVIF images only, so covers come from Apple (about 4 in 7 found). |

## Checked and not used

| Site | Why not (Nov 2026) |
|---|---|
| Rolling Stone (album reviews feed) | Works, but no images and free-form headlines ("U2 Sound Revitalized on 'Carnaval de Luz'"). Overlaps NME/Billboard. A possible later add with Apple covers. |
| Bandcamp Daily | "Album of the Day" works (`Artist, "Album"`, images). Not chosen when The Guardian and The Quietus were picked; a good candidate for independent music. |
| Consequence | Album-review feed empty; main feed is news plus TV/film reviews. |
| BrooklynVegan | Stale (last post 6 Oct 2026); review feed empty. |
| The FADER | No review tagging. |
| Paste | Feed serves unrelated spam. |
| AllMusic | Blog only; new-releases feed blocked (403). |
| The Line of Best Fit, Aquarium Drunkard | No review items in their feeds. |
| Atwood Magazine | "Reviews" are interviews and features. |
| Jazz Journal | No images; several albums per post. |
| Metal Injection, FACT | Stale (last posts April and September 2026). |
| Drowned In Sound, Okayplayer, Popjustice, Mixmag, Riddimstream | Dead or blocked feeds. |

The list at https://rss.feedspot.com/music_rss_feeds/ (about 130 feeds) was
reviewed. About 60 entries are gear, guitar, production, industry,
education or concert sites with no album reviews. Most of the rest are news
or single-track blogs.

## Open decision: specialist sites (paused)

These four passed every check and would fill thin genres. Today the page
has about 4 Hip-hop reviews, 1 Jazz, 1 Global, and almost no Metal or Country.

| Site | Genre | Reviews in feed | Images | Headline format |
|---|---|---|---|---|
| Heavy Blog Is Heavy (`heavyblogisheavy.com/feed/`) | Metal | ~5 | all | "Parius – Alchestronomy" |
| Saving Country Music (`savingcountrymusic.com/feed/`) | Country | ~10 | all | `Album Review – Willi Carlisle's "The Universal Bubba"` |
| No Depression (`nodepression.org/rss/`) | Roots / Americana | ~6 | all | "ALBUM REVIEW: Jake Bugg's 'Alamo' explores…" |
| UK Jazz News (`ukjazznews.com/feed/`) | Jazz | ~9 | rarely (Apple covers) | "Tommy Flanagan – 'Made in Dublin'" |

Louder Than War (`louderthanwar.com/music/feed/`, UK rock/punk) also works,
but has no images and many small releases Apple doesn't have.

No working **hip-hop or electronic** review feed was found, so those stay
thin.

**Pros**

- Genre pills get real content: Metal 0 → ~5, Jazz 1 → ~9, Country/Folk
  ~7 → ~20.
- More "Critics agree" (Willi Carlisle: Stereogum and Saving Country Music).
- "For you" finds more for people with niche taste.

**Cons**

- Lesser-known names than Pitchfork and the like.
- The All view tilts niche. Sites take turns (`interleaveBySource`), so with
  10 sites each big site's pick is every 10th row, and specialist sites make
  up about 40% of All.
- More upkeep: each site's headline format is a parser case that breaks if
  the site changes it.
- The feed grows from ~56 to ~85 albums.

**The open question: how specialist sites should appear in All**

1. Under their genre pill, For you and Critics agree only, not in All
   (keeps the default view to the main six). This was the recommendation.
2. In All, with one turn for every two of the main sites.
3. In All, with equal turns (simplest; about 40% niche).

**To add one:** a `NEWS_SOURCES` entry, a `titleParts` case with tests in
`functions/src/__tests__/news.test.ts`, a name in `musicNewsSources`
(`lib/providers/music_news_provider.dart`), then deploy `refreshMusicNews`
and run `npm run backfill -- --news`.
