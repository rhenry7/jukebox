import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { syncReview } from "./analysis";
import { ensureSimilarArtists, syncMbIds } from "./musicbrainz";
import { syncSearchKeys } from "./search";
import { ANALYSIS_VERSION, COLLECTIONS, OPENAI_API_KEY, RERANK_ENABLED } from "./config";
import { computeForYou } from "./forYou";
import { matchForReview } from "./match";
import { computeNeighbors, writeNeighbors } from "./neighbors";
import { reviewDocId } from "./text";

initializeApp();
const db = getFirestore();

/** Signed-in, non-anonymous users only (matches the app's auth gating). */
function requireRealUser(req: CallableRequest): string {
  const auth = req.auth;
  if (!auth || auth.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "Sign in to get recommendations.");
  }
  return auth.uid;
}

/**
 * Every review create/edit/delete: index fields and MusicBrainz IDs first,
 * then analyse once and refresh the author's For You. This is the only
 * place the LLM runs on the write path.
 */
export const onReviewWritten = onDocumentWritten(
  { document: "users/{uid}/reviews/{rid}", secrets: [OPENAI_API_KEY], timeoutSeconds: 120 },
  async (event) => {
    const reviewPath = `users/${event.params.uid}/reviews/${event.params.rid}`;
    // Tag-page index fields. Writing them fires this trigger again, and that
    // run (keys now unchanged) does the analysis — so it happens only once.
    if ((await syncSearchKeys(db, reviewPath)) === "updated") {
      logger.info("Search keys updated", { reviewPath });
      return;
    }
    // MusicBrainz IDs for the song, then its artists' similar artists. Same
    // pattern: writing the IDs re-runs this trigger, which goes on to analyse.
    if ((await syncMbIds(db, reviewPath)) === "updated") {
      const artistMbids = ((await db.doc(reviewPath).get()).get("artistMbids") as string[] | undefined) ?? [];
      const fetched = await ensureSimilarArtists(db, artistMbids);
      logger.info("MusicBrainz IDs updated", { reviewPath, artistMbids, similarFetched: fetched });
      return;
    }
    const outcome = await syncReview(db, OPENAI_API_KEY.value(), reviewPath);
    logger.info("Review synced", { reviewPath, outcome });
    if (outcome === "analyzed" || outcome === "deleted") {
      await db
        .collection(COLLECTIONS.userVectors)
        .doc(event.params.uid)
        .set({ lastActiveAt: FieldValue.serverTimestamp() }, { merge: true });
      await computeForYou(db, OPENAI_API_KEY.value(), event.params.uid, {
        write: true,
        rerank: RERANK_ENABLED.value(),
      });
    }
  },
);

/**
 * Called by the app right after posting a review: returns up to 5 reviews of
 * other tracks the user will probably like, based on what they just wrote.
 */
export const analyzeAndMatch = onCall(
  { secrets: [OPENAI_API_KEY], timeoutSeconds: 30, memory: "512MiB" },
  async (req) => {
    const uid = requireRealUser(req);
    const reviewPath = String(req.data?.reviewPath ?? "");
    if (!reviewPath.startsWith(`users/${uid}/reviews/`) || reviewPath.split("/").length !== 4) {
      throw new HttpsError("permission-denied", "You can only match your own reviews.");
    }

    // The write trigger is normally already analysing this review; wait for it
    // briefly rather than paying for a second analysis.
    const vectorRef = db.collection(COLLECTIONS.reviewVectors).doc(reviewDocId(reviewPath));
    const deadline = Date.now() + 6_000;
    let ready = false;
    while (Date.now() < deadline) {
      const snap = await vectorRef.get();
      if (snap.exists && snap.get("analysisVersion") === ANALYSIS_VERSION) {
        ready = true;
        break;
      }
      await new Promise((r) => setTimeout(r, 400));
    }
    if (!ready) await syncReview(db, OPENAI_API_KEY.value(), reviewPath);

    return { matches: await matchForReview(db, uid, reviewPath) };
  },
);

/** Pull-to-refresh on For You. Deterministic (no LLM); throttled to once a minute. */
export const refreshForYou = onCall({ secrets: [OPENAI_API_KEY], timeoutSeconds: 60 }, async (req) => {
  const uid = requireRealUser(req);
  const current = await db.doc(`users/${uid}/forYou/current`).get();
  const generatedAt = current.get("generatedAt") as Timestamp | undefined;
  if (generatedAt && Date.now() - generatedAt.toMillis() < 60_000) {
    return { refreshed: false };
  }
  // Keep a previous LLM rerank unless it's stale — refresh only re-retrieves.
  const items = await computeForYou(db, OPENAI_API_KEY.value(), uid, { write: true, rerank: false });
  return { refreshed: true, count: items.length };
});

/**
 * Nightly: rebuild the lookalike-listener graph, then refresh For You for
 * active users so new community reviews show up. LLM rerank at most weekly.
 */
export const nightlyRefresh = onSchedule(
  { schedule: "every day 04:00", timeZone: "America/New_York", secrets: [OPENAI_API_KEY], timeoutSeconds: 540 },
  async () => {
    await writeNeighbors(db, await computeNeighbors(db));

    const activeSince = Timestamp.fromMillis(Date.now() - 30 * 86_400_000);
    const weekAgo = Date.now() - 7 * 86_400_000;
    const active = await db.collection(COLLECTIONS.userVectors).where("lastActiveAt", ">=", activeSince).get();
    for (const doc of active.docs) {
      const lastRerank = (doc.get("lastRerankAt") as Timestamp | undefined)?.toMillis() ?? 0;
      try {
        await computeForYou(db, OPENAI_API_KEY.value(), doc.id, {
          write: true,
          rerank: RERANK_ENABLED.value() && lastRerank < weekAgo,
        });
      } catch (e) {
        logger.error("Nightly For You refresh failed", { uid: doc.id, error: String(e) });
      }
    }
  },
);
