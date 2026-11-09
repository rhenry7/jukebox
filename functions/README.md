# REVERB recommendation functions

Server-side CF-RAG recommender for the For You tab and the post-review
"Because you just reviewed X" sheet.

## How it works

| When | What runs | AI cost |
|---|---|---|
| A review is created or edited (`onReviewWritten`), before analysis | Looks up the song's MusicBrainz IDs (`recordingMbid`, `artistMbids` on the review) and caches each artist's similar artists from ListenBrainz in `similarArtists/{artistMbid}` (refreshed monthly) | 0 (free APIs, no key) |
| A review is created or edited (`onReviewWritten`) | LLM reads the whole review → overall polarity, tone, aspects (`{category, statement, polarity, quote}`); embeds the review and each aspect; then rebuilds the author's For You | 1 chat call + 1 embedding request (+1 rerank call if `RERANK_ENABLED`) |
| User posts a review (`analyzeAndMatch` callable) | Waits for the analysis above, then finds other reviews that praise what this review praises | none extra |
| Pull-to-refresh (`refreshForYou` callable) | Re-runs retrieval + ranking, throttled to once a minute | 0 |
| Nightly 04:00 ET (`nightlyRefresh`) | Rebuilds lookalike listeners, refreshes For You for users active in the last 30 days (LLM rerank at most weekly) | 0 (or weekly rerank) |
| Opening For You in the app | Reads `users/{uid}/forYou/current` | 0 |

Retrieval searches the whole corpus with Firestore vector search. Matching is
polarity-aware: praise matches praise, complaint matches complaint, and a
review celebrating what the user complained about is penalised. A fourth
source adds reviews of artists that *sound like* ones the user rated highly
(ListenBrainz's listening-based similar artists, `similarArtistSignal`),
weighted by `RANKING.weights.artistSim`, with the reason "Sounds like X,
which you rated highly". The app's "More like this" row reads the same
`similarArtists` cache, and onboarding uses it to suggest more artists.

| File | Purpose |
|---|---|
| `src/analysis.ts` | Write-time analysis + embeddings (idempotent via content hash) |
| `src/profile.ts` | The user's interests (k-means over praised aspects), complaints, known tracks |
| `src/forYou.ts` | Candidate retrieval (aspect, style, CF, similar artists) → ranking → cache |
| `src/musicbrainz.ts` | MusicBrainz IDs on reviews, ListenBrainz similar-artist cache |
| `src/scoring.ts` | Pure ranking logic (unit-tested) |
| `src/match.ts` | Post-review item-to-item matches |
| `src/neighbors.ts` | User-based collaborative filtering |
| `src/rerank.ts` | Optional LLM rerank + explanations (`RERANK_ENABLED`) |
| `src/scripts/backfill.ts` | Analyse existing reviews; `--search-keys`, `--mbids` for the index fields and MusicBrainz IDs |
| `src/scripts/eval.ts` | Leave-one-out HitRate@10 / NDCG@10 |

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

## Develop

```
npm install
npm test        # compiles and runs the unit tests
```
