/**
 * One-time (and re-runnable) analysis of every existing review.
 *
 *   OPENAI_API_KEY=… GOOGLE_APPLICATION_CREDENTIALS=… npm run backfill -- --dry-run
 *   … npm run backfill                 # analyse new/changed reviews only
 *   … npm run backfill -- --force      # re-analyse everything
 *   … npm run backfill -- --for-you    # then build every user's For You
 *   … npm run backfill -- --for-you --user=<uid>   # … or just one user's
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
import { syncSearchKeys } from "../search";
import { mergedTags, normalizeReview, ReviewDoc, searchKeys } from "../text";

const args = new Set(process.argv.slice(2));
// --user=<uid>: build For You for that one user instead of everyone.
const onlyUser = process.argv.find((a) => a.startsWith("--user="))?.slice("--user=".length);
const apiKey = process.env.OPENAI_API_KEY ?? "";
if (!apiKey && !args.has("--search-keys")) {
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

async function main() {
  if (args.has("--search-keys")) return backfillSearchKeys();
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
