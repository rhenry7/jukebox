/**
 * One-time (and re-runnable) analysis of every existing review.
 *
 *   OPENAI_API_KEY=… GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --dry-run
 *   … npm run backfill                 # analyse new/changed reviews only
 *   … npm run backfill -- --force      # re-analyse everything
 *   … npm run backfill -- --for-you    # then build every user's For You
 *   … npm run backfill -- --for-you --user=<uid>   # … or just one user's
 *
 * MusicBrainz IDs and ListenBrainz similar artists (no OpenAI key; about
 * one review a second, as MusicBrainz asks):
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --mbids --dry-run
 *   … npm run backfill -- --mbids          # also mbTags, release years + era tags, tag rarity
 *   … npm run backfill -- --mbids --force  # re-fetch every review's mbTags
 *
 * "More like this" lists (similar songs, then every review's list):
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --similar [--dry-run]
 *
 * Recompute every review's release year + era tags:
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --years [--dry-run]
 *
 * Onboarding favourite artists → MBIDs + similar artists (For You cold start):
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --favorites
 *
 * "Listeners like you" now, seed accounts excluded (nightly does this too):
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --neighbors [--dry-run]
 *
 * "Best New Music" on the Search page (the 3-hourly job does this too):
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --news [--dry-run]
 *
 * Tag-page index fields only (no OpenAI key needed, no analysis):
 *   GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --search-keys --dry-run
 *   … npm run backfill -- --search-keys
 *
 * Idempotent: unchanged reviews (same text/stars/tags and ANALYSIS_VERSION)
 * are skipped, so it is safe to re-run after a failure.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { analyzeText, syncReview } from "../analysis";
import { computeForYou } from "../forYou";
import { seedUserIds } from "../config";
import {
  backfillMbTags,
  backfillYears,
  ensureSimilarArtists,
  ensureSimilarRecordings,
  syncFavoriteArtists,
  syncMbIds,
} from "../musicbrainz";
import { loadSimilarCorpus, rankSimilar, writeSimilar } from "../similar";
import { computeNeighbors, writeNeighbors } from "../neighbors";
import { computeTagIdf } from "../tagStats";
import { loadProjectEnv } from "./env";
import { syncMusicNews } from "../news";
import { syncSearchKeys } from "../search";
import { mergedTags, normalizeReview, ReviewDoc, searchKeys } from "../text";

loadProjectEnv();
const args = new Set(process.argv.slice(2));
// --user=<uid>: build For You for that one user instead of everyone.
const onlyUser = process.argv.find((a) => a.startsWith("--user="))?.slice("--user=".length);
const apiKey = process.env.OPENAI_API_KEY ?? "";
if (
  !apiKey &&
  !["--search-keys", "--mbids", "--neighbors", "--similar", "--favorites", "--years", "--news"].some((f) => args.has(f))
) {
  console.error("Set OPENAI_API_KEY (server key, never the old client one).");
  process.exit(1);
}

initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "juxeboxd" });
const db = getFirestore();

/** Writes the tag-page index fields on every review that lacks or differs. */
async function backfillSearchKeys() {
  // Only users/{uid}/reviews/{id}: the app never reads stray docs elsewhere.
  const reviews = (await db.collectionGroup("reviews").get()).docs.filter(
    (d) => d.ref.path.split("/").length === 4 && d.ref.path.startsWith("users/"),
  );
  const dryRun = args.has("--dry-run");
  console.log(`${reviews.length} user review docs${dryRun ? " (dry run: nothing written)" : ""}`);
  for (const doc of reviews.filter((d) => !d.get("isRepost")).slice(0, 5)) {
    console.log(`\n${doc.ref.path} — "${doc.get("title")}"`);
    console.log(JSON.stringify(searchKeys(doc.data() as Partial<ReviewDoc>)));
  }
  const counts: Record<string, number> = {};
  const queue = [...reviews];
  const worker = async () => {
    for (let doc = queue.shift(); doc; doc = queue.shift()) {
      try {
        const outcome = await syncSearchKeys(db, doc.ref.path, { dryRun });
        counts[outcome] = (counts[outcome] ?? 0) + 1;
      } catch (e) {
        counts.failed = (counts.failed ?? 0) + 1;
        console.error(`Failed ${doc.ref.path}: ${e}`);
      }
    }
  };
  await Promise.all([worker(), worker(), worker(), worker()]);
  console.log(`\nSearch keys ${dryRun ? "that would change" : "done"}:`, counts);
}

/**
 * Looks up MusicBrainz IDs for every review that lacks them (or whose song
 * changed), then caches similar artists for every artist found. One review
 * at a time: MusicBrainz allows about a request a second.
 */
async function backfillMbIds() {
  const reviews = (await db.collectionGroup("reviews").get()).docs.filter(
    (d) => d.ref.path.split("/").length === 4 && d.ref.path.startsWith("users/") && !d.get("isRepost"),
  );
  const dryRun = args.has("--dry-run");
  console.log(`${reviews.length} original reviews${dryRun ? " (dry run: nothing written)" : ""}`);
  const counts: Record<string, number> = {};
  let i = 0;
  for (const doc of reviews) {
    const outcome = await syncMbIds(db, doc.ref.path, { dryRun });
    counts[outcome] = (counts[outcome] ?? 0) + 1;
    if (++i % 25 === 0) console.log(`  ${i}/${reviews.length}`, counts);
  }
  console.log("MusicBrainz IDs:", counts);
  if (dryRun) {
    console.log("Filled-in tags (sample, nothing written):");
    await backfillMbTags(db, { dryRun: true, force: true });
    return;
  }

  const artists = new Set<string>();
  let resolved = 0;
  for (const doc of (await db.collectionGroup("reviews").select("artistMbids", "recordingMbid").get()).docs) {
    if (doc.get("recordingMbid")) resolved++;
    for (const id of (doc.get("artistMbids") as string[] | undefined) ?? []) artists.add(id);
  }
  console.log(`${resolved} reviews matched to a MusicBrainz song; ${artists.size} distinct artists`);
  console.log(`Similar-artist lists fetched: ${await ensureSimilarArtists(db, [...artists])}`);
  console.log(`Filled-in tags written: ${await backfillMbTags(db, { force: args.has("--force") })}`);
  console.log("Release years (by decade):", await backfillYears(db));
  console.log("Tag rarity:", await computeTagIdf(db));
}

