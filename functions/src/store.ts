/** Firestore reads for retrieval. Vector search runs over the whole corpus. */
import { DocumentSnapshot, FieldValue, Firestore } from "firebase-admin/firestore";
import { COLLECTIONS } from "./config";
import { Aspect } from "./scoring";
import { Vec } from "./vectors";

export interface ReviewVector {
  reviewPath: string;
  userId: string;
  trackKey: string;
  artist: string;
  title: string;
  tags: string[];
  /** The song's artists' MusicBrainz IDs (empty if unknown). */
  artistMbids: string[];
  /** The song's MusicBrainz ID, if matched. */
  recordingMbid: string | null;
  /** Genres filled in from MusicBrainz / ListenBrainz (never the author's tags). */
  mbTags: string[];
  stars: number;
  likes: number;
  /** Characters in the review text; null for docs analysed before this was stored. */
  textLength: number | null;
  polarity: number;
  affinity: number;
  date: Date | null;
  embedding: Vec;
}

/**
 * A nearest-aspect search hit. No embedding: retrieval only needs which
 * review it came from, and leaving the vectors out makes the search about
 * 13× faster and ~100× smaller.
 */
export interface AspectHit extends Omit<Aspect, "embedding"> {
  reviewPath: string;
  userId: string;
  trackKey: string;
  /** Cosine similarity to the query (Firestore returns cosine *distance*). */
  similarity: number;
}

/** Firestore returns vector fields as VectorValue (not re-exported by firebase-admin). */
export function toVec(v: unknown): Vec {
  if (v && typeof (v as { toArray?: unknown }).toArray === "function") return (v as { toArray(): Vec }).toArray();
  return Array.isArray(v) ? v : [];
}

export function toReviewVector(snap: DocumentSnapshot): ReviewVector {
  const d = snap.data()!;
  return {
    reviewPath: d.reviewPath,
    userId: d.userId,
    trackKey: d.trackKey,
    artist: d.artist ?? "",
    title: d.title ?? "",
    tags: d.tags ?? [],
    artistMbids: d.artistMbids ?? [],
    recordingMbid: d.recordingMbid ?? null,
    mbTags: d.mbTags ?? [],
    stars: d.stars ?? 0,
    likes: d.likes ?? 0,
    textLength: typeof d.textLength === "number" ? d.textLength : null,
    polarity: d.polarity ?? 0,
    affinity: d.affinity ?? 0,
    date: d.date?.toDate?.() ?? null,
    embedding: toVec(d.embedding),
  };
}

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

export async function reviewVectorsByUser(db: Firestore, userId: string): Promise<ReviewVector[]> {
  const snap = await db.collection(COLLECTIONS.reviewVectors).where("userId", "==", userId).get();
  return snap.docs.map(toReviewVector);
}

export async function reviewVectorsByPath(db: Firestore, reviewPaths: string[]): Promise<ReviewVector[]> {
  const col = db.collection(COLLECTIONS.reviewVectors);
  const out: ReviewVector[] = [];
  for (const ids of chunk(reviewPaths.map((p) => p.replace(/\//g, "__")), 100)) {
    const snaps = await db.getAll(...ids.map((id) => col.doc(id)));
    snaps.filter((s) => s.exists).forEach((s) => out.push(toReviewVector(s)));
  }
  return out;
}

/** All aspects (with embeddings) for the given reviews, grouped by review path. */
export async function aspectsByReview(db: Firestore, reviewPaths: string[]): Promise<Map<string, Aspect[]>> {
  const out = new Map<string, Aspect[]>();
  const queries = chunk(reviewPaths, 30).map((paths) =>
    db.collection(COLLECTIONS.reviewAspects).where("reviewPath", "in", paths).get(),
  );
  for (const snap of await Promise.all(queries)) {
    for (const doc of snap.docs) {
      const d = doc.data();
      const list = out.get(d.reviewPath) ?? [];
      list.push({ category: d.category, statement: d.statement, polarity: d.polarity, embedding: toVec(d.embedding) });
      out.set(d.reviewPath, list);
    }
  }
  return out;
}

/** Nearest aspect statements of one polarity ("pos" praise / "neg" complaint). */
export async function nearestAspects(
  db: Firestore,
  query: Vec,
  sign: "pos" | "neg",
  limit: number,
): Promise<AspectHit[]> {
  const snap = await db
    .collection(COLLECTIONS.reviewAspects)
    .where("sign", "==", sign)
    .select("reviewPath", "userId", "trackKey", "category", "statement", "polarity", "distance")
    .findNearest({
      vectorField: "embedding",
      queryVector: FieldValue.vector(query),
      limit,
      distanceMeasure: "COSINE",
      distanceResultField: "distance",
    })
    .get();
  return snap.docs.map((doc) => {
    const d = doc.data();
    return {
      reviewPath: d.reviewPath,
      userId: d.userId,
      trackKey: d.trackKey,
      category: d.category,
      statement: d.statement,
      polarity: d.polarity,
      similarity: 1 - d.distance,
    };
  });
}

/** Nearest whole reviews (style / tone / voice). Reposts are never indexed. */
export async function nearestReviews(db: Firestore, query: Vec, limit: number): Promise<ReviewVector[]> {
  const snap = await db
    .collection(COLLECTIONS.reviewVectors)
    .findNearest({
      vectorField: "embedding",
      queryVector: FieldValue.vector(query),
      limit,
      distanceMeasure: "COSINE",
    })
    .get();
  return snap.docs.map(toReviewVector);
}

export interface Preferences {
  favoriteGenres: string[];
  favoriteArtists: string[];
  favoriteAlbums: string[];
  savedTracks: string[];
}

export async function loadPreferences(db: Firestore, userId: string): Promise<Preferences | null> {
  const snap = await db.doc(`users/${userId}/musicPreferences/profile`).get();
  if (!snap.exists) return null;
  const d = snap.data()!;
  return {
    favoriteGenres: d.favoriteGenres ?? [],
    favoriteArtists: d.favoriteArtists ?? [],
    favoriteAlbums: d.favoriteAlbums ?? [],
    savedTracks: d.savedTracks ?? [],
  };
}
