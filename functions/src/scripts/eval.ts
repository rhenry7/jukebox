/**
 * Offline accuracy evaluation. Read-only: nothing is written to Firestore.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run eval                # For You
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run eval -- --similar   # "More like this"
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run eval -- --tune      # + search for better weights
 *
 * For You: for each real (non-seed) user, hide each of up to
 * `HOLDOUTS_PER_USER` of their liked reviews in turn, build their list from
 * the rest, and score the top 10 against the hidden review.
 *
 * "More like this": for each liked review A by a real user, rank similar
 * reviews (by other people) and score the top 5 against that user's *other*
 * liked reviews: would someone who loved A also love these?
 *
 * Scores (see src/relevance.ts):
 *   graded  same song 1, same artist 0.6, similar-sounding artist ≤0.5
 *           (ListenBrainz), shared rare tags ≤0.3.
 *   strict  same song or artist only. Doesn't depend on any of our data
 *           sources, so it can't be gamed by them.
 * Each as nDCG (capped at 1) and Hit (any item scoring ≥ 0.5).
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { RANKING, seedUserIds } from "../config";
import { retrieveCandidates } from "../forYou";
import { buildProfile } from "../profile";
import { dcgAtK, gradedGain, ItemInfo, SimilarArtistIndex, strictGain, tagIdf, TagIdf } from "../relevance";
import {
  aspectFit,
  aspectPairs,
  bestPerTrack,
  Candidate,
  diversify,
  features,
  Features,
  jaccard,
  ScoredCandidate,
  weightedScore,
  Weights,
} from "../scoring";
import { loadTagIdf } from "../tagStats";
import { ReviewVector, toReviewVector } from "../store";
import { loadSimilarCorpus, rankSimilar, SimilarCorpus, WEIGHTS as SIMILAR_WEIGHTS } from "../similar";
import { mergedTags, trackKey } from "../text";
import { recencyWeight } from "../vectors";
import { loadProjectEnv } from "./env";

loadProjectEnv();
const args = process.argv.slice(2);
// Only cold-start profiles (no analysed praise) need it; they're skipped without.
const apiKey = process.env.OPENAI_API_KEY ?? "";

const FOR_YOU_K = 10;
const SIMILAR_K = 5;
const HOLDOUTS_PER_USER = 5;
/** A review counts as "liked" at this affinity (≈ 4★). */
const LIKED = 0.5;

initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "juxeboxd" });
const db = getFirestore();

/** Everything the eval needs about the corpus, read once. */
export interface Corpus {
  vectors: ReviewVector[];
  info: Map<string, ItemInfo>;
  similar: SimilarArtistIndex;
  idf: TagIdf;
  seeds: Set<string>;
}

export async function loadCorpus(): Promise<Corpus> {
  const [vectorSnap, reviewSnap, similarSnap] = await Promise.all([
    db.collection("reviewVectors").get(),
    db.collectionGroup("reviews").select("artist", "title", "genres", "tags", "mbTags", "artistMbids").get(),
    db.collection("similarArtists").get(),
  ]);
  const info = new Map<string, ItemInfo>();
  for (const d of reviewSnap.docs) {
    if (!d.ref.path.startsWith("users/")) continue;
    const data = d.data();
    info.set(d.ref.path, {
      trackKey: trackKey(data.artist ?? "", data.title ?? ""),
      artist: data.artist ?? "",
      artistMbids: data.artistMbids ?? [],
      tags: [...mergedTags(data), ...((data.mbTags as string[] | undefined) ?? [])],
    });
  }
  const similar: SimilarArtistIndex = new Map();
  for (const d of similarSnap.docs) {
    const list = (d.get("similar") as { mbid: string; score: number }[] | undefined) ?? [];
    similar.set(d.id, new Map(list.map((s) => [s.mbid, s.score])));
  }
  return {
    vectors: vectorSnap.docs.map(toReviewVector),
    info,
    similar,
    idf: tagIdf([...info.values()].map((i) => i.tags)),
    seeds: seedUserIds(),
  };
}

type Scorer = (rec: ItemInfo, target: ItemInfo) => number;

/** Average graded and strict nDCG / Hit over test cases. */
class Tally {
  private n = 0;
  private sums = { graded: 0, gradedHit: 0, strict: 0, strictHit: 0 };