/** Similar songs for every matched review, then every review's "More like this" list. */
async function backfillSimilar() {
  const dryRun = args.has("--dry-run");
  const recordings = new Set<string>();
  for (const d of (await db.collectionGroup("reviews").select("recordingMbid").get()).docs) {
    const id = d.get("recordingMbid") as string | null | undefined;
    if (id) recordings.add(id);
  }
  if (!dryRun) console.log(`Similar-song lists fetched: ${await ensureSimilarRecordings(db, [...recordings])} of ${recordings.size}`);
  const corpus = await loadSimilarCorpus(db);
  for (const path of [...corpus.items.keys()].slice(0, 3)) {
    const me = corpus.items.get(path)!;
    console.log(`\n${me.artist} – ${path}`);
    for (const s of rankSimilar(path, corpus).slice(0, 5)) {
      const it = corpus.items.get(s.reviewPath)!;
      console.log(`  ${s.score.toFixed(3)} ${s.reason.padEnd(6)} ${it.artist} (${it.trackKey.split("|")[1]})`);
    }
  }
  console.log(`\n"More like this" lists ${dryRun ? "that would be written" : "written"}: ${await writeSimilar(db, corpus, undefined, { dryRun })}`);
}

/** Resolves every user's onboarding favourite artists (see syncFavoriteArtists). */
async function backfillFavorites() {
  const prefs = (await db.collectionGroup("musicPreferences").select("favoriteArtists").get()).docs.filter(
    (d) => d.id === "profile" && ((d.get("favoriteArtists") as string[] | undefined) ?? []).length > 0,
  );
  console.log(`${prefs.length} users with favourite artists`);
  for (const d of prefs) {
    const uid = d.ref.path.split("/")[1];
    console.log(`  ${uid.slice(0, 6)}…: ${await syncFavoriteArtists(db, uid)}`);
  }
}

/** Rebuilds "listeners like you" now (seed accounts excluded) instead of waiting for the nightly run. */
async function backfillNeighbors() {
  const neighbors = await computeNeighbors(db);
  const seeds = seedUserIds();
  const withSeed = [...neighbors.values()].filter((l) => l.some((n) => seeds.has(n.uid))).length;
  console.log(`${neighbors.size} users; lists including a seed account: ${withSeed}`);
  if (args.has("--dry-run")) return;
  await writeNeighbors(db, neighbors);
  console.log("Neighbours written. Tag rarity:", await computeTagIdf(db));
}

async function main() {
  if (args.has("--news")) {
    console.log("Music news:", await syncMusicNews(db, { dryRun: args.has("--dry-run") }));
    return;
  }
  if (args.has("--search-keys")) return backfillSearchKeys();
  if (args.has("--mbids")) return backfillMbIds();
  if (args.has("--neighbors")) return backfillNeighbors();
  if (args.has("--similar")) return backfillSimilar();
  if (args.has("--favorites")) return backfillFavorites();
  if (args.has("--years")) {
    console.log("Release years (by decade):", await backfillYears(db, { force: true, dryRun: args.has("--dry-run") }));
    return;
  }
  const reviews = await db.collectionGroup("reviews").get();
  const originals = reviews.docs.filter((d) => !d.get("isRepost") && d.ref.path.split("/").length === 4);
  console.log(`${reviews.size} review docs, ${originals.length} originals (reposts skipped)`);

  if (args.has("--dry-run")) {
    for (const doc of originals.slice(0, 5)) {
      const data = normalizeReview(doc.data() as Partial<ReviewDoc>, doc.ref.path);
      const analysis = await analyzeText(apiKey, data, mergedTags(data));
      console.log(`\n${doc.ref.path} — "${data.title}" by ${data.artist} (${data.score}★)`);
      console.log(`  ${data.review.slice(0, 160)}…`);
      console.log(JSON.stringify(analysis, null, 2));
    }
    console.log("\nDry run: nothing written.");
    return;
  }

  const counts: Record<string, number> = {};
  const queue = [...originals];
  const worker = async () => {
    for (let doc = queue.shift(); doc; doc = queue.shift()) {
      try {
        const outcome = await syncReview(db, apiKey, doc.ref.path, { force: args.has("--force") });
        counts[outcome] = (counts[outcome] ?? 0) + 1;
      } catch (e) {
        counts.failed = (counts.failed ?? 0) + 1;
        console.error(`Failed ${doc.ref.path}: ${e}`);
      }
      const done = originals.length - queue.length;
      if (done % 25 === 0) console.log(`  ${done}/${originals.length}`, counts);
    }
  };
  await Promise.all([worker(), worker(), worker(), worker()]);
  console.log("Analysis done:", counts);

  const vectors = await db.collection("reviewVectors").count().get();
  console.log(`reviewVectors: ${vectors.data().count} (expect ${originals.length} minus empty reviews)`);

  if (args.has("--for-you")) {
    const users = onlyUser ? [onlyUser] : [...new Set(originals.map((d) => d.ref.path.split("/")[1]))];
    for (const uid of users) {
      const items = await computeForYou(db, apiKey, uid, { write: true });
      console.log(`  For You ${uid}: ${items.length} items`);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
