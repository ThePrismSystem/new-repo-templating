import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { displayName } from "./index.js";

describe("displayName", () => {
  it("joins the parts with single spaces", () => {
    assert.equal(displayName("Ada", "Lovelace"), "Ada Lovelace");
  });

  it("trims each part and leaves out blank ones", () => {
    assert.equal(displayName("  Ada ", "", "   ", "Lovelace"), "Ada Lovelace");
  });

  it("returns an empty string for no parts", () => {
    assert.equal(displayName(), "");
  });
});
