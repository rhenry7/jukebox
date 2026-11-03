# REVERB recommendation functions

Server-side CF-RAG recommender for the For You tab and the post-review
"Because you just reviewed X" sheet.

## How it works

| When | What runs | AI cost |
|---|---|---|
| A review is created or edited (`onReviewWritten`) | LLM reads the whole review → overall polarity, tone, aspects (`{category, statement, polarity, quote}`); embeds the review and each aspect; then rebuilds the author's For You | 1 chat call + 1 embedding request (+1 rerank call if `RERANK_ENABLED`) |
| User posts a review (`analyzeAndMatch` callable) | Waits for the analysis above, then finds other reviews that praise what this review praises | none extra |
| Pull-to-refresh (`refreshForYou` callable) | Re-runs retrieval + ranking, throttled to once a minute | 0 |
| Nightly 04:00 ET (`nightlyRefresh`) | Rebuilds lookalike listeners, refreshes For You for users active in the last 30 days (LLM rerank at most weekly) | 0 (or weekly rerank) |
| Opening For You in the app | Reads `users/{uid}/forYou/current` | 0 |

Retrieval searches the whole corpus with Firestore vector search. Matching is
polarity-aware: praise matches praise, complaint matches complaint, and a
review celebrating what the user complained about is penalised.

| File | Purpose |
|---|---|
| `src/analysis.ts` | Write-time analysis + embeddings (idempotent via content hash) |
| `src/profile.ts` | The user's interests (k-means over praised aspects), complaints, known tracks |
| `src/forYou.ts` | Candidate retrieval (aspect, style, CF) → ranking → cache |
| `src/scoring.ts` | Pure ranking logic (unit-tested) |
| `src/match.ts` | Post-review item-to-item matches |
| `src/neighbors.ts` | User-based collaborative filtering |
| `src/rerank.ts` | Optional LLM rerank + explanations (`RERANK_ENABLED`) |
| `src/scripts/backfill.ts` | Analyse existing reviews |
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

## Develop

```
npm install
npm test        # compiles and runs the unit tests
```
