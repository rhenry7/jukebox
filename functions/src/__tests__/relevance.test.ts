import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { dcgAtK, gradedGain, idfOverlap, ItemInfo, strictGain, tagIdf } from "../relevance";

const item = (o: Partial<ItemInfo>): ItemInfo => ({
  trackKey: "a|t",
  artist: "A",
  artistMbids: [],
  tags: [],
  ...o,
});

describe("tag rarity (IDF)", () => {
  // "rock" on every review, "darkwave" on one.
  const idf = tagIdf([["rock", "darkwave"], ["rock"], ["rock"], ["Rock", "pop"]]);

  it("a tag on every review carries no weight", () => {
    assert.equal(idf.get("rock"), 0);
    assert.ok((idf.get("darkwave") ?? 0) > (idf.get("pop") ?? 0) - 1e-9);
  });

  it("sharing a rare tag beats sharing a common one", () => {
    const rare = idfOverlap(["darkwave", "rock"], ["darkwave", "pop"], idf);
    const common = idfOverlap(["rock", "darkwave"], ["rock", "pop"], idf);
    assert.ok(rare > common);
    assert.equal(idfOverlap(["rock"], ["rock"], idf), 0);
  });

  it("folds spelling variants", () => {
    const idf2 = tagIdf([["R&B"], ["rnb"], ["jazz"]]);
    assert.equal(idfOverlap(["R and B"], ["rnb"], idf2), 1);
  });
});

describe("gradedGain", () => {
  const similar = new Map([["masego", new Map([["paak", 0.8]])]]);
  const idf = tagIdf([["neo soul"], ["rock"], ["rock"]]);
  const target = item({ trackKey: "masego|tadow", artist: "Masego, FKJ", artistMbids: ["masego"], tags: ["neo soul"] });

  it("same song 1, same artist 0.6", () => {
    assert.equal(gradedGain(item({ trackKey: "masego|tadow" }), target, similar, idf), 1);
    assert.equal(gradedGain(item({ artist: "FKJ" }), target, similar, idf), 0.6);
    assert.equal(gradedGain(item({ artistMbids: ["masego"] }), target, similar, idf), 0.6);
  });

  it("similar-sounding artist, either direction", () => {
    assert.ok(Math.abs(gradedGain(item({ artistMbids: ["paak"] }), target, similar, idf) - 0.4) < 1e-9);
    const reverse = { ...target, artistMbids: ["paak"] };
    assert.ok(gradedGain(item({ artistMbids: ["masego"] }), reverse, similar, idf) > 0);
  });

  it("shared rare tags count up to 0.3; unrelated is 0", () => {
    assert.equal(gradedGain(item({ tags: ["neo soul"] }), target, similar, idf), 0.3);
    assert.equal(gradedGain(item({ tags: ["metal"] }), target, similar, idf), 0);
  });

  it("strict gain ignores similarity and tags", () => {
    assert.equal(strictGain(item({ artistMbids: ["paak"], tags: ["neo soul"] }), target), 0);
  });
});

describe("dcgAtK", () => {
  it("rewards relevant items near the top, capped at 1", () => {
    assert.equal(dcgAtK([1], 10).dcg, 1);
    assert.ok(dcgAtK([0, 1], 10).dcg < dcgAtK([1, 0], 10).dcg);
    assert.equal(dcgAtK([1, 1, 1], 10).dcg, 1);
    assert.deepEqual(dcgAtK([0.4, 0.3], 10).hit, 0);
    assert.deepEqual(dcgAtK([0, 0, 0.6], 2).hit, 0, "only the top k count");
  });
});
