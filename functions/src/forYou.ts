/**
 * For You (plan phases 4–6): retrieve ~300 candidates from five sources over
 * the whole corpus, score them deterministically, optionally rerank the top
 * 30 with the LLM, diversify, and cache the result for the app to read.
 */
import { FieldValue, Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { COLLECTIONS, RANKING } from "./config";
import { eraFit } from "./era";
import { SimilarArtist, similarArtistsFor, similarRecordingsFor } from "./musicbrainz";
import { buildProfile, Profile, tasteCentroid } from "./profile";
import { rerank } from "./rerank";
import { TagIdf } from "./relevance";
import { loadTagIdf } from "./tagStats";
import {
  bestPerTrack,
  blendRerank,
  Candidate,
  diversify,
  rescaleSim,
  MatchVia,
  reasonFor,
  ScoredCandidate,
  scoreCandidate,
  Source,
  Weights,
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

/** A similar artist's strength for this user, and which loved artist it came from. */
export interface ArtistMatch {
  strength: number;
  lovedArtist: string;
  via: MatchVia;
}

/** A review that tells us what the user likes, and how much (0–1). */
interface Loved {
  review: ReviewVector;
  affinity: number;
  via: MatchVia;
}

/**
 * The reviews that say what the user loves: their own with affinity ≥
 * `artistMinAffinity`, plus reviews they liked / bookmarked / reposted /
 * commented on, at that action's weight.
 */
export function lovedReviews(profile: Pick<Profile, "positiveReviews" | "liked">): Loved[] {
  return [
    ...profile.positiveReviews
      .filter((r) => r.affinity >= RANKING.artistMinAffinity)
      .map((review) => ({ review, affinity: review.affinity, via: "review" as const })),
    ...profile.liked.map((l) => ({ review: l.review, affinity: l.weight, via: "liked" as const })),
  ];
}

/**
 * Each review's artist MBIDs: from its analysis record when copied there
 * (syncMbIds), otherwise read from the review.
 */
async function artistMbidsOf(db: Firestore, reviews: ReviewVector[]): Promise<Map<string, string[]>> {
  const out = new Map<string, string[]>();
  const missing = reviews.filter((r) => {
    if (r.artistMbids.length) out.set(r.reviewPath, r.artistMbids);
    return !r.artistMbids.length;
  });
  if (missing.length) {
    const docs = await db.getAll(...missing.map((r) => db.doc(r.reviewPath)), { fieldMask: ["artistMbids"] });
    docs.forEach((d) => out.set(d.ref.path, (d.get("artistMbids") as string[] | undefined) ?? []));
  }
  return out;
}

/** Onboarding favourite artists resolved to MBIDs (see `syncFavoriteArtists`). */
async function favoriteArtists(db: Firestore, userId: string): Promise<{ mbid: string; name: string }[]> {
  const snap = await db.collection(COLLECTIONS.userVectors).doc(userId).get();
  return (snap.get("favoriteArtists") as { mbid: string; name: string }[] | undefined) ?? [];
}

/** How much an onboarding favourite artist counts, like a ~4★ review. */
export const FAVORITE_ARTIST_AFFINITY = 0.7;

/**
 * Artists that sound like ones the user loves: their loved reviews' artists
 * (see [lovedReviews]) and onboarding favourites, each artist's ListenBrainz
 * similar artists (cached in `similarArtists`), weighted by affinity ×
 * similarity. The user's own artists are left out (other channels cover
 * them); the point is discovery.
 */
export async function similarArtistSignal(
  db: Firestore,
  profile: Pick<Profile, "positiveReviews" | "liked" | "userId">,
): Promise<Map<string, ArtistMatch>> {
  const loved = lovedReviews(profile);
  const [mbids, favorites] = await Promise.all([
    artistMbidsOf(
      db,
      loved.map((l) => l.review),
    ),
    favoriteArtists(db, profile.userId),
  ]);
  // Each loved artist's best affinity, and a display name for the reason line.
  const own = new Map<string, OwnArtist>();
  const consider = (id: string, affinity: number, name: string, via: MatchVia) => {
    const prev = own.get(id);
    if (!prev || affinity > prev.affinity) own.set(id, { affinity, name, via });
  };
  for (const { review, affinity, via } of loved) {
    for (const id of mbids.get(review.reviewPath) ?? []) {
      consider(id, affinity, review.artist.split(",")[0].trim(), via);
    }
  }
  for (const f of favorites) consider(f.mbid, FAVORITE_ARTIST_AFFINITY, f.name, "favorite");
  if (own.size === 0) return new Map();
  return combineSimilarArtists(own, await similarArtistsFor(db, [...own.keys()]));
}

/** A similar song's strength for this user, and which loved song it came from. */
export interface SongMatch {
  strength: number;
  lovedTitle: string;
  via: MatchVia;
}

/**
 * Songs that sound like ones the user loves (ListenBrainz similar
 * recordings, cached in `similarRecordings`): recording MBID → strength.
 */
export async function similarSongSignal(
  db: Firestore,
  profile: Pick<Profile, "positiveReviews" | "liked">,
): Promise<Map<string, SongMatch>> {
  const loved = lovedReviews(profile).filter((l) => l.review.recordingMbid);
  if (loved.length === 0) return new Map();
  const similar = await similarRecordingsFor(db, [...new Set(loved.map((l) => l.review.recordingMbid!))]);
  const own = new Set(loved.map((l) => l.review.recordingMbid!));
  const out = new Map<string, SongMatch>();
  for (const { review, affinity, via } of loved) {
    similar.get(review.recordingMbid!)?.forEach((score, id) => {
      if (own.has(id)) return;
      const strength = affinity * score;
      if (strength > (out.get(id)?.strength ?? 0)) out.set(id, { strength, lovedTitle: review.title, via });
    });
  }
  return out;
}

/**
 * Artists the user marked "Not for me" (1) and ones that sound like them
 * (half their similarity): artist MBID → 0–1 penalty.
 */
export async function dislikeSignal(db: Firestore, profile: Pick<Profile, "disliked">): Promise<Map<string, number>> {
  if (profile.disliked.length === 0) return new Map();
  const mbids = await artistMbidsOf(db, profile.disliked);
  const ids = [...new Set([...mbids.values()].flat())];
  const out = new Map<string, number>(ids.map((id) => [id, 1]));
  (await similarArtistsFor(db, ids)).forEach((list) => {
    for (const s of list) out.set(s.mbid, Math.max(out.get(s.mbid) ?? 0, 0.5 * s.score));
  });
  return out;
}

/** One of the user's loved artists. */
export interface OwnArtist {
  affinity: number;
  name: string;
  via?: MatchVia;
}

/** Pure part of [similarArtistSignal] (unit-tested). */
export function combineSimilarArtists(
  own: Map<string, OwnArtist>,
  similarByArtist: Map<string, SimilarArtist[]>,
): Map<string, ArtistMatch> {
  const out = new Map<string, ArtistMatch>();
  for (const [ownId, { affinity, name, via }] of own) {
    for (const s of similarByArtist.get(ownId) ?? []) {
      if (own.has(s.mbid)) continue;
      const strength = affinity * s.score;
      if (strength > (out.get(s.mbid)?.strength ?? 0)) {
        out.set(s.mbid, { strength, lovedArtist: name, via: via ?? "review" });
      }
    }
  }
  return out;
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

  const quiet = <T>(what: string, fallback: T) => (e: unknown) => {
    logger.warn(`${what} signal failed`, { userId: profile.userId, error: String(e) });
    return fallback;
  };
  const [aspectHits, styleHits, cfByTrack, artistSignal, songSignal, dislikes] = await Promise.all([
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
    similarArtistSignal(db, profile).catch(quiet("Similar-artist", new Map<string, ArtistMatch>())),
    similarSongSignal(db, profile).catch(quiet("Similar-song", new Map<string, SongMatch>())),
    dislikeSignal(db, profile).catch(quiet("Dislike", new Map<string, number>())),
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

  // Similar artists: reviews by the artists that sound most like the user's
  // loved ones. Each review keeps its best match for scoring and the reason.
  const artistByPath = new Map<string, ArtistMatch>();
  const topArtists = [...artistSignal.entries()]
    .sort((a, b) => b[1].strength - a[1].strength)
    .slice(0, RANKING.similarArtistQuery);
  if (topArtists.length > 0) {
    const snap = await db
      .collectionGroup("reviews")
      .where(
        "artistMbids",
        "array-contains-any",
        topArtists.map(([id]) => id),
      )
      .orderBy("date", "desc")
      .limit(RANKING.artistHits)
      .select("artistMbids")
      .get();
    for (const d of snap.docs) {
      let best: ArtistMatch | undefined;
      for (const id of (d.get("artistMbids") as string[] | undefined) ?? []) {
        const m = artistSignal.get(id);
        if (m && m.strength > (best?.strength ?? 0)) best = m;
      }
      if (!best) continue;
      artistByPath.set(d.ref.path, best);
      tag(d.ref.path, "artist");
    }
  }

  // Similar songs: reviews of songs that sound like the user's loved ones.
  const songByPath = new Map<string, SongMatch>();
  const topSongs = [...songSignal.entries()]
    .sort((a, b) => b[1].strength - a[1].strength)
    .slice(0, RANKING.similarSongQuery);
  for (let i = 0; i < topSongs.length; i += 30) {
    const snap = await db
      .collection(COLLECTIONS.reviewVectors)
      .where(
        "recordingMbid",
        "in",
        topSongs.slice(i, i + 30).map(([id]) => id),
      )
      .select("reviewPath", "recordingMbid")
      .get();
    for (const d of snap.docs) {
      const m = songSignal.get(d.get("recordingMbid"));
      if (!m) continue;
      songByPath.set(d.get("reviewPath"), m);
      tag(d.get("reviewPath"), "song");
    }
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
      // Author tags plus filled-in MusicBrainz genres.
      tags: [...r.tags, ...r.mbTags],
      stars: r.stars,
      affinity: r.affinity,
      date: r.date,
      likes: r.likes,
    textLength: r.textLength,
      aspects: aspectMap.get(r.reviewPath) ?? [],
      styleSim,
      styleMatchTitle,
      cf: cfByTrack.get(r.trackKey) ?? 0,
      artistSim: artistByPath.get(r.reviewPath)?.strength ?? 0,
      artistMatch: artistByPath.get(r.reviewPath)?.lovedArtist,
      artistVia: artistByPath.get(r.reviewPath)?.via,
      songSim: songByPath.get(r.reviewPath)?.strength ?? 0,
      songMatch: songByPath.get(r.reviewPath)?.lovedTitle,
      songVia: songByPath.get(r.reviewPath)?.via,
      dislike: Math.max(0, ...r.artistMbids.map((id) => dislikes.get(id) ?? 0)),
      eraFit: eraFit(r.releaseYear, profile.lovedYears),
      sources: sources.get(r.reviewPath)!,
    };
  });
}

/** Scores retrieved candidates and keeps the best review per track (no I/O). */
export function scoreAndGroup(
  candidates: Candidate[],
  profile: Pick<Profile, "aspects" | "tags" | "knownTrackKeys"> & Partial<Pick<Profile, "basis">>,
  idf: TagIdf,
  weights: Weights = RANKING.weights,
): ScoredCandidate[] {
  const now = new Date();
  const basis = profile.basis ?? "reviews";
  const scored = candidates.map((c) => {
    const s = scoreCandidate(c, profile.aspects, profile.tags, now, idf, weights);
    return basis === "reviews" ? s : { ...s, reason: reasonFor(c, s.bestPair, s.aspectFit, basis) };
  });
  return bestPerTrack(scored, profile.knownTrackKeys);
}

export async function rankForProfile(
  db: Firestore,
  apiKey: string,
  profile: Profile,
  opts: ForYouOptions,
): Promise<ScoredCandidate[]> {
  const [candidates, idf] = await Promise.all([retrieveCandidates(db, profile, opts), loadTagIdf(db)]);
  let ranked = scoreAndGroup(candidates, profile, idf);

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
