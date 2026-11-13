/**
 * What a user's actions on other people's reviews say about their taste,
 * besides their own reviews: likes, comments, reposts and bookmarks count
 * as weaker "I liked this" signals, and "Not for me" on a For You card as a
 * dislike.
 *
 * Read from `users/{uid}/activity` (likes, comments, reposts, written by
 * ActivityService in the app), `users/{uid}/bookmarks` and
 * `users/{uid}/forYouFeedback`.
 */
import { Firestore } from "firebase-admin/firestore";

/** How much each action counts, relative to the user's own 5★ review (1). */
export const IMPLICIT_WEIGHTS = {
  bookmark: 0.6,
  repost: 0.6,
  like: 0.4,
  comment: 0.3,
} as const;

export type ImplicitAction = keyof typeof IMPLICIT_WEIGHTS;

export interface ImplicitSignals {
  /** Review path → 0–1 interest (strongest action wins). Own reviews excluded. */
  liked: Map<string, number>;
  /** Review path → the action behind that interest, for reason lines. */
  actions: Map<string, ImplicitAction>;
  /** Review paths marked "Not for me". */
  disliked: Set<string>;
}

/** Combines the raw rows (pure; unit-tested). */
export function combineImplicit(
  userId: string,
  activity: { type?: string; reviewId?: string }[],
  bookmarks: { reviewPath?: string }[],
  feedback: { reviewPath?: string; reason?: string }[],
): ImplicitSignals {
  const own = (path: string) => path.startsWith(`users/${userId}/`);
  const liked = new Map<string, number>();
  const actions = new Map<string, ImplicitAction>();
  const add = (path: string | undefined, action: ImplicitAction) => {
    if (!path || own(path) || !path.startsWith("users/")) return;
    const w = IMPLICIT_WEIGHTS[action];
    if (w > (liked.get(path) ?? 0)) {
      liked.set(path, w);
      actions.set(path, action);
    }
  };
  for (const a of activity) {
    if (a.type && a.type in IMPLICIT_WEIGHTS) add(a.reviewId, a.type as ImplicitAction);
  }
  for (const b of bookmarks) add(b.reviewPath, "bookmark");
  const disliked = new Set<string>();
  for (const f of feedback) {
    if (f.reviewPath && f.reason === "not_for_me") disliked.add(f.reviewPath);
  }
  // A dislike overrides an earlier like of the same review.
  disliked.forEach((p) => {
    liked.delete(p);
    actions.delete(p);
  });
  return { liked, actions, disliked };
}

export async function loadImplicitSignals(db: Firestore, userId: string): Promise<ImplicitSignals> {
  const [activity, bookmarks, feedback] = await Promise.all([
    db.collection(`users/${userId}/activity`).select("type", "reviewId").limit(500).get(),
    db.collection(`users/${userId}/bookmarks`).select("reviewPath").limit(500).get(),
    db.collection(`users/${userId}/forYouFeedback`).select("reviewPath", "reason").limit(500).get(),
  ]);
  return combineImplicit(
    userId,
    activity.docs.map((d) => d.data()),
    bookmarks.docs.map((d) => d.data()),
    feedback.docs.map((d) => d.data()),
  );
}
