/**
 * Offline leave-one-out evaluation (plan phase 2). For each user with ≥ 5
 * positive reviews, hide their newest positive review, build recommendations
 * from the rest, and check whether the hidden track comes back in the top 10.
 *
 *   OPENAI_API_KEY=… GOOGLE_APPLICATION_CREDENTIALS=… npm run eval [-- --rerank]
 *
 * Read-only: nothing is written to Firestore. --rerank adds LLM calls.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { RANKING } from "../config";
import { rankForProfile } from "../forYou";
import { buildProfile } from "../profile";
import { jaccard } from "../scoring";
import { ReviewVector, toReviewVector } from "../store";
import { recencyWeight } from "../vectors";

const K = 10;
const withRerank = process.argv.includes("--rerank");
const apiKey = process.env.OPENAI_API_KEY ?? "";

initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "juxeboxd" });
const db = getFirestore();

interface Ranked {
  trackKey: string;
  artist: string;
}

/** Full credit for the hidden track, half for another track by the same artist. */
function gain(r: Ranked, hidden: ReviewVector): number {
  if (r.trackKey === hidden.trackKey) return 1;
  return r.artist.toLowerCase() === hidden.artist.toLowerCase() ? 0.5 : 0;
}

function metrics(list: Ranked[], hidden: ReviewVector) {
  const top = list.slice(0, K);
  const gains = top.map((r) => gain(r, hidden));
  const best = Math.max(0, ...gains);
  const dcg = gains.reduce((s, g, i) => s + g / Math.log2(i + 2), 0);
  return { hit: best, ndcg: Math.min(1, dcg) }; // ideal DCG = 1 (one relevant item at rank 1)
}

/** Today's app logic (tag/artist/rating/recency on the whole corpus) as the baseline. */
function baseline(all: ReviewVector[], uid: string, own: ReviewVector[], known: Set<string>): Ranked[] {
  const liked = own.filter((r) => r.affinity > 0);
  const tags = [...new Set(liked.flatMap((r) => r.tags.map((t) => t.toLowerCase())))];
  const artists = new Set(liked.map((r) => r.artist.toLowerCase()));
  const best = new Map<string, { score: number; r: ReviewVector }>();
  for (const r of all) {
    if (r.userId === uid || known.has(r.trackKey) || r.stars < 3) continue;
    const score =
      0.4 * jaccard(r.tags, tags) +
      0.25 * (artists.has(r.artist.toLowerCase()) ? 1 : 0) +
      0.15 * (r.stars / 5) +
      0.1 * recencyWeight(r.date, 90);
    const prev = best.get(r.trackKey);
    if (!prev || score > prev.score) best.set(r.trackKey, { score, r });
  }
  return [...best.values()]
    .sort((a, b) => b.score - a.score)
    .map(({ r }) => ({ trackKey: r.trackKey, artist: r.artist }));
}

async function main() {
  const all = (await db.collection("reviewVectors").get()).docs.map(toReviewVector);
  const byUser = new Map<string, ReviewVector[]>();
  all.forEach((r) => byUser.set(r.userId, [...(byUser.get(r.userId) ?? []), r]));
  const reviewersByTrack = new Map<string, Set<string>>();
  all.forEach((r) => reviewersByTrack.set(r.trackKey, (reviewersByTrack.get(r.trackKey) ?? new Set()).add(r.userId)));

  const variants = ["baseline", "semantic", "semantic+cf", ...(withRerank ? ["semantic+cf+rerank"] : [])];
  const totals = Object.fromEntries(variants.map((v) => [v, { hit: 0, ndcg: 0 }]));
  let evaluated = 0;
  let unrecoverable = 0;

  for (const [uid, reviews] of byUser) {
    const positives = reviews
      .filter((r) => r.affinity > 0)
      .sort((a, b) => (b.date?.getTime() ?? 0) - (a.date?.getTime() ?? 0));
    if (positives.length < 5) continue;
    const hidden = positives[0];
    // Only someone else's review of the hidden track can bring it back.
    if (([...(reviewersByTrack.get(hidden.trackKey) ?? [])].filter((u) => u !== uid).length) === 0) {
      unrecoverable++;
      continue;
    }
    evaluated++;

    const profile = await buildProfile(db, apiKey, uid, { excludeReviewPath: hidden.reviewPath });
    const results: Record<string, Ranked[]> = {
      baseline: baseline(
        all,
        uid,
        reviews.filter((r) => r !== hidden),
        profile.knownTrackKeys,
      ),
    };
    const toRanked = (list: Awaited<ReturnType<typeof rankForProfile>>) =>
      list.map((s) => ({ trackKey: s.candidate.trackKey, artist: s.candidate.artist }));
    results.semantic = toRanked(await rankForProfile(db, apiKey, profile, { disableCf: true, size: K }));
    results["semantic+cf"] = toRanked(await rankForProfile(db, apiKey, profile, { size: K }));
    if (withRerank) {
      results["semantic+cf+rerank"] = toRanked(await rankForProfile(db, apiKey, profile, { size: K, rerank: true }));
    }

    for (const v of variants) {
      const m = metrics(results[v], hidden);
      totals[v].hit += m.hit;
      totals[v].ndcg += m.ndcg;
    }
  }

  console.log(`Users evaluated: ${evaluated} (skipped ${unrecoverable} whose hidden track nobody else reviewed)`);
  if (evaluated === 0) return;
  console.log(`\nvariant                 HitRate@${K}  NDCG@${K}`);
  for (const v of variants) {
    const t = totals[v];
    console.log(`${v.padEnd(22)}  ${(t.hit / evaluated).toFixed(3)}       ${(t.ndcg / evaluated).toFixed(3)}`);
  }
  console.log(`\n(pool sizes: ${RANKING.aspectHitsPerInterest}/interest, ${RANKING.styleHitsPerQuery}/style query)`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
