/**
 * The active user's taste, rebuilt from their analysed reviews and their
 * actions on other people's reviews (likes, bookmarks, reposts, comments,
 * "Not for me"; see implicit.ts). Math only — the one exception is a
 * cold-start embedding of their preferences.
 */
import { Firestore } from "firebase-admin/firestore";
import { RANKING } from "./config";
import { loadImplicitSignals } from "./implicit";
import { embed } from "./openai";
import { ProfileBasis, UserAspect } from "./scoring";
import { aspectsByReview, loadPreferences, ReviewVector, reviewVectorsByPath, reviewVectorsByUser } from "./store";
import { parseSavedTrack, trackKey } from "./text";
import { kmeans, recencyWeight, Vec, weightedCentroid } from "./vectors";

export interface Profile {
  userId: string;
  /** Positive reviews, newest first — the "style" queries. */
  positiveReviews: ReviewVector[];
  /** Every aspect from the user's reviews (praise and complaints). */
  aspects: UserAspect[];
  /** 1–5 interest centroids over the user's praised aspects, heaviest first. */
  interests: { centroid: Vec; weight: number }[];
  /** Centroid of what the user complains about. */
  negCentroid: Vec | null;
  /** Tags from positive reviews (for tag overlap). */
  tags: string[];
  /** Tracks the user has reviewed, saved, engaged with or dismissed — never recommended back. */
  knownTrackKeys: Set<string>;
  /** Other people's reviews the user liked / bookmarked / reposted / commented on, with 0–1 weight. */
  liked: { review: ReviewVector; weight: number }[];
  /** Reviews the user marked "Not for me" on For You. */
  disliked: ReviewVector[];
  /** Release years of the music the user loves (own liked reviews + engaged-with), weighted. */
  lovedYears: { year: number; weight: number }[];
  coldStart: boolean;
  /** What the profile is built from (for honest explanations). */
  basis: ProfileBasis;
}

/** How much a "Not for me" review's praise counts toward what the user dislikes. */
const DISLIKE_ASPECT_WEIGHT = 0.5;