  add(list: ItemInfo[], targets: ItemInfo[], k: number, corpus: Corpus) {
    // Against several targets (More like this), each item takes its best match.
    const score = (s: Scorer) => list.map((rec) => Math.max(0, ...targets.map((t) => s(rec, t))));
    const graded = dcgAtK(score((r, t) => gradedGain(r, t, corpus.similar, corpus.idf)), k);
    const strict = dcgAtK(score(strictGain), k);
    this.n++;
    this.sums.graded += graded.dcg;
    this.sums.gradedHit += graded.hit;
    this.sums.strict += strict.dcg;
    this.sums.strictHit += strict.hit;
  }

  row(name: string): string {
    const f = (x: number) => (this.n ? x / this.n : 0).toFixed(3).padStart(8);
    const s = this.sums;
    return `${name.padEnd(24)}${f(s.graded)}${f(s.gradedHit)}${f(s.strict)}${f(s.strictHit)}`;
  }

  get count() {
    return this.n;
  }

  means() {
    const d = Math.max(1, this.n);
    return { graded: this.sums.graded / d, strict: this.sums.strict / d };
  }
}

function printTable(title: string, k: number, rows: [string, Tally][]) {
  console.log(`\n${title}: ${rows[0]?.[1].count ?? 0} test cases`);
  console.log(`${"variant".padEnd(24)}${`nDCG@${k}`.padStart(8)}${"Hit".padStart(8)}${"strict".padStart(8)}${"sHit".padStart(8)}`);
  for (const [name, t] of rows) console.log(t.row(name));
}

/** The old app-side recommender, kept as a floor. */
function baseline(all: ReviewVector[], uid: string, own: ReviewVector[], known: Set<string>): ReviewVector[] {
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
  return [...best.values()].sort((a, b) => b.score - a.score).map(({ r }) => r);
}

/** One For You test case, retrieved once and re-scored many ways. */
interface Case {
  target: ItemInfo;
  known: Set<string>;
  items: { candidate: Candidate; features: Features }[];
  baseline: string[];
}

/** For You variants: which candidates and signals to keep. */
const VARIANTS: Record<string, (c: Candidate, f: Features) => Features | null> = {
  full: (_c, f) => f,
  "no listeners-like-you": (c, f) =>
    c.sources.size === 1 && c.sources.has("cf") ? null : { ...f, cf: 0 },
  "no ListenBrainz": (c, f) =>
    [...c.sources].every((s) => s === "artist" || s === "song") ? null : { ...f, artistSim: 0, songSim: 0 },
  "no liked-review seeds": (c, f) =>
    c.sources.size === 1 && c.sources.has("liked") ? null : { ...f, likedSim: 0 },
};

/** Ranked review paths for [c] under [weights] and [variant]. */
function rankCase(c: Case, weights: Weights, variant = VARIANTS.full): string[] {
  const scored: ScoredCandidate[] = [];
  for (const { candidate, features: f } of c.items) {
    const kept = variant(candidate, f);
    if (!kept) continue;
    scored.push({ candidate, score: weightedScore(kept, weights), aspectFit: kept.aspectFit, bestPair: null, reason: "" });
  }
  return diversify(bestPerTrack(scored, c.known), FOR_YOU_K).map((s) => s.candidate.reviewPath);
}

function tallyCases(cases: Case[], corpus: Corpus, rank: (c: Case) => string[]): Tally {
  const t = new Tally();
  for (const c of cases) {
    const list = rank(c)
      .map((p) => corpus.info.get(p))
      .filter((i): i is ItemInfo => !!i);
    t.add(list, [c.target], FOR_YOU_K, corpus);
  }
  return t;
}

