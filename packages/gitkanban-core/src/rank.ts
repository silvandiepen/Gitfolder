import { generateKeyBetween, generateNKeysBetween } from 'fractional-indexing'

/**
 * Fractional / lexicographic rank keys for ordering cards within a lane.
 *
 * A key is a short string that sorts lexicographically. Inserting between two
 * cards mints a new key strictly between their keys, so only the moved card is
 * rewritten — no neighbour churn, no array-rewrite conflicts. See
 * `project-assets/GitKanban/plan/sync-model.md`.
 *
 * Thin, well-tested wrappers over `fractional-indexing` so call sites read in
 * board terms rather than library terms. The Swift port mirrors these.
 */

/** Mint a rank strictly between `before` and `after`. Pass `null` for an open end. */
export function rankBetween(before: string | null, after: string | null): string {
  return generateKeyBetween(before, after)
}

/** The first rank for an empty lane. */
export function firstRank(): string {
  return generateKeyBetween(null, null)
}

/** Mint `count` evenly-spaced ranks after `before` (or from the start when null). */
export function ranksAfter(before: string | null, count: number): string[] {
  return generateNKeysBetween(before, null, count)
}

/** Mint `count` ranks strictly between `before` and `after` (for bulk inserts). */
export function ranksBetween(before: string | null, after: string | null, count: number): string[] {
  return generateNKeysBetween(before, after, count)
}

/**
 * Assign initial ranks to a fresh, ordered list of items — used when importing a
 * board whose cards have no `order` yet (e.g. the audit/task boards ordered by
 * priority). Returns one rank per item, in the given order.
 */
export function initialRanks(count: number): string[] {
  if (count <= 0) return []
  return generateNKeysBetween(null, null, count)
}
