import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { combineSimilarArtists } from "../forYou";
import { Candidate, reasonFor } from "../scoring";

const base: Candidate = {
  reviewPath: "users/b/reviews/1",
  userId: "b",
  trackKey: "a|t",
  artist: "A",
  title: "T",
  tags: [],
  stars: 4,
  affinity: 0.6,
  date: new Date(),
  likes: 0,
  textLength: 300,
  aspects: [],
  styleSim: 0,
  cf: 0,
  sources: new Set(["aspect"]),
};

describe("reasons never claim what the user hasn't done", () => {
  it("fallback depends on what the profile is built from", () => {
    assert.equal(reasonFor(base, null, 0, "reviews"), "Matches the music you write about");
    assert.equal(reasonFor(base, null, 0, "activity"), "Matches reviews you've liked or saved");
    assert.equal(reasonFor(base, null, 0, "onboarding"), "Picked from the music you chose when you joined");
    assert.equal(reasonFor(base, null, 0, "none"), "Popular with REVERB listeners");
  });

  it("no review language for anyone without reviews", () => {
    for (const basis of ["activity", "onboarding", "none"] as const) {
      assert.doesNotMatch(reasonFor(base, null, 0, basis), /write|your review/i, basis);
    }
  });

  it("artist and song reasons say where the taste came from", () => {
    const artist = (via: "review" | "liked" | "favorite") =>
      reasonFor({ ...base, artistSim: 0.8, artistMatch: "Masego", artistVia: via }, null, 0);
    assert.equal(artist("review"), "Sounds like Masego, which you rated highly");
    assert.equal(artist("liked"), "Sounds like Masego, from a review you liked");
    assert.equal(artist("favorite"), "Sounds like Masego, one of your favorite artists");
    assert.equal(
      reasonFor({ ...base, songSim: 0.9, songMatch: "Tadow", songVia: "liked" }, null, 0),
      "Similar to Tadow, from a review you liked",
    );
  });

  it("similar artists remember how the user knows the source artist", () => {
    const out = combineSimilarArtists(
      new Map([["masego", { affinity: 0.7, name: "Masego", via: "favorite" as const }]]),
      new Map([["masego", [{ mbid: "paak", name: "Anderson .Paak", score: 1 }]]]),
    );
    assert.equal(out.get("paak")?.via, "favorite");
  });
});
