import { describe, expect, it } from "vitest";

import { env } from "./index.js";

describe("env", () => {
  it("reads NODE_ENV from the process environment", () => {
    expect(env.NODE_ENV).toBe(process.env["NODE_ENV"] ?? "development");
  });
});
