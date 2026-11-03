/**
 * Deterministic ranking (plan "Scoring"). Pure functions only — everything
 * here is unit-tested without Firestore or OpenAI.
 */
import { RANKING } from "./config";
import { cosine, recencyWeight, Vec } from "./vectors";

export interface Aspect {
  category: string;
  statement: string;
  /** -1 (complaint) … 1 (praise), judged in the context of the whole review. */
  polarity: number;
  embedding: Vec;
}

/** One of the active user's own aspects, with the review it came from. */
export interface UserAspect extends Aspect {
  reviewTitle: string;
}

export type Source = "aspect" | "style" | "cf";

export interface Candidate {
  reviewPath: string;
  userId: string;
  trackKey: string;
  artist: string;
  title: string;
  tags: string[];
  stars: number;
  affinity: number;
  date: Date | null;
  likes: number;
  /** Characters in the review text (null = unknown, scored as neutral). */
  textLength: number | null;
  aspects: Aspect[];
  /** Best review-level similarity to one of the user's positive reviews (0 if not retrieved that way). */
  styleSim: number;
  /** Title of the user's review that `styleSim` came from. */
  styleMatchTitle?: string;
  /** 0–1: how strongly the user's neighbours vouch for this review's track. */
  cf: number;
  sources: Set<Source>;
}

export interface AspectPair {
  user: UserAspect;
  candidate: Aspect;
  similarity: number;
  /** similarity × A_pol × C_pol: praise↔praise and complaint↔complaint add, praise↔complaint subtracts. */
  contribution: number;
}

export interface ScoredCandidate {
  candidate: Candidate;
  score: number;
  aspectFit: number;
  bestPair: AspectPair | null;
  reason: string;
}

/** Embedding cosines for unrelated text sit around 0.1–0.25; treat that as zero. */
const SIM_FLOOR = 0.25;
export function rescaleSim(cos: number): number {
  return Math.max(0, (cos - SIM_FLOOR) / (1 - SIM_FLOOR));
}

/**
 * Pairs each candidate aspect with the user's most similar aspect (by topic),
 * then signs the match by both polarities. "Loved the muddy bass" matched to
 * the user's "bass was way too muddy" therefore counts *against* the review.
 */
export function aspectPairs(userAspects: UserAspect[], candidateAspects: Aspect[]): AspectPair[] {
  if (userAspects.length === 0) return [];
  return candidateAspects.map((c) => {
    let best = userAspects[0];
    let bestSim = -Infinity;
    for (const u of userAspects) {
      const s = cosine(u.embedding, c.embedding);
      if (s > bestSim) {
        bestSim = s;
        best = u;
      }
    }
    const similarity = rescaleSim(bestSim);
    const contribution = similarity === 0 ? 0 : similarity * best.polarity * c.polarity;
    return { user: best, candidate: c, similarity, contribution };
  });
}

/** Mean contribution of the 3 most on-topic pairs; in [-1, 1]. */
export function aspectFit(pairs: AspectPair[]): number {
  const top = [...pairs].sort((a, b) => b.similarity - a.similarity).slice(0, 3);
  if (top.length === 0) return 0;
  return top.reduce((s, p) => s + p.contribution, 0) / top.length;
}

export function jaccard(a: string[], b: string[]): number {
  if (a.length === 0 || b.length === 0) return 0;
  const A = new Set(a.map((x) => x.toLowerCase()));
  const B = new Set(b.map((x) => x.toLowerCase()));
  let inter = 0;
  A.forEach((x) => {
    if (B.has(x)) inter++;
  });
  return inter / (A.size + B.size - inter);
}

/** Reviewer's stars plus how much the community liked the review. */
export function quality(stars: number, likes: number): number {
  return 0.7 * (stars / 5) + 0.3 * Math.min(1, Math.log1p(likes) / Math.log(20));
}

/**
 * -1 for reviews under `minReviewLength` (a one-liner says little about the
 * music), 0 at the threshold, rising to 1 at `fullDepthLength`.
 */
export function depth(textLength: number | null): number {
  if (textLength === null) return 0;
  if (textLength < RANKING.minReviewLength) return -1;
  return Math.min(1, (textLength - RANKING.minReviewLength) / (RANKING.fullDepthLength - RANKING.minReviewLength));
}

export function scoreCandidate(
  c: Candidate,
  userAspects: UserAspect[],
  userTags: string[],
  now = new Date(),
): ScoredCandidate {
  const w = RANKING.weights;
  const pairs = aspectPairs(userAspects, c.aspects);
  const fit = aspectFit(pairs);
  const score =
    w.aspectFit * fit +
    w.styleSim * c.styleSim +
    w.cf * c.cf +
    w.affinity * c.affinity +
    w.tagOverlap * jaccard(c.tags, userTags) +
    w.quality * quality(c.stars, c.likes) +
    w.recency * recencyWeight(c.date, RANKING.recencyHalfLifeDays, now) +
    w.depth * depth(c.textLength);
  const bestPair = pairs.reduce<AspectPair | null>(
    (best, p) => (p.contribution > (best?.contribution ?? 0) ? p : best),
    null,
  );
  return { candidate: c, score, aspectFit: fit, bestPair, reason: reasonFor(c, bestPair, fit) };
}