async function loadCases(corpus: Corpus): Promise<{ cases: Case[]; skipped: number }> {
  const byUser = new Map<string, ReviewVector[]>();
  corpus.vectors.forEach((r) => byUser.set(r.userId, [...(byUser.get(r.userId) ?? []), r]));
  const idf = await loadTagIdf(db);
  const cases: Case[] = [];
  let skipped = 0;
  for (const [uid, reviews] of byUser) {
    if (corpus.seeds.has(uid)) continue;
    const liked = reviews
      .filter((r) => r.affinity >= LIKED)
      .sort((a, b) => (b.date?.getTime() ?? 0) - (a.date?.getTime() ?? 0));
    // Need something left to learn from after hiding one.
    if (liked.length < 3) continue;
    for (const hidden of liked.slice(0, HOLDOUTS_PER_USER)) {
      const target = corpus.info.get(hidden.reviewPath);
      if (!target) continue;
      let profile;
      try {
        profile = await buildProfile(db, apiKey, uid, { excludeReviewPath: hidden.reviewPath });
      } catch {
        // Cold-start users need an embedding call (OPENAI_API_KEY).
        skipped++;
        continue;
      }
      const now = new Date();
      const candidates = await retrieveCandidates(db, profile);
      cases.push({
        target,
        known: profile.knownTrackKeys,
        // Features once (the expensive part is aspect pairing); drop the vectors.
        items: candidates.map((c) => ({
          candidate: { ...c, aspects: [] },
          features: features(c, aspectFit(aspectPairs(profile!.aspects, c.aspects)), profile!.tags, now, idf),
        })),
        baseline: baseline(
          corpus.vectors,
          uid,
          reviews.filter((r) => r !== hidden),
          profile.knownTrackKeys,
        ).map((r) => r.reviewPath),
      });
    }
    process.stdout.write(".");
  }
  return { cases, skipped };
}

/**
 * Coordinate search over the ranking weights: each weight in turn at
 * 0×, ½×, 1×, 1½×, 2× of its current value, keeping a change only if graded
 * nDCG improves without strict nDCG dropping. Prints the result; it never
 * changes config.ts.
 */
function tune(cases: Case[], corpus: Corpus): Weights {
  const score = (w: Weights) => tallyCases(cases, corpus, (c) => rankCase(c, w)).means();
  let best: Weights = { ...RANKING.weights };
  let bestScore = score(best);
  for (let round = 0; round < 2; round++) {
    for (const key of Object.keys(best) as (keyof Weights)[]) {
      for (const m of [0, 0.5, 1.5, 2]) {
        const base = RANKING.weights[key] || 0.05;
        const trial = { ...best, [key]: Number((base * m).toFixed(3)) };
        const s = score(trial);
        if (s.graded > bestScore.graded + 1e-4 && s.strict >= bestScore.strict - 1e-4) {
          best = trial;
          bestScore = s;
        }
      }
    }
  }
  console.log("\nTuned weights (review before copying into RANKING.weights in config.ts):");
  console.log(JSON.stringify(best, null, 2));
  return best;
}

async function evalForYou(corpus: Corpus) {
  const { cases, skipped } = await loadCases(corpus);
  const rows: [string, Tally][] = [["baseline (old app)", tallyCases(cases, corpus, (c) => c.baseline)]];
  for (const [name, variant] of Object.entries(VARIANTS)) {
    rows.push([name, tallyCases(cases, corpus, (c) => rankCase(c, RANKING.weights, variant))]);
  }
  if (args.includes("--tune")) {
    const tuned = tune(cases, corpus);
    rows.push(["full, tuned weights", tallyCases(cases, corpus, (c) => rankCase(c, tuned))]);
  }
  printTable("For You", FOR_YOU_K, rows);
  if (skipped) console.log(`(${skipped} cases skipped: cold-start profiles need OPENAI_API_KEY)`);
}

/** "More like this" rankers under test: review path → ranked review paths. */
export type SimilarRanker = (path: string, corpus: Corpus) => Promise<string[]>;

/**
 * Port of the app's current `findSimilarReviews` (tags + similar artists),
 * over the in-memory corpus.
 */
export const appSimilar: SimilarRanker = async (path, corpus) => {
  const me = corpus.info.get(path)!;
  const myTags = new Set(me.tags.map((t) => t.toLowerCase()));
  const myWords = new Set([...myTags].flatMap((t) => t.split(" ")));
  const artistScore = new Map<string, number>();
  for (const id of me.artistMbids) {
    artistScore.set(id, 0.9);
    corpus.similar.get(id)?.forEach((s, other) => artistScore.set(other, Math.max(artistScore.get(other) ?? 0, s)));
  }
  const scored: { path: string; score: number }[] = [];
  for (const [p, it] of corpus.info) {
    if (p === path || it.trackKey === me.trackKey) continue;
    const tags = it.tags.map((t) => t.toLowerCase());
    const shared = tags.filter((t) => myTags.has(t)).length;
    const words = new Set(tags.flatMap((t) => t.split(" ")).filter((w) => myWords.has(w))).size;
    const artist = Math.max(0, ...it.artistMbids.map((id) => artistScore.get(id) ?? 0));
    const score = shared * 2 + words + artist * 4;
    if (score > 0) scored.push({ path: p, score });
  }
  return scored.sort((a, b) => b.score - a.score).map((s) => s.path);
};

