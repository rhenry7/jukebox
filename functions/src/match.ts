/**
 * Post-review "you'll like these" (plan phase 3): item-to-item retrieval from
 * the review the user just wrote. No profile and no LLM — just the review's
 * own aspects and style vector against the whole corpus.
 */
import { Firestore } from "firebase-admin/firestore";
import { RANKING } from "./config";
import { bestPerTrack, Candidate, diversify, rescaleSim, scoreCandidate, Source, UserAspect } from "./scoring";
import {
  aspectsByReview,
  nearestAspects,
  nearestReviews,
  ReviewVector,
  reviewVectorsByPath,
  reviewVectorsByUser,
} from "./store";
import { cosine } from "./vectors";

export interface Match {
  reviewPath: string;
  trackKey: string;
  title: string;
  artist: string;
  reason: string;
}

export async function matchForReview(db: Firestore, userId: string, reviewPath: string): Promise<Match[]> {
  const [source] = await reviewVectorsByPath(db, [reviewPath]);
  if (!source) return [];
  const ownAspects = (await aspectsByReview(db, [reviewPath])).get(reviewPath) ?? [];
  const userAspects: UserAspect[] = ownAspects.map((a) => ({ ...a, reviewTitle: source.title }));
  const liked = source.affinity > 0;

  const praised = ownAspects.filter((a) => a.polarity > 0);
  const [aspectHits, styleHits, ownReviews] = await Promise.all([
    Promise.all(praised.map((a) => nearestAspects(db, a.embedding, "pos", 30))).then((l) => l.flat()),
    // Sounding like a review of a track they disliked is not a recommendation.
    liked ? nearestReviews(db, source.embedding, 30) : Promise.resolve([] as ReviewVector[]),
    reviewVectorsByUser(db, userId),
  ]);

  const known = new Set(ownReviews.map((r) => r.trackKey));
  const sources = new Map<string, Set<Source>>();
  const tag = (path: string, s: Source) => sources.set(path, (sources.get(path) ?? new Set<Source>()).add(s));
  aspectHits.forEach((h) => tag(h.reviewPath, "aspect"));
  styleHits.forEach((r) => tag(r.reviewPath, "style"));

  const byPath = new Map(styleHits.map((r) => [r.reviewPath, r]));
  const missing = [...sources.keys()].filter((p) => !byPath.has(p));
  (await reviewVectorsByPath(db, missing)).forEach((r) => byPath.set(r.reviewPath, r));
  const reviews = [...byPath.values()].filter((r) => r.userId !== userId && !known.has(r.trackKey));
  const aspectMap = await aspectsByReview(
    db,
    reviews.map((r) => r.reviewPath),
  );

  const candidates: Candidate[] = reviews.map((r) => ({
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
    styleSim: liked ? rescaleSim(cosine(source.embedding, r.embedding)) : 0,
    styleMatchTitle: source.title,
    cf: 0,
    sources: sources.get(r.reviewPath)!,
  }));

  const userTags = liked ? source.tags.map((t) => t.toLowerCase()) : [];
  const ranked = bestPerTrack(
    candidates.map((c) => scoreCandidate(c, userAspects, userTags)),
    known,
  ).filter((s) => s.score > 0);

  return diversify(ranked, RANKING.postReviewMatches).map((s) => ({
    reviewPath: s.candidate.reviewPath,
    trackKey: s.candidate.trackKey,
    title: s.candidate.title,
    artist: s.candidate.artist,
    reason: s.reason,
  }));
}
