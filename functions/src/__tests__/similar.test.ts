import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseSimilarRecordings } from "../musicbrainz";
import { tagIdf } from "../relevance";
import { CorpusItem, rankSimilar, SimilarCorpus } from "../similar";

const item = (path: string, o: Partial<CorpusItem>): CorpusItem => ({
  reviewPath: path,
  userId: path.split("/")[1],
  trackKey: `${path}|t`,
  artist: path,
  artistMbids: [],
  recordingMbid: null,
  tags: [],
  embedding: null,
  stars: 4,
  likes: 0,
  textLength: 300,
  ...o,
});

function corpus(items: CorpusItem[], o: Partial<SimilarCorpus> = {}): SimilarCorpus {
  return {
    items: new Map(items.map((i) => [i.reviewPath, i])),
    similarArtists: new Map(),
    similarRecordings: new Map(),
    idf: tagIdf(items.map((i) => i.tags)),
    ...o,
  };
}

describe("rankSimilar", () => {
  const anchor = item("users/me/reviews/a", {
    artistMbids: ["masego"],
    recordingMbid: "tadow",
    tags: ["neo soul"],
    embedding: [1, 0],
  });

  it("scores artist, song, tags and text, and says why", () => {
    const c = corpus(
      [
        anchor,
        item("users/b/reviews/artist", { artistMbids: ["paak"] }),
        item("users/c/reviews/song", { recordingMbid: "redbone" }),
        item("users/d/reviews/tags", { tags: ["neo soul"] }),
        item("users/e/reviews/text", { embedding: [1, 0] }),
        item("users/f/reviews/none", { tags: ["metal"], embedding: [0, 1] }),
      ],
      {
        similarArtists: new Map([["masego", new Map([["paak", 1]])]]),
        similarRecordings: new Map([["tadow", new Map([["redbone", 1]])]]),
      },
    );
    const out = rankSimilar(anchor.reviewPath, c);
    const reasons = Object.fromEntries(out.map((s) => [s.reviewPath.split("/").pop(), s.reason]));
    assert.deepEqual(reasons, { artist: "artist", song: "song", tags: "tags", text: "text" });
    assert.ok(!out.some((s) => s.reviewPath.endsWith("none")), "unrelated reviews are left out");
  });

  it("leaves out the same song and caps each author", () => {
    const c = corpus([
      anchor,
      item("users/b/reviews/same", { trackKey: anchor.trackKey, tags: ["neo soul"] }),
      ...[1, 2, 3].map((n) => item(`users/seed/reviews/${n}`, { tags: ["neo soul"], trackKey: `s${n}` })),
      // Other music, so "neo soul" is a rare (meaningful) tag.
      ...[1, 2, 3, 4, 5, 6].map((n) => item(`users/x${n}/reviews/r`, { tags: ["rock"] })),
    ]);
    const out = rankSimilar(anchor.reviewPath, c);
    assert.ok(!out.some((s) => s.reviewPath.endsWith("same")));
    assert.equal(out.filter((s) => s.reviewPath.startsWith("users/seed/")).length, 2);
  });
});

describe("parseSimilarRecordings", () => {
  it("best first, scaled to 1", () => {
    const out = parseSimilarRecordings([
      { recording_mbid: "b", recording_name: "B", artist_credit_name: "Y", score: 20 },
      { recording_mbid: "a", recording_name: "Redbone", artist_credit_name: "Childish Gambino", score: 85 },
    ]);
    assert.equal(out[0].title, "Redbone");
    assert.equal(out[0].score, 1);
    assert.ok(Math.abs(out[1].score - 20 / 85) < 0.001);
  });
});