export async function buildProfile(
  db: Firestore,
  apiKey: string,
  userId: string,
  opts: { excludeReviewPath?: string } = {},
): Promise<Profile> {
  const now = new Date();
  const [allReviews, prefs, reviewedTracks, implicit] = await Promise.all([
    reviewVectorsByUser(db, userId),
    loadPreferences(db, userId),
    // Every track they've reviewed — including star-only reviews and
    // reposts, which have no vector.
    db.collection(`users/${userId}/reviews`).select("artist", "title").get(),
    loadImplicitSignals(db, userId),
  ]);
  const reviews = allReviews.filter((r) => r.reviewPath !== opts.excludeReviewPath);
  const otherVectors = await reviewVectorsByPath(db, [...implicit.liked.keys(), ...implicit.disliked]);
  const liked = otherVectors
    .filter((r) => implicit.liked.has(r.reviewPath))
    .map((review) => ({ review, weight: implicit.liked.get(review.reviewPath)! }));
  const disliked = otherVectors.filter((r) => implicit.disliked.has(r.reviewPath));
  const aspectMap = await aspectsByReview(db, [
    ...reviews.map((r) => r.reviewPath),
    ...otherVectors.map((r) => r.reviewPath),
  ]);

  const aspects: UserAspect[] = [];
  const posVecs: Vec[] = [];
  const posWeights: number[] = [];
  const negVecs: Vec[] = [];
  const negWeights: number[] = [];
  for (const r of reviews) {
    const recency = recencyWeight(r.date, RANKING.recencyHalfLifeDays, now);
    for (const a of aspectMap.get(r.reviewPath) ?? []) {
      aspects.push({ ...a, reviewTitle: r.title });
      if (a.polarity > 0) {
        posVecs.push(a.embedding);
        posWeights.push(a.polarity * Math.max(r.affinity, 0.1) * recency);
      } else if (a.polarity < 0) {
        negVecs.push(a.embedding);
        negWeights.push(-a.polarity * recency);
      }
    }
  }

  // Praise in reviews they engaged with: a weaker version of their own.
  for (const { review, weight } of liked) {
    const recency = recencyWeight(review.date, RANKING.recencyHalfLifeDays, now);
    for (const a of aspectMap.get(review.reviewPath) ?? []) {
      if (a.polarity <= 0) continue;
      posVecs.push(a.embedding);
      posWeights.push(a.polarity * weight * recency);
    }
  }
  // What a "Not for me" review praises is something they don't want.
  for (const review of disliked) {
    for (const a of aspectMap.get(review.reviewPath) ?? []) {
      if (a.polarity <= 0) continue;
      negVecs.push(a.embedding);
      negWeights.push(a.polarity * DISLIKE_ASPECT_WEIGHT);
    }
  }

  const positiveReviews = reviews
    .filter((r) => r.affinity > 0)
    .sort((a, b) => (b.date?.getTime() ?? 0) - (a.date?.getTime() ?? 0));

  const k = Math.min(RANKING.maxInterests, Math.max(1, Math.ceil(posVecs.length / 4)));
  let interests = kmeans(posVecs, posWeights, k).map((c) => ({ centroid: c.centroid, weight: c.weight }));

  // Cold start: no praised aspects yet → use what they told us in onboarding.
  let coldStart = false;
  if (interests.length === 0 && prefs) {
    const text = [
      prefs.favoriteGenres.length ? `I love ${prefs.favoriteGenres.join(", ")} music.` : "",
      prefs.favoriteArtists.length ? `Favourite artists: ${prefs.favoriteArtists.slice(0, 15).join(", ")}.` : "",
      prefs.favoriteAlbums.length ? `Favourite albums: ${prefs.favoriteAlbums.slice(0, 10).join(", ")}.` : "",
    ]
      .filter(Boolean)
      .join(" ");
    if (text) {
      const [vec] = await embed(apiKey, [text]);
      interests = [{ centroid: vec, weight: 1 }];
      coldStart = true;
    }
  }

  const knownTrackKeys = new Set(reviews.map((r) => r.trackKey));
  for (const doc of reviewedTracks.docs) {
    if (doc.ref.path === opts.excludeReviewPath) continue;
    knownTrackKeys.add(trackKey(doc.get("artist") ?? "", doc.get("title") ?? ""));
  }
  for (const saved of prefs?.savedTracks ?? []) {
    const key = parseSavedTrack(saved);
    if (key) knownTrackKeys.add(key);
  }
  // Seen (engaged with or dismissed): don't recommend those songs again.
  for (const r of otherVectors) knownTrackKeys.add(r.trackKey);

  return {
    userId,
    positiveReviews,
    aspects,
    interests,
    negCentroid: weightedCentroid(negVecs, negWeights),
    tags: [
      ...new Set(
        [...positiveReviews, ...liked.map((l) => l.review)].flatMap((r) =>
          [...r.tags, ...r.mbTags].map((t) => t.toLowerCase()),
        ),
      ),
    ],
    knownTrackKeys,
    liked,
    disliked,
    lovedYears: [
      ...positiveReviews.map((r) => ({ year: r.releaseYear, weight: r.affinity })),
      ...liked.map((l) => ({ year: l.review.releaseYear, weight: l.weight })),
    ].filter((y): y is { year: number; weight: number } => y.year !== null && y.weight > 0),
    coldStart,
    basis:
      reviews.length > 0 ? "reviews" : liked.length > 0 ? "activity" : coldStart ? "onboarding" : "none",
  };
}

/** One vector summarising the user's taste — used to find lookalike users. */
export function tasteCentroid(profile: Profile): Vec | null {
  return weightedCentroid(
    profile.interests.map((i) => i.centroid),
    profile.interests.map((i) => i.weight),
  );
}
