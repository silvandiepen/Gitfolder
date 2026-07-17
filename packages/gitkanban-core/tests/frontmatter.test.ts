import { describe, expect, it } from 'vitest'
import { parseCard, parseFrontmatter, serializeCard } from '../src/index.js'

const CARD = `---
id: IMAGEKID-001
title: Protect native work lifecycle and operation targeting
project: imagekid
status: todo
priority: P0
type: fix
epic: native-hardening
assignee: null
depends_on: []
audit_findings: [EXP-0001, ARC-0001]
tags: [native, data-loss]
---

# Protect native work lifecycle and operation targeting

## Context

Dirty items can be removed without recovery.
`

describe('frontmatter', () => {
  it('splits frontmatter from body', () => {
    const { data, body, hasFrontmatter } = parseFrontmatter(CARD)
    expect(hasFrontmatter).toBe(true)
    expect(data.id).toBe('IMAGEKID-001')
    expect(data.audit_findings).toEqual(['EXP-0001', 'ARC-0001'])
    expect(body.startsWith('\n# Protect native work lifecycle')).toBe(true)
  })

  it('treats a document with no frontmatter as pure body', () => {
    const { data, body, hasFrontmatter } = parseFrontmatter('# just a heading\n')
    expect(hasFrontmatter).toBe(false)
    expect(data).toEqual({})
    expect(body).toBe('# just a heading\n')
  })

  it('round-trips a card without losing keys the app does not model', () => {
    const parsed = parseCard(CARD)
    const out = serializeCard(parsed)
    const reparsed = parseCard(out)
    // Semantic round-trip: every key survives with its value.
    expect(reparsed.frontmatter).toEqual(parsed.frontmatter)
    // Unknown-to-the-app keys are preserved.
    expect(reparsed.frontmatter.depends_on).toEqual([])
    expect(reparsed.frontmatter.audit_findings).toEqual(['EXP-0001', 'ARC-0001'])
    // Body is preserved verbatim.
    expect(reparsed.body).toBe(parsed.body)
  })

  it('preserves a null value as null, not an empty string', () => {
    const parsed = parseCard(CARD)
    expect(parsed.frontmatter.assignee).toBeNull()
    const reparsed = parseCard(serializeCard(parsed))
    expect(reparsed.frontmatter.assignee).toBeNull()
  })
})