export async function evalSimilar(
  corpus: Corpus,
  rankers: Record<string, SimilarRanker>,
  opts: { quiet?: boolean } = {},
): Promise<Map<string, Tally>> {
  const authorOf = (path: string) => path.split("/")[1];
  const likedByUser = new Map<string, string[]>();
  for (const r of corpus.vectors) {
    if (r.affinity < LIKED || corpus.seeds.has(r.userId) || !corpus.info.has(r.reviewPath)) continue;
    likedByUser.set(r.userId, [...(likedByUser.get(r.userId) ?? []), r.reviewPath]);
  }
  const tallies = new Map(Object.keys(rankers).map((name) => [name, new Tally()]));
  for (const [uid, liked] of likedByUser) {
    if (liked.length < 2) continue;
    for (const a of liked) {
      const targets = liked.filter((p) => p !== a).map((p) => corpus.info.get(p)!);
      for (const [name, rank] of Object.entries(rankers)) {
        // Other people's reviews only, one per song.
        const seen = new Set<string>();
        const list: ItemInfo[] = [];
        for (const p of await rank(a, corpus)) {
          const it = corpus.info.get(p);
          if (!it || authorOf(p) === uid || seen.has(it.trackKey)) continue;
          seen.add(it.trackKey);
          list.push(it);
          if (list.length === SIMILAR_K) break;
        }
        tallies.get(name)!.add(list, targets, SIMILAR_K, corpus);
      }
    }
  }
  if (!opts.quiet) printTable('"More like this"', SIMILAR_K, [...tallies]);
  return tallies;
}

/** Coordinate search over similar.ts WEIGHTS, like [tune]. Prints; never edits code. */
async function tuneSimilar(corpus: Corpus, server: SimilarCorpus): Promise<typeof SIMILAR_WEIGHTS> {
  const score = async (w: typeof SIMILAR_WEIGHTS) => {
    const t = await evalSimilar(
      corpus,
      { x: async (path) => rankSimilar(path, server, { keep: 50, weights: w }).map((s) => s.reviewPath) },
      { quiet: true },
    );
    return t.get("x")!.means();
  };
  let best = { ...SIMILAR_WEIGHTS };
  let bestScore = await score(best);
  for (let round = 0; round < 2; round++) {
    for (const key of Object.keys(best) as (keyof typeof SIMILAR_WEIGHTS)[]) {
      for (const m of [0, 0.5, 1.5, 2]) {
        const trial = { ...best, [key]: Number(((SIMILAR_WEIGHTS[key] || 0.05) * m).toFixed(3)) };
        const s = await score(trial);
        if (s.graded > bestScore.graded + 1e-4 && s.strict >= bestScore.strict - 1e-4) {
          best = trial;
          bestScore = s;
        }
      }
    }
  }
  console.log('\nTuned "More like this" weights (review before copying into WEIGHTS in similar.ts):');
  console.log(JSON.stringify(best, null, 2));
  return best;
}

async function main() {
  const corpus = await loadCorpus();
  const tagged = [...corpus.info.values()].filter((i) => i.tags.length).length;
  console.log(
    `${corpus.vectors.length} analysed reviews, ${corpus.info.size} reviews (${tagged} with tags), ` +
      `${corpus.similar.size} similar-artist lists, ${corpus.seeds.size} seed account(s) excluded as test users`,
  );
  if (args.includes("--similar")) {
    const server = await loadSimilarCorpus(db);
    const rankers: Record<string, SimilarRanker> = {
      "app (tags+artists)": appSimilar,
      "server (similar.ts)": async (path) => rankSimilar(path, server, { keep: 50 }).map((s) => s.reviewPath),
    };
    if (args.includes("--tune")) {
      const tuned = await tuneSimilar(corpus, server);
      rankers["server, tuned"] = async (path) =>
        rankSimilar(path, server, { keep: 50, weights: tuned }).map((s) => s.reviewPath);
    }
    await evalSimilar(corpus, rankers);
  } else {
    await evalForYou(corpus);
    console.log(`\n(pool sizes: ${RANKING.aspectHitsPerInterest}/interest, ${RANKING.styleHitsPerQuery}/style query)`);
  }
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