/** Always-available, no-AI explanation from the strongest signal. */
export function reasonFor(c: Candidate, bestPair: AspectPair | null, fit: number): string {
  if (bestPair && bestPair.contribution >= 0.15 && fit >= c.styleSim * 0.5) {
    const { user, candidate } = bestPair;
    return candidate.polarity > 0
      ? `Also praises ${candidate.statement}, like your review of ${user.reviewTitle}`
      : `Also calls out ${candidate.statement}, like you did on ${user.reviewTitle}`;
  }
  if (c.styleMatchTitle && c.styleSim >= c.cf) {
    return `Reads a lot like your review of ${c.styleMatchTitle}`;
  }
  if (c.cf > 0) return "Loved by listeners who rate music like you";
  return "Matches the music you write about";
}

/**
 * One entry per track: the best-scoring positive review is the "qualifier"
 * shown on the card. Tracks the user already knows are dropped.
 */
export function bestPerTrack(scored: ScoredCandidate[], excludeTrackKeys: Set<string>): ScoredCandidate[] {
  const byTrack = new Map<string, ScoredCandidate>();
  for (const s of scored) {
    const c = s.candidate;
    if (c.affinity <= 0 || excludeTrackKeys.has(c.trackKey)) continue;
    const prev = byTrack.get(c.trackKey);
    if (!prev || s.score > prev.score) byTrack.set(c.trackKey, s);
  }
  return [...byTrack.values()].sort((a, b) => b.score - a.score);
}

function itemSimilarity(a: Candidate, b: Candidate): number {
  if (a.artist.toLowerCase() === b.artist.toLowerCase()) return 1;
  return jaccard(a.tags, b.tags);
}

/**
 * Maximal Marginal Relevance: trades a little score for variety, and allows
 * at most one track per artist in the first `artistCapTopN` slots.
 */
export function diversify(
  ranked: ScoredCandidate[],
  size: number,
  lambda: number = RANKING.mmrLambda,
  artistCapTopN: number = RANKING.artistCapTopN,
): ScoredCandidate[] {
  if (ranked.length === 0) return [];
  const max = Math.max(...ranked.map((r) => r.score));
  const min = Math.min(...ranked.map((r) => r.score));
  const relevance = (r: ScoredCandidate) => (max === min ? 1 : (r.score - min) / (max - min));

  const pool = [...ranked];
  const picked: ScoredCandidate[] = [];
  while (picked.length < size && pool.length > 0) {
    const capArtists = picked.length < artistCapTopN;
    const usedArtists = new Set(picked.map((p) => p.candidate.artist.toLowerCase()));
    let bestIdx = -1;
    let bestVal = -Infinity;
    pool.forEach((r, i) => {
      if (capArtists && usedArtists.has(r.candidate.artist.toLowerCase())) return;
      const redundancy = picked.length
        ? Math.max(...picked.map((p) => itemSimilarity(p.candidate, r.candidate)))
        : 0;
      const val = lambda * relevance(r) - (1 - lambda) * redundancy;
      if (val > bestVal) {
        bestVal = val;
        bestIdx = i;
      }
    });
    // Only same-artist items left inside the capped window: lift the cap.
    if (bestIdx < 0) bestIdx = 0;
    picked.push(pool.splice(bestIdx, 1)[0]);
  }
  return picked;
}

/**
 * Blends the LLM's 0–1 fit with the normalised deterministic score for the
 * reranked pool, drops weak stylistic matches, and keeps everything the LLM
 * didn't see after it in the original order.
 */
export function blendRerank(
  ranked: ScoredCandidate[],
  fits: Map<string, { fit: number; reason: string }>,
  blend: number = RANKING.rerankBlend,
  minFit: number = RANKING.rerankMinFit,
): ScoredCandidate[] {
  const seen = ranked.filter((r) => fits.has(r.candidate.reviewPath));
  const unseen = ranked.filter((r) => !fits.has(r.candidate.reviewPath));
  if (seen.length === 0) return ranked;
  const max = Math.max(...seen.map((r) => r.score));
  const min = Math.min(...seen.map((r) => r.score));
  const normScore = (s: number) => (max === min ? 1 : (s - min) / (max - min));
  const reranked = seen
    .filter((r) => fits.get(r.candidate.reviewPath)!.fit >= minFit)
    .map((r) => {
      const f = fits.get(r.candidate.reviewPath)!;
      return { ...r, score: blend * f.fit + (1 - blend) * normScore(r.score), reason: f.reason || r.reason };
    })
    .sort((a, b) => b.score - a.score);
  return [...reranked, ...unseen];
}
