import { describe, expect, it } from 'vitest'
import { firstRank, initialRanks, rankBetween, ranksBetween } from '../src/index.js'

describe('rank keys', () => {
  it('mints a rank strictly between two neighbours', () => {
    const a = firstRank()
    const b = rankBetween(a, null)
    const mid = rankBetween(a, b)
    expect(a < mid).toBe(true)
    expect(mid < b).toBe(true)
  })

  it('keeps lexicographic order stable across many inserts at the head', () => {
    let keys = initialRanks(3)
    // Repeatedly insert a new first card; the list must stay sorted.
    for (let i = 0; i < 25; i++) {
      keys = [rankBetween(null, keys[0]), ...keys]
    }
    const sorted = [...keys].sort()
    expect(keys).toEqual(sorted)
    expect(new Set(keys).size).toBe(keys.length)
  })

  it('inserting between the same gap twice yields two distinct, ordered keys', () => {
    const [a, b] = initialRanks(2)
    const first = rankBetween(a, b)
    const second = rankBetween(a, first)
    expect(a < second).toBe(true)
    expect(second < first).toBe(true)
    expect(first < b).toBe(true)
  })

  it('initialRanks returns ascending, unique keys', () => {
    const keys = initialRanks(10)
    expect(keys).toEqual([...keys].sort())
    expect(new Set(keys).size).toBe(10)
    expect(initialRanks(0)).toEqual([])
  })

  it('ranksBetween fills a gap with ordered keys', () => {
    const [a, b] = initialRanks(2)
    const fill = ranksBetween(a, b, 5)
    const all = [a, ...fill, b]
    expect(all).toEqual([...all].sort())
    expect(new Set(all).size).toBe(all.length)
  })
})
