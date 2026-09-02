import test from "node:test"
import assert from "node:assert/strict"

import { derivativeKey } from "../src/derivative_key.mjs"

test("builds the thumb path for 400px", () => {
  assert.equal(derivativeKey("7/bo-ke-coffee-a1b2c3.jpg", 400), "7/thumb/bo-ke-coffee-a1b2c3.webp")
})

test("builds the preview path for 1200px", () => {
  assert.equal(derivativeKey("7/bo-ke-coffee-a1b2c3.jpg", 1200), "7/preview/bo-ke-coffee-a1b2c3.webp")
})

test("rejects keys that are not grouped by place", () => {
  assert.throws(() => derivativeKey("legacy-random-key", 400), /must be <place-id>/)
})

test("rejects unsupported sizes", () => {
  assert.throws(() => derivativeKey("7/photo.jpg", 800), /Unsupported derivative size/)
})
