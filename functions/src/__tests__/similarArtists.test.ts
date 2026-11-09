import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { combineSimilarArtists } from "../forYou";
import { tagIdf } from "../relevance";
import { Candidate, scoreCandidate } from "../scoring";

function candidate(overrides: Partial<Candidate>): Candidate {
  return {
    reviewPath: "users/b/reviews/1",
    userId: "b",
    trackKey: "artist|track",
    artist: "Artist",
    title: "Track",
    tags: [],
    stars: 4,
    affinity: 0.6,
    date: new Date(),
    likes: 0,
    textLength: 300,
    aspects: [],
    styleSim: 0,
    cf: 0,
    sources: new Set(["artist"]),
    ...overrides,
  };
}

describe("combineSimilarArtists", () => {
  const own = new Map([
    ["masego", { affinity: 1, name: "Masego" }],
    ["cure", { affinity: 0.6, name: "The Cure" }],
  ]);
  const similar = new Map([
    [
      "masego",
      [
        { mbid: "paak", name: "Anderson .Paak", score: 1 },
        { mbid: "misch", name: "Tom Misch", score: 0.5 },
        { mbid: "cure", name: "The Cure", score: 0.2 },
      ],
    ],
    ["cure", [{ mbid: "misch", name: "Tom Misch", score: 0.9 }]],
  ]);

  it("weights similarity by how much the user loved the artist", () => {
    const out = combineSimilarArtists(own, similar);
    assert.equal(out.get("paak")?.strength, 1);
    assert.equal(out.get("paak")?.lovedArtist, "Masego");
  });

  it("keeps the strongest path to each artist", () => {
    // Via Masego: 1 × 0.5 = 0.5; via The Cure: 0.6 × 0.9 = 0.54.
    const misch = combineSimilarArtists(own, similar).get("misch");
    assert.ok(Math.abs((misch?.strength ?? 0) - 0.54) < 1e-9);
    assert.equal(misch?.lovedArtist, "The Cure");
  });

  it("leaves out artists the user already reviewed", () => {
    assert.equal(combineSimilarArtists(own, similar).has("cure"), false);
  });

  it("is empty without cached similar artists", () => {
    assert.equal(combineSimilarArtists(own, new Map()).size, 0);
  });
});

describe("similar artists in scoring", () => {
  it("raises the score of a review by a similar artist", () => {
    const plain = scoreCandidate(candidate({}), [], []);
    const similar = scoreCandidate(candidate({ artistSim: 1, artistMatch: "Masego" }), [], []);
    assert.ok(similar.score > plain.score);
  });

  it("explains a strong artist match", () => {
    const s = scoreCandidate(candidate({ artistSim: 0.8, artistMatch: "Masego" }), [], []);
    assert.equal(s.reason, "Sounds like Masego, which you rated highly");
  });

  it("doesn't claim a weak artist match", () => {
    const s = scoreCandidate(candidate({ artistSim: 0.3, artistMatch: "Masego" }), [], []);
    assert.notEqual(s.reason, "Sounds like Masego, which you rated highly");
  });
});

describe("rare tags in scoring", () => {
  // "rock" is on every review; "darkwave" on one.
  const idf = tagIdf([["rock", "darkwave"], ["rock"], ["rock"], ["rock"]]);

  it("a shared rare tag lifts the score more than a shared common one", () => {
    const rare = scoreCandidate(candidate({ tags: ["darkwave"] }), [], ["darkwave", "rock"], new Date(), idf);
    const common = scoreCandidate(candidate({ tags: ["rock"] }), [], ["darkwave", "rock"], new Date(), idf);
    assert.ok(rare.score > common.score);
  });
});
