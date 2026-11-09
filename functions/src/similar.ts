/**
 * "More like this" for the review page, computed on the server and cached
 * per review in `similarReviews/{reviewDocId}` (public read) so the app reads
 * one document.
 *
 * Every other review is scored against the anchor on four signals, each 0–1:
 *   artist  same artist, or how similar-sounding (ListenBrainz `similarArtists`)
 *   song    how similar the songs are (ListenBrainz `similarRecordings`)
 *   tags    shared tags, weighted by rarity (author tags + filled-in `mbTags`)
 *   text    how alike the two reviews read (their embeddings)
 * plus a little for review quality and length. One review per song, at most
 * `MAX_PER_AUTHOR` per author, top `KEEP`. Each item keeps its strongest
 * signal as the reason the app shows ("Similar artist", "Reads alike"…).
 *
 * The whole corpus is scored in memory: a few hundred reviews take well
 * under a second. Revisit (vector search per signal) past ~10k reviews.
 */
import { FieldValue, Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { COLLECTIONS } from "./config";
import { similarRecordingsFor } from "./musicbrainz";
import { artistSimilarity, idfOverlap, ItemInfo, sameArtist, SimilarArtistIndex, TagIdf } from "./relevance";
import { depth, quality, rescaleSim } from "./scoring";
import { toVec } from "./store";
import { loadTagIdf } from "./tagStats";
import { mergedTags, reviewDocId, trackKey } from "./text";
import { cosine, Vec } from "./vectors";

export const SIMILAR_COLLECTION = "similarReviews";
/** How many similar reviews are stored per review (the app shows 5). */
export const KEEP = 10;
/** At most this many from one author, so one prolific account can't fill the row. */
export const MAX_PER_AUTHOR = 2;

export const WEIGHTS = {
  artist: 0.3,
  song: 0.25,
  tags: 0.25,
  text: 0.3,
  quality: 0.05,
  depth: 0.05,
};

export type SimilarReason = "artist" | "song" | "tags" | "text";

export interface SimilarItem {
  reviewPath: string;
  score: number;
  reason: SimilarReason;
}

export interface CorpusItem extends ItemInfo {
  reviewPath: string;
  userId: string;
  recordingMbid: string | null;
  embedding: Vec | null;
  stars: number;
  likes: number;
  textLength: number;
}

export interface SimilarCorpus {
  items: Map<string, CorpusItem>;
  similarArtists: SimilarArtistIndex;
  /** Recording MBID → (similar recording MBID → 0–1). */
  similarRecordings: Map<string, Map<string, number>>;
  idf: TagIdf;
}

/** The four signals for [c] against [anchor], each 0–1. */
export function signals(anchor: CorpusItem, c: CorpusItem, corpus: SimilarCorpus): Record<SimilarReason, number> {
  const song =
    anchor.recordingMbid && c.recordingMbid
      ? Math.max(
          corpus.similarRecordings.get(anchor.recordingMbid)?.get(c.recordingMbid) ?? 0,
          corpus.similarRecordings.get(c.recordingMbid)?.get(anchor.recordingMbid) ?? 0,
        )
      : 0;
  return {
    artist: sameArtist(anchor, c) ? 0.9 : artistSimilarity(anchor, c, corpus.similarArtists),
    song,
    tags: idfOverlap(anchor.tags, c.tags, corpus.idf),
    text: anchor.embedding && c.embedding ? rescaleSim(cosine(anchor.embedding, c.embedding)) : 0,
  };
}

/** Ranked similar reviews for [anchorPath] (by other people), best first. */
export function rankSimilar(
  anchorPath: string,
  corpus: SimilarCorpus,
  opts: { keep?: number; weights?: typeof WEIGHTS } = {},
): SimilarItem[] {
  const anchor = corpus.items.get(anchorPath);
  if (!anchor) return [];
  const w = opts.weights ?? WEIGHTS;
  const scored: SimilarItem[] = [];
  for (const c of corpus.items.values()) {
    if (c.reviewPath === anchorPath || c.trackKey === anchor.trackKey) continue;
    const s = signals(anchor, c, corpus);
    const weighted: Record<SimilarReason, number> = {
      artist: w.artist * s.artist,
      song: w.song * s.song,
      tags: w.tags * s.tags,
      text: w.text * s.text,
    };
    const relevance = weighted.artist + weighted.song + weighted.tags + weighted.text;
    if (relevance <= 0) continue;
    const reason = (Object.keys(weighted) as SimilarReason[]).reduce((a, b) => (weighted[b] > weighted[a] ? b : a));
    const score = relevance + w.quality * quality(c.stars, c.likes) + w.depth * depth(c.textLength);
    scored.push({ reviewPath: c.reviewPath, score: Number(score.toFixed(4)), reason });
  }
  scored.sort((a, b) => b.score - a.score);

  const out: SimilarItem[] = [];
  const tracks = new Set<string>();
  const perAuthor = new Map<string, number>();
  for (const s of scored) {
    const c = corpus.items.get(s.reviewPath)!;
    if (tracks.has(c.trackKey) || (perAuthor.get(c.userId) ?? 0) >= MAX_PER_AUTHOR) continue;
    tracks.add(c.trackKey);
    perAuthor.set(c.userId, (perAuthor.get(c.userId) ?? 0) + 1);
    out.push(s);
    if (out.length === (opts.keep ?? KEEP)) break;
  }
  return out;
}

/** Reads everything [rankSimilar] needs: reviews, embeddings, similarity caches, tag rarity. */
export async function loadSimilarCorpus(db: Firestore): Promise<SimilarCorpus> {
  const [reviews, vectors, artists, idf] = await Promise.all([
    db
      .collectionGroup("reviews")
      .select(
        "userId", "artist", "title", "genres", "tags", "mbTags", "artistMbids", "recordingMbid",
        "score", "likes", "review", "isRepost",
      )
      .get(),
    db.collection(COLLECTIONS.reviewVectors).select("reviewPath", "embedding").get(),
    db.collection("similarArtists").get(),
    loadTagIdf(db),
  ]);
  const embeddings = new Map<string, Vec>();
  vectors.docs.forEach((d) => embeddings.set(d.get("reviewPath"), toVec(d.get("embedding"))));

  const items = new Map<string, CorpusItem>();
  for (const d of reviews.docs) {
    const path = d.ref.path;
    if (!path.startsWith("users/") || path.split("/").length !== 4 || d.get("isRepost")) continue;
    const data = d.data();
    items.set(path, {
      reviewPath: path,
      userId: data.userId || path.split("/")[1],
      trackKey: trackKey(data.artist ?? "", data.title ?? ""),
      artist: data.artist ?? "",
      artistMbids: data.artistMbids ?? [],
      recordingMbid: data.recordingMbid ?? null,
      tags: [...mergedTags(data), ...((data.mbTags as string[] | undefined) ?? [])],
      embedding: embeddings.get(path) ?? null,
      stars: typeof data.score === "number" ? data.score : 0,
      likes: data.likes ?? 0,
      textLength: String(data.review ?? "").trim().length,
    });
  }

  const similarArtists: SimilarArtistIndex = new Map();
  artists.docs.forEach((d) => {
    const list = (d.get("similar") as { mbid: string; score: number }[] | undefined) ?? [];
    similarArtists.set(d.id, new Map(list.map((s) => [s.mbid, s.score])));
  });
  const recordingIds = [...new Set([...items.values()].map((i) => i.recordingMbid).filter((x): x is string => !!x))];
  const similarRecordings = await similarRecordingsFor(db, recordingIds);
  return { items, similarArtists, similarRecordings, idf };
}

/**
 * Writes `similarReviews/{id}` for [paths] (default: every review). Returns
 * how many were written.
 */
export async function writeSimilar(
  db: Firestore,
  corpus: SimilarCorpus,
  paths: string[] = [...corpus.items.keys()],
  opts: { dryRun?: boolean } = {},
): Promise<number> {
  const writer = db.bulkWriter();
  let n = 0;
  for (const path of paths) {
    if (!corpus.items.has(path)) continue;
    const items = rankSimilar(path, corpus);
    n++;
    if (opts.dryRun) continue;
    writer.set(db.collection(SIMILAR_COLLECTION).doc(reviewDocId(path)), {
      reviewPath: path,
      items,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await writer.close();
  return n;
}

/** Recomputes one review's list (after it's written). Removes it if the review is gone. */
export async function refreshSimilarFor(db: Firestore, reviewPath: string): Promise<void> {
  const ref = db.collection(SIMILAR_COLLECTION).doc(reviewDocId(reviewPath));
  const corpus = await loadSimilarCorpus(db);
  if (!corpus.items.has(reviewPath)) {
    await ref.delete();
    return;
  }
  await writeSimilar(db, corpus, [reviewPath]);
  logger.info("Similar reviews refreshed", { reviewPath });
}
