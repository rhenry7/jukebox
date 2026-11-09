# REVERB recommendation functions

Server-side CF-RAG recommender for the For You tab and the post-review
"Because you just reviewed X" sheet.

## How it works

| When | What runs | AI cost |
|---|---|---|
| A review is created or edited (`onReviewWritten`), before analysis | Looks up the song's MusicBrainz IDs (`recordingMbid`, `artistMbids` on the review) and caches each artist's similar artists from ListenBrainz in `similarArtists/{artistMbid}` (refreshed monthly) | 0 (free APIs, no key) |
| A review is created or edited (`onReviewWritten`) | LLM reads the whole review → overall polarity, tone, aspects (`{category, statement, polarity, quote}`); embeds the review and each aspect; then rebuilds the author's For You | 1 chat call + 1 embedding request (+1 rerank call if `RERANK_ENABLED`) |
| User posts a review (`analyzeAndMatch` callable) | Waits for the analysis above, then finds other reviews that praise what this review praises | none extra |
| Onboarding / preferences saved (`onPreferencesWritten`) | Resolves favourite artists to MusicBrainz IDs (similar-artist cold start) and builds For You | 0 (cold-start embedding only if no reviews) |
| "Not for me" on a For You card (`onForYouFeedback`) | Rebuilds For You without that song; its artist and similar ones rank lower | 0 |
| Pull-to-refresh (`refreshForYou` callable) | Re-runs retrieval + ranking, throttled to once a minute | 0 |
| Nightly 04:00 ET (`nightlyRefresh`) | Rebuilds lookalike listeners (seed accounts excluded), tag rarity (`stats/tags`), every review's "More like this" (`similarReviews`), and For You for users active in the last 30 days (LLM rerank at most weekly) | 0 (or weekly rerank) |
| Opening For You in the app | Reads `users/{uid}/forYou/current` | 0 |

Retrieval searches the whole corpus with Firestore vector search. Matching is
polarity-aware: praise matches praise, complaint matches complaint, and a
review celebrating what the user complained about is penalised. A fourth
source adds reviews of artists that *sound like* ones the user rated highly
(ListenBrainz's listening-based similar artists, `similarArtistSignal`),
weighted by `RANKING.weights.artistSim`, with the reason "Sounds like X,
which you rated highly"; a fifth adds reviews of similar *songs*
(`similarRecordings`). Onboarding uses the same cache to suggest more
artists.

What feeds a user's profile besides their own reviews (`implicit.ts`): likes,
comments, reposts and bookmarks of other people's reviews count as weaker
"I liked this" (0.3–0.6), and "Not for me" (`users/{uid}/forYouFeedback`) as
a dislike. Shared tags are weighted by rarity (`tagStats.ts`), and include
`mbTags`, genres filled in from ListenBrainz for reviews whose authors left
none (never shown as the author's tags). Seed / test accounts
(`SEED_USER_IDS` in `.env.juxeboxd`) are never anyone's "listener like you".
Each review also gets hidden era metadata (`era.ts`): `releaseYear` (first
release, from MusicBrainz) and `metaTags` such as `decade:1970s`,
`era:classic`. For You scores how well a song's year fits the eras the user
loves (`eraFit`); "More like this" adds a same-era bonus to musical matches.

"More like this" (`similar.ts`) is computed here too: every review scored
against every other on similar artist, similar song, rare shared tags and
how alike the texts read, cached per review in `similarReviews/{id}` with a
reason the app shows as a chip.

| File | Purpose |
|---|---|
| `src/analysis.ts` | Write-time analysis + embeddings (idempotent via content hash) |
| `src/profile.ts` | The user's interests (k-means over praised aspects), complaints, known tracks |
| `src/forYou.ts` | Candidate retrieval (aspect, style, CF, similar artists) → ranking → cache |
| `src/musicbrainz.ts` | MusicBrainz IDs, filled-in tags (`mbTags`), similar artist / song caches, onboarding favourites |
| `src/similar.ts` | "More like this" per review |
| `src/implicit.ts` | Likes / bookmarks / reposts / comments / "Not for me" as taste signals |
| `src/relevance.ts`, `src/tagStats.ts` | Rare-tag weighting; graded relevance for the eval |
| `src/scoring.ts` | Pure ranking logic (unit-tested) |
| `src/match.ts` | Post-review item-to-item matches |
| `src/neighbors.ts` | User-based collaborative filtering |
| `src/rerank.ts` | Optional LLM rerank + explanations (`RERANK_ENABLED`) |
| `src/scripts/backfill.ts` | Analyse existing reviews; `--search-keys`, `--mbids` for the index fields and MusicBrainz IDs |
| `src/scripts/eval.ts` | Accuracy: For You (leave-one-out) and `--similar`; `--tune` searches weights |

## First deploy

1. **Rotate the OpenAI key** (the old one was in the public web bundle) and
   make sure the Firebase project is on the **Blaze** plan.
2. Update the CLI (vector indexes and Node 20 need a recent version):
   `npm install -g firebase-tools`
3. Store the new key as a secret:
   `firebase functions:secrets:set OPENAI_API_KEY`
4. Deploy rules, indexes and functions:
   `firebase deploy --only firestore:rules,firestore:indexes,functions`
   Vector indexes take a few minutes to build; check the Firestore console.
5. Backfill existing reviews (uses your gcloud credentials):
   ```
   cd functions
   gcloud auth application-default login
   OPENAI_API_KEY=… npm run backfill -- --dry-run   # prints 5 sample analyses, writes nothing
   OPENAI_API_KEY=… npm run backfill -- --for-you   # analyse all, then build every For You
   ```
6. Measure: `OPENAI_API_KEY=… npm run eval` (add `-- --rerank` to test the LLM step).
   Turn the rerank on only if it beats `semantic+cf`: put
   `RERANK_ENABLED=true` in `functions/.env` and redeploy the functions.

## Similar artists (MusicBrainz + ListenBrainz)

New reviews get their IDs automatically once the functions are deployed. For
existing reviews (about one review a second; no OpenAI key):

```
cd functions
GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --mbids --dry-run   # counts, writes nothing
GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --mbids
```

Deploy `firestore:rules` (public read of `similarArtists`) and
`firestore:indexes` (`artistMbids` + `date` on `reviews`) first. The
similar-artist dataset is on ListenBrainz's experimental "labs" server
(`SIMILAR_ARTISTS_ALGORITHM`); if it changes, fetches fail and cached lists
keep working until updated. The app has a copy of that name in
`lib/services/similar_artists_service.dart`.

## Measuring accuracy

```
GOOGLE_APPLICATION_CREDENTIALS=… npm run eval                       # For You
GOOGLE_APPLICATION_CREDENTIALS=… npm run eval -- --similar          # "More like this"
… npm run eval -- --tune   /   … npm run eval -- --similar --tune     # search for better weights
```

Read-only. Real (non-seed) users' liked reviews are held out one at a time
and scored against what comes back: **graded** counts the same song (1),
same artist (0.6), a similar-sounding artist (≤0.5) or shared rare tags
(≤0.3); **strict** counts only the same song or artist, so it can't be
inflated by our own similarity data. `--tune` prints better weights; copy
them into `RANKING.weights` / `similar.ts` only if both scores improve.
Run it before and after any ranking change.

Other backfills: `--similar` (every review's "More like this"),
`--favorites` (onboarding artists), `--neighbors` (lookalike listeners now).

## Develop

```
npm install
npm test        # compiles and runs the unit tests
```
