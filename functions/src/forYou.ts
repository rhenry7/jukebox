/**
 * For You (plan phases 4–6): retrieve ~300 candidates from three sources over
 * the whole corpus, score them deterministically, optionally rerank the top
 * 30 with the LLM, diversify, and cache the result for the app to read.
 */
import { FieldValue, Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { COLLECTIONS, RANKING } from "./config";
import { buildProfile, Profile, tasteCentroid } from "./profile";
import { rerank } from "./rerank";
import {
  bestPerTrack,
  blendRerank,
  Candidate,
  diversify,
  rescaleSim,
  ScoredCandidate,
  scoreCandidate,
  Source,
} from "./scoring";
import {
  AspectHit,
  aspectsByReview,
  nearestAspects,
  nearestReviews,
  ReviewVector,
  reviewVectorsByPath,
  reviewVectorsByUser,
} from "./store";
import { cosine } from "./vectors";

export interface ForYouItem {
  trackKey: string;
  reviewPath: string;
  score: number;
  reason: string;
  sources: Source[];
}

export interface ForYouOptions {
  /** Leave-one-out evaluation: pretend this review doesn't exist. */
  excludeReviewPath?: string;
  rerank?: boolean;
  write?: boolean;
  size?: number;
  /** Evaluation only: skip the lookalike-listener channel. */
  disableCf?: boolean;
}

/** Neighbours' liked tracks: trackKey → 0–1 strength. */
async function collaborativeSignal(db: Firestore, userId: string): Promise<Map<string, number>> {
  const snap = await db.collection(COLLECTIONS.userVectors).doc(userId).get();
  const neighbors: { uid: string; sim: number }[] = snap.get("neighbors") ?? [];
  const byTrack = new Map<string, number>();
  const lists = await Promise.all(neighbors.map((n) => reviewVectorsByUser(db, n.uid)));
  neighbors.forEach((n, i) => {
    for (const r of lists[i]) {
      if (r.affinity < RANKING.neighborMinAffinity) continue;
      const v = n.sim * r.affinity;
      byTrack.set(r.trackKey, Math.max(byTrack.get(r.trackKey) ?? 0, v));
    }
  });
  return byTrack;
}

export async function retrieveCandidates(
  db: Firestore,
  profile: Profile,
  opts: Pick<ForYouOptions, "disableCf"> = {},
): Promise<Candidate[]> {
  const sources = new Map<string, Set<Source>>();
  const tag = (path: string, s: Source) => {
    const set = sources.get(path) ?? new Set<Source>();
    set.add(s);
    sources.set(path, set);
  };

  const interests = profile.interests.slice(0, RANKING.maxInterests);
  const styleQueries = profile.positiveReviews.slice(0, RANKING.styleQueries);

  const [aspectHits, styleHits, cfByTrack] = await Promise.all([
    Promise.all([
      // Praise ↔ praise: other reviews celebrating what this user celebrates.
      ...interests.map((i) => nearestAspects(db, i.centroid, "pos", RANKING.aspectHitsPerInterest)),
      // Complaint ↔ complaint: shared dislikes are a strong taste signal.
      ...(profile.negCentroid
        ? [nearestAspects(db, profile.negCentroid, "neg", RANKING.aspectHitsPerNegative)]
        : []),
    ]).then((lists) => lists.flat()),
    Promise.all(styleQueries.map((r) => nearestReviews(db, r.embedding, RANKING.styleHitsPerQuery))).then(
      (lists) => lists.flat(),
    ),
    opts.disableCf ? Promise.resolve(new Map<string, number>()) : collaborativeSignal(db, profile.userId),
  ]);

  aspectHits.forEach((h: AspectHit) => tag(h.reviewPath, "aspect"));
  styleHits.forEach((r) => tag(r.reviewPath, "style"));

  // CF: pull in every indexed review of a track the user's neighbours loved.
  const cfTracks = [...cfByTrack.keys()].filter((k) => !profile.knownTrackKeys.has(k));
  for (let i = 0; i < cfTracks.length; i += 30) {
    const snap = await db
      .collection(COLLECTIONS.reviewVectors)
      .where("trackKey", "in", cfTracks.slice(i, i + 30))
      .select("reviewPath")
      .get();
    snap.docs.forEach((d) => tag(d.get("reviewPath"), "cf"));
  }

  const known = new Map<string, ReviewVector>(styleHits.map((r) => [r.reviewPath, r]));
  const missing = [...sources.keys()].filter((p) => !known.has(p));
  (await reviewVectorsByPath(db, missing)).forEach((r) => known.set(r.reviewPath, r));

  const reviews = [...known.values()].filter(
    (r) => r.userId !== profile.userId && sources.has(r.reviewPath) && !profile.knownTrackKeys.has(r.trackKey),
  );
  const aspectMap = await aspectsByReview(
    db,
    reviews.map((r) => r.reviewPath),
  );

  return reviews.map((r) => {
    let styleSim = 0;
    let styleMatchTitle: string | undefined;
    for (const own of styleQueries) {
      const s = rescaleSim(cosine(own.embedding, r.embedding));
      if (s > styleSim) {
        styleSim = s;
        styleMatchTitle = own.title;
      }
    }
    return {
      reviewPath: r.reviewPath,
      userId: r.userId,
      trackKey: r.trackKey,
      artist: r.artist,
      title: r.title,
      tags: r.tags,
      stars: r.stars,
      affinity: r.affinity,
      date: r.date,
      likes: r.likes,
    textLength: r.textLength,
      aspects: aspectMap.get(r.reviewPath) ?? [],
      styleSim,
      styleMatchTitle,
      cf: cfByTrack.get(r.trackKey) ?? 0,
      sources: sources.get(r.reviewPath)!,
    };
  });
}

export async function rankForProfile(
  db: Firestore,
  apiKey: string,
  profile: Profile,
  opts: ForYouOptions,
): Promise<ScoredCandidate[]> {
  const candidates = await retrieveCandidates(db, profile, opts);
  const scored = candidates.map((c) => scoreCandidate(c, profile.aspects, profile.tags));
  let ranked = bestPerTrack(scored, profile.knownTrackKeys);

  if (opts.rerank && ranked.length > 0) {
    const pool = ranked.slice(0, RANKING.rerankPoolSize);
    try {
      const texts = new Map<string, string>();
      const snaps = await db.getAll(...pool.map((s) => db.doc(s.candidate.reviewPath)));
      snaps.forEach((s) => s.exists && texts.set(s.ref.path, s.get("review") ?? ""));
      const fits = await rerank(apiKey, profile, pool, texts);
      ranked = blendRerank(ranked, fits);
    } catch (e) {
      // Deterministic order is always a valid answer.
      logger.warn("Rerank failed; keeping deterministic order", { userId: profile.userId, error: String(e) });
    }
  }

  return diversify(ranked, opts.size ?? RANKING.forYouSize);
}

export async function computeForYou(
  db: Firestore,
  apiKey: string,
  userId: string,
  opts: ForYouOptions = {},
): Promise<ForYouItem[]> {
  const profile = await buildProfile(db, apiKey, userId, { excludeReviewPath: opts.excludeReviewPath });
  const ranked = await rankForProfile(db, apiKey, profile, opts);
  const items: ForYouItem[] = ranked.map((s) => ({
    trackKey: s.candidate.trackKey,
    reviewPath: s.candidate.reviewPath,
    score: Number(s.score.toFixed(4)),
    reason: s.reason,
    sources: [...s.candidate.sources],
  }));

  if (opts.write) {
    const centroid = tasteCentroid(profile);
    await Promise.all([
      db.doc(`users/${userId}/forYou/current`).set({
        items,
        generatedAt: FieldValue.serverTimestamp(),
        reranked: Boolean(opts.rerank),
        coldStart: profile.coldStart,
      }),
      db
        .collection(COLLECTIONS.userVectors)
        .doc(userId)
        .set(
          {
            centroid: centroid ? FieldValue.vector(centroid) : FieldValue.delete(),
            reviewCount: profile.positiveReviews.length,
            updatedAt: FieldValue.serverTimestamp(),
            ...(opts.rerank ? { lastRerankAt: FieldValue.serverTimestamp() } : {}),
          },
          { merge: true },
        ),
    ]);
  }
  return items;
}
